#include "browser_activation.h"
#include "browser_socket.h"

#include <QCoreApplication>
#include <QCryptographicHash>
#include <QDir>
#include <QEvent>
#ifdef Q_OS_MACOS
#include <QFileOpenEvent>
#endif
#include <QJsonDocument>
#include <QJsonObject>
#include <QLocalSocket>
#include <QHostAddress>
#include <memory>
#include <QUrlQuery>

namespace {
constexpr int kMaxRequestBytes = 16 * 1024;

QByteArray encodeReply(bool ok, const QString& message)
{
    return QJsonDocument(QJsonObject{
        {QStringLiteral("ok"), ok},
        {QStringLiteral("message"), message},
    }).toJson(QJsonDocument::Compact) + '\n';
}

QString safeArgument(const QString& argument)
{
    const QUrl parsed = BrowserActivation::parseDownloadUrl(argument);
    return BrowserActivation::isSafeHttpUrl(parsed) ? parsed.toString(QUrl::FullyEncoded) : QString();
}
}

BrowserActivation::BrowserActivation(DownloadHandler handler, QObject* parent)
    : QObject(parent), m_downloadHandler(std::move(handler))
{
    connect(&m_server, &QLocalServer::newConnection, this, &BrowserActivation::onConnection);
    qApp->installEventFilter(this);
}

QString BrowserActivation::socketName()
{
    return genydl::browser::socketName();
}

QUrl BrowserActivation::parseDownloadUrl(const QString& raw)
{
    const QUrl original = QUrl::fromEncoded(raw.trimmed().toUtf8(), QUrl::StrictMode);
    if (!original.isValid()) return {};
    if (original.scheme().compare(QStringLiteral("genydl"), Qt::CaseInsensitive) != 0)
        return original;
    if (original.host() != QStringLiteral("download")) return {};
    QUrlQuery query(original);
    if (!query.hasQueryItem(QStringLiteral("url"))) return {};
    return QUrl::fromEncoded(query.queryItemValue(QStringLiteral("url"), QUrl::FullyDecoded).toUtf8(),
                             QUrl::StrictMode);
}

bool BrowserActivation::isSafeHttpUrl(const QUrl& url)
{
    if (!url.isValid() || url.isEmpty() || url.host().isEmpty()
        || !url.userName().isEmpty() || !url.password().isEmpty())
        return false;
    const QString scheme = url.scheme().toLower();
    if (scheme != QStringLiteral("https") && scheme != QStringLiteral("http")) return false;
    // This IPC can be used by other local applications; do not accept
    // arbitrary local services or file URLs as implicit browser downloads.
    const QString host = url.host().toLower();
    if (host == QStringLiteral("localhost") || host.endsWith(QStringLiteral(".localhost")))
        return false;
    QHostAddress address;
    if (address.setAddress(host)) {
        if (address.isLoopback() || address.isLinkLocal() || address.isMulticast()) return false;
    }
    return true;
}

QString BrowserActivation::safeFilename(const QString& raw)
{
    // The browser may give an absolute local download path. Never honor its
    // directories: only the leaf filename can affect the GenyDL destination.
    QString normalized = raw.trimmed();
    normalized.replace(QLatin1Char('\\'), QLatin1Char('/'));
    const QString leaf = normalized.mid(normalized.lastIndexOf(QLatin1Char('/')) + 1).trimmed();
    if (leaf.isEmpty() || leaf == QStringLiteral(".") || leaf == QStringLiteral("..")
        || leaf.endsWith(QLatin1Char('.')) || leaf.toUtf8().size() > 240)
        return {};
    for (const QChar c : leaf) {
        if (!c.isPrint() || QStringLiteral("<>:\"|?*").contains(c))
            return {};
    }
    return leaf;
}

void BrowserActivation::finishPrompt(bool accepted)
{
    if (!m_pendingPromptSocket) return;
    QPointer<QLocalSocket> client = m_pendingPromptSocket;
    m_pendingPromptSocket.clear();
    if (!client) return;
    client->write(encodeReply(accepted,
        accepted ? QStringLiteral("user accepted")
                 : QStringLiteral("user declined")));
    client->flush();
    client->disconnectFromServer();
}

bool BrowserActivation::submitUrl(const QString& raw)
{
    return deliver(raw);
}

bool BrowserActivation::deliver(const QString& raw, const QString& filename)
{
    const QUrl url = parseDownloadUrl(raw);
    return isSafeHttpUrl(url) && m_downloadHandler
        && m_downloadHandler(url, safeFilename(filename));
}

