#include "browser_activation.h"
#include "browser_socket.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QSettings>
#include <QCryptographicHash>
#include <QDir>
#include <QEvent>
#ifdef Q_OS_MACOS
#include <QFileOpenEvent>
#endif
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>
#include <QTimer>
#include <QLocalSocket>
#include <QHostAddress>
#include <memory>
#include <QUrlQuery>

namespace {
constexpr int kMaxRequestBytes = 16 * 1024;

QByteArray encodeReply(bool ok, const QString& message, const QString& requestId = {})
{
    QJsonObject reply{
        {QStringLiteral("ok"), ok},
        {QStringLiteral("message"), message},
        {QStringLiteral("protocolVersion"), 2}
    };
    if (!requestId.isEmpty()) reply.insert(QStringLiteral("requestId"), requestId);
    return QJsonDocument(reply).toJson(QJsonDocument::Compact) + '\n';
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
    // Windows device names remain reserved even with extensions (CON.zip,
    // COM1.txt, etc.). Reject them on every OS for portable handoffs.
    const QString stem = leaf.section(QLatin1Char('.'), 0, 0).toUpper();
    if (stem == QStringLiteral("CON") || stem == QStringLiteral("PRN")
        || stem == QStringLiteral("AUX") || stem == QStringLiteral("NUL")
        || (stem.size() == 4
            && ((stem.startsWith(QStringLiteral("COM"))
                 || stem.startsWith(QStringLiteral("LPT")))
                && stem.at(3) >= QLatin1Char('1')
                && stem.at(3) <= QLatin1Char('9'))))
        return {};
    return leaf;
}

void BrowserActivation::scheduleNextPrompt()
{
    // Give the QML Dialog its close transition before opening the next one.
    // New sockets arriving in the interim remain queued, not rejected.
    m_promptTransitioning = true;
    QTimer::singleShot(350, this, [this] {
        m_promptTransitioning = false;
        activateNextPrompt();
    });
}

void BrowserActivation::setFrontendReady(bool ready)
{
    m_frontendReady = ready;
    if (ready) activateNextPrompt();
}

void BrowserActivation::activateNextPrompt()
{
    if (!m_frontendReady || m_pendingPromptSocket || m_localPromptActive
        || m_promptTransitioning) return;
    while (!m_promptQueue.isEmpty()) {
        const PendingPrompt pending = m_promptQueue.dequeue();
        if (!pending.localRequest
            && (!pending.client
                || pending.client->state() != QLocalSocket::ConnectedState))
            continue;
        m_pendingPromptSocket = pending.client;
        m_localPromptActive = pending.localRequest;
        m_activeRequestId = pending.requestId;
        emit promptRequested(pending.url, pending.filename);
        return;
    }
}

void BrowserActivation::expirePrompt(QLocalSocket* client)
{
    if (!client) return;
    if (m_pendingPromptSocket == client) {
        m_pendingPromptSocket.clear();
        m_outstandingRequestIds.remove(m_activeRequestId);
        m_activeRequestId.clear();
        emit promptAborted();
    } else {
        for (int i = 0; i < m_promptQueue.size(); ++i) {
            if (m_promptQueue.at(i).client == client) {
                m_outstandingRequestIds.remove(m_promptQueue.at(i).requestId);
                m_promptQueue.removeAt(i);
                break;
            }
        }
    }
    if (client->state() == QLocalSocket::ConnectedState) {
        client->write(encodeReply(false, QStringLiteral("download prompt expired")));
        client->flush();
        client->disconnectFromServer();
    }
    scheduleNextPrompt();
}

void BrowserActivation::finishPrompt(bool accepted)
{
    if (!m_pendingPromptSocket && !m_localPromptActive) return;
    QPointer<QLocalSocket> client = m_pendingPromptSocket;
    const QString requestId = m_activeRequestId;
    m_pendingPromptSocket.clear();
    m_localPromptActive = false;
    m_activeRequestId.clear();
    m_outstandingRequestIds.remove(requestId);
    if (accepted && !requestId.isEmpty()) {
        m_handledRequestIds.insert(requestId);
        m_handledRequestOrder.enqueue(requestId);
        if (m_handledRequestOrder.size() > 256)
            m_handledRequestIds.remove(m_handledRequestOrder.dequeue());
    }
    if (client) {
        client->write(encodeReply(accepted,
            accepted ? QStringLiteral("user accepted")
                     : QStringLiteral("user declined"), requestId));
        client->flush();
        client->disconnectFromServer();
    }
    scheduleNextPrompt();
}

bool BrowserActivation::submitUrl(const QString& raw)
{
    // macOS Services and OS protocol handlers represent an explicit user
    // action. Queue a review dialog rather than starting the download.
    const QUrl url = parseDownloadUrl(raw);
    if (!isSafeHttpUrl(url) || m_promptQueue.size() >= 16) return false;
    m_promptQueue.enqueue({nullptr, url.toString(QUrl::FullyEncoded),
                           QString(), QString(), true});
    activateNextPrompt();
    return true;
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
        const bool protocolPrompt = input.startsWith(
            QStringLiteral("genydl:"), Qt::CaseInsensitive);
        const QByteArray message = QJsonDocument(QJsonObject{
            {QStringLiteral("type"), protocolPrompt
                ? QStringLiteral("download.prompt")
                : QStringLiteral("download.request")},
            {QStringLiteral("url"), input}
        }).toJson(QJsonDocument::Compact) + '\n';
        if (socket.write(message) != message.size()) return false;
        if (!socket.waitForBytesWritten(1000)) return false;
        if (!socket.waitForReadyRead(protocolPrompt ? 125000 : 1500)) return false;
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
    for (const QString& arg : arguments) {
        if (safeArgument(arg).isEmpty()) continue;
        if (arg.startsWith(QStringLiteral("genydl:"), Qt::CaseInsensitive))
            submitUrl(arg);
        else
            deliver(arg); // Legacy raw CLI URL keeps its direct behavior.
    }
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
        if (submitUrl(raw)) return true;
    }
#endif
    return QObject::eventFilter(object, event);
}