bool BrowserActivation::deliverToRunningInstance(const QStringList& arguments)
{
    QLocalSocket socket;
    socket.connectToServer(socketName(), QIODevice::ReadWrite);
    if (!socket.waitForConnected(250)) return false;

    auto send = [&socket](const QString& input) -> bool {
        const QByteArray message = QJsonDocument(QJsonObject{
            {QStringLiteral("type"), QStringLiteral("download.request")},
            {QStringLiteral("url"), input}
        }).toJson(QJsonDocument::Compact) + '\n';
        if (socket.write(message) != message.size()) return false;
        if (!socket.waitForBytesWritten(1000)) return false;
        if (!socket.waitForReadyRead(1500)) return false;
        const QJsonObject reply = QJsonDocument::fromJson(socket.readAll().trimmed()).object();
        return reply.value(QStringLiteral("ok")).toBool();
    };

    if (arguments.isEmpty()) {
        // Existing app is alive; do not create a second instance.
        return true;
    }
    bool allDelivered = true;
    for (const QString& arg : arguments) {
        if (safeArgument(arg).isEmpty()) continue;
        allDelivered = send(arg) && allDelivered;
    }
    return allDelivered;
}

bool BrowserActivation::start(const QStringList& arguments)
{
    if (deliverToRunningInstance(arguments)) return false;
    m_server.setSocketOptions(QLocalServer::UserAccessOption);
    if (!m_server.listen(socketName())) {
        // Remove a stale endpoint only after proving there is no live listener.
        QLocalSocket probe;
        probe.connectToServer(socketName());
        if (probe.waitForConnected(300)) return false;
        QLocalServer::removeServer(socketName());
        if (!m_server.listen(socketName())) return false;
    }
    for (const QString& arg : arguments)
        if (!safeArgument(arg).isEmpty()) deliver(arg);
    return true;
}

bool BrowserActivation::eventFilter(QObject* object, QEvent* event)
{
#ifdef Q_OS_MACOS
    if (event->type() == QEvent::FileOpen) {
        const auto* opened = static_cast<QFileOpenEvent*>(event);
        const QString raw = opened->url().isValid()
            ? opened->url().toString(QUrl::FullyEncoded)
            : opened->file();
        if (deliver(raw)) return true;
    }
#endif
    return QObject::eventFilter(object, event);
}

void BrowserActivation::onConnection()
{
    while (QLocalSocket* client = m_server.nextPendingConnection()) {
        client->setParent(this);
        auto buffer = std::make_shared<QByteArray>();
        connect(client, &QLocalSocket::readyRead, this, [this, client, buffer] {
            if (m_pendingPromptSocket == client) return;
            *buffer += client->readAll();
            if (buffer->size() > kMaxRequestBytes) {
                client->write(encodeReply(false, QStringLiteral("request too large")));
                client->flush();
                client->disconnectFromServer();
                return;
            }
            const qsizetype end = buffer->indexOf('\n');
            if (end < 0) return;
            const QJsonDocument document = QJsonDocument::fromJson(buffer->left(end));
            const QJsonObject message = document.object();
            const QString type = message.value(QStringLiteral("type")).toString();
            const QString rawUrl = message.value(QStringLiteral("url")).toString();
            const QString filename = safeFilename(
                message.value(QStringLiteral("filename")).toString());
            if (type == QStringLiteral("download.prompt")) {
                const QUrl url = parseDownloadUrl(rawUrl);
                if (!isSafeHttpUrl(url) || m_pendingPromptSocket) {
                    client->write(encodeReply(false,
                        QStringLiteral("invalid URL or another prompt is active")));
                    client->flush();
                    client->disconnectFromServer();
                    return;
                }
                m_pendingPromptSocket = client;
                // The native host keeps this socket open while the user
                // chooses. No download and no success ACK occurs yet.
                emit promptRequested(url.toString(QUrl::FullyEncoded), filename);
                return;
            }
            const bool accepted = type == QStringLiteral("download.request")
                && deliver(rawUrl, filename);
            client->write(encodeReply(accepted, accepted ? QStringLiteral("accepted")
                                                         : QStringLiteral("invalid or rejected request")));
            client->flush();
            client->disconnectFromServer();
        });
        connect(client, &QLocalSocket::disconnected, this, [this, client] {
            if (m_pendingPromptSocket == client) {
                m_pendingPromptSocket.clear();
                emit promptAborted();
            }
            client->deleteLater();
        });
    }
}