void BrowserActivation::onConnection()
{
    while (QLocalSocket* client = m_server.nextPendingConnection()) {
        client->setParent(this);
        auto buffer = std::make_shared<QByteArray>();
        auto handled = std::make_shared<bool>(false);
        connect(client, &QLocalSocket::readyRead, this, [this, client, buffer, handled] {
            if (*handled) { client->readAll(); return; }
            *buffer += client->readAll();
            if (buffer->size() > kMaxRequestBytes) {
                client->write(encodeReply(false, QStringLiteral("request too large")));
                client->flush();
                client->disconnectFromServer();
                return;
            }
            const qsizetype end = buffer->indexOf('\n');
            if (end < 0) return;
            *handled = true;
            const QJsonDocument document = QJsonDocument::fromJson(buffer->left(end));
            const QJsonObject message = document.object();
            const QString type = message.value(QStringLiteral("type")).toString();
            const QString rawUrl = message.value(QStringLiteral("url")).toString();
            const QString filename = safeFilename(
                message.value(QStringLiteral("filename")).toString());
            const int version = message.value(QStringLiteral("protocolVersion")).toInt(1);
            const QString requestId = message.value(QStringLiteral("requestId")).toString();
            static const QRegularExpression validId(QStringLiteral("^[A-Za-z0-9_-]{1,96}$"));
            const bool validRequest = document.isObject()
                && (version == 1 || version == 2)
                && (version == 1 || validId.match(requestId).hasMatch())
                && (requestId.isEmpty() || validId.match(requestId).hasMatch());
            auto reject = [client, &requestId](const QString& reason) {
                client->write(encodeReply(false, reason, requestId));
                client->flush();
                client->disconnectFromServer();
            };
            if (!validRequest) {
                reject(QStringLiteral("invalid protocol or request ID"));
                return;
            }
            if (type == QStringLiteral("integration.ping")) {
                const QString browser = message.value(QStringLiteral("browser")).toString();
                static const QSet<QString> allowedBrowsers{
                    QStringLiteral("firefox"), QStringLiteral("chrome"),
                    QStringLiteral("edge"), QStringLiteral("brave"),
                    QStringLiteral("chromium"), QStringLiteral("vivaldi")
                };
                if (version != 2 || !allowedBrowsers.contains(browser)) {
                    reject(QStringLiteral("invalid browser handshake"));
                    return;
                }
                QSettings settings;
                const bool enabled = settings.value(
                    QStringLiteral("browserIntegration/enabled/") + browser,
                    browser == QStringLiteral("firefox")).toBool();
                if (!enabled) {
                    reject(QStringLiteral("browser integration disabled"));
                    return;
                }
                settings.setValue(
                    QStringLiteral("browserIntegration/lastSeen/") + browser,
                    QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs));
                settings.sync();
                const bool ok = settings.status() == QSettings::NoError;
                client->write(encodeReply(ok, ok
                    ? QStringLiteral("GenyDL integration active")
                    : QStringLiteral("could not record browser connection"), requestId));
                client->flush();
                client->disconnectFromServer();
                return;
            }
            if (type == QStringLiteral("download.prompt")) {
                const QUrl url = parseDownloadUrl(rawUrl);
                if (!isSafeHttpUrl(url)) {
                    reject(QStringLiteral("invalid URL"));
                    return;
                }
                if (m_promptQueue.size() >= 16
                    || (!requestId.isEmpty() && (
                        m_outstandingRequestIds.contains(requestId)
                        || m_handledRequestIds.contains(requestId)))) {
                    reject(QStringLiteral("prompt queue full or duplicate request"));
                    return;
                }
                if (!requestId.isEmpty()) m_outstandingRequestIds.insert(requestId);
                m_promptQueue.enqueue({client, url.toString(QUrl::FullyEncoded),
                                      filename, requestId});
                // The timeout is shorter than the native host's 180 seconds.
                // Queued requests have the same bounded lifetime as active ones.
                QTimer::singleShot(120000, client, [this, client] { expirePrompt(client); });
                activateNextPrompt();
                return;
            }
            if (type != QStringLiteral("download.request")) {
                reject(QStringLiteral("unknown request type"));
                return;
            }
            if (!requestId.isEmpty() && (
                m_outstandingRequestIds.contains(requestId)
                || m_handledRequestIds.contains(requestId))) {
                reject(QStringLiteral("duplicate request ID"));
                return;
            }
            const bool accepted = deliver(rawUrl, filename);
            if (accepted && !requestId.isEmpty()) {
                m_handledRequestIds.insert(requestId);
                m_handledRequestOrder.enqueue(requestId);
                if (m_handledRequestOrder.size() > 256)
                    m_handledRequestIds.remove(m_handledRequestOrder.dequeue());
            }
            client->write(encodeReply(accepted, accepted ? QStringLiteral("accepted")
                : QStringLiteral("invalid or rejected request"), requestId));
            client->flush();
            client->disconnectFromServer();
        });
        connect(client, &QLocalSocket::disconnected, this, [this, client] {
            if (m_pendingPromptSocket == client) {
                m_pendingPromptSocket.clear();
                m_outstandingRequestIds.remove(m_activeRequestId);
                m_activeRequestId.clear();
                emit promptAborted();
                scheduleNextPrompt();
            }
            for (int i = m_promptQueue.size() - 1; i >= 0; --i) {
                if (m_promptQueue.at(i).client == client) {
                    m_outstandingRequestIds.remove(m_promptQueue.at(i).requestId);
                    m_promptQueue.removeAt(i);
                }
            }
            client->deleteLater();
        });
    }
}
