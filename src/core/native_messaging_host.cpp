// Browser native-messaging host. Exactly one framed JSON request per process.
// No commands are executed from untrusted browser input.
#include "browser_socket.h"
#include "native_messaging_host.h"
#include <cstring>
#include <QCoreApplication>
#include <QCryptographicHash>
#include <QDir>
#include <QElapsedTimer>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLocalSocket>
#include <QProcess>
#include <QThread>
#include <QUrl>
#include <cstdint>
#include <iostream>
#ifdef Q_OS_WIN
#include <fcntl.h>
#include <io.h>
#endif

namespace {
constexpr uint32_t kMaxMessage = 64 * 1024;
QString endpoint()
{
    return genydl::browser::socketName();
}

void respond(bool ok, const QString& message, const QString& requestId = {})
{
    QJsonObject response{
        {QStringLiteral("ok"), ok},
        {QStringLiteral("message"), message},
        {QStringLiteral("protocolVersion"), 2}
    };
    if (!requestId.isEmpty())
        response.insert(QStringLiteral("requestId"), requestId);
    const QByteArray data = QJsonDocument(response).toJson(QJsonDocument::Compact);
    const uint32_t size = static_cast<uint32_t>(data.size());
    const char len[4] = {
        static_cast<char>(size & 0xff), static_cast<char>((size >> 8) & 0xff),
        static_cast<char>((size >> 16) & 0xff), static_cast<char>((size >> 24) & 0xff)
    };
    std::cout.write(len, 4);
    std::cout.write(data.constData(), data.size());
    std::cout.flush();
}

bool sendToApplication(const QByteArray& json, bool waitForUser,
                       const QString& expectedRequestId, bool allowLaunch)
{
    QLocalSocket socket;
    socket.connectToServer(endpoint());
    if (!socket.waitForConnected(350)) {
        // Heartbeats must not launch GenyDL whenever the browser opens.
        if (!allowLaunch) return false;
        QString executable = QCoreApplication::applicationDirPath() + QStringLiteral("/GenyDL");
#ifdef Q_OS_WIN
        executable += QStringLiteral(".exe");
#endif
        if (!QFileInfo::exists(executable) || !QProcess::startDetached(executable, {}))
            return false;
        for (int i = 0; i < 25; ++i) {
            QThread::msleep(120);
            socket.abort();
            socket.connectToServer(endpoint());
            if (socket.waitForConnected(250)) break;
        }
        if (socket.state() != QLocalSocket::ConnectedState) return false;
    }
    const QByteArray packet = json + '\n';
    if (socket.write(packet) != packet.size() || !socket.waitForBytesWritten(1500))
        return false;
    // Browser-originated prompts keep the native host pending until the user
    // accepts or dismisses the desktop dialog. Failure returns control to
    // the browser, which resumes its paused transfer.
    const int timeoutMs = waitForUser ? 180000 : 2500;
    QElapsedTimer timer;
    timer.start();
    QByteArray response;
    // QLocalSocket is a byte stream: JSON may arrive in multiple chunks.
    // Never treat a partial read as a failed desktop acknowledgment.
    while (!response.contains('\n')) {
        response.append(socket.readAll());
        if (response.size() > 4096) return false;
        if (response.contains('\n')) break;
        const qint64 remaining = timeoutMs - timer.elapsed();
        if (remaining <= 0 || !socket.waitForReadyRead(static_cast<int>(remaining)))
            return false;
    }
    const qsizetype end = response.indexOf('\n');
    const QJsonDocument reply = QJsonDocument::fromJson(response.left(end));
    if (!reply.isObject()) return false;
    const QJsonObject body = reply.object();
    return body.value(QStringLiteral("ok")).toBool()
        && (expectedRequestId.isEmpty()
            || body.value(QStringLiteral("requestId")).toString()
                == expectedRequestId);
}
}

bool isNativeMessagingInvocation(int argc, char* argv[])
{
    if (argc < 2 || !argv || !argv[1]) return false;
    // Explicit mode for regression tests and controlled internal launches.
    if (std::strcmp(argv[1], "--native-messaging-host") == 0)
        return true;

    // Google Chrome passes the originating extension URL as argv[1].
    // Its host manifest separately restricts allowed_origins to known IDs.
    const QString first = QString::fromLocal8Bit(argv[1]);
    if (first.startsWith(QStringLiteral("chrome-extension://"))) {
        const QUrl origin(first);
        return origin.isValid()
            && origin.scheme() == QStringLiteral("chrome-extension")
            && !origin.host().isEmpty();
    }

    // Firefox passes its native manifest path followed by the add-on ID.
    // Requiring both avoids starting the headless host for a normal app open.
    const QString manifestFile = QFileInfo(first).fileName();
    const bool ownManifest = manifestFile == QStringLiteral("com.genyleap.genydl.json")
        || manifestFile == QStringLiteral("firefox-com.genyleap.genydl.json");
    return argc >= 3 && argv[2] && ownManifest
        && QString::fromLocal8Bit(argv[2])
            == QStringLiteral("download-links@genydl.genyleap.com");
}

int runNativeMessagingHost(int argc, char** argv)
{
    QCoreApplication app(argc, argv);
    QCoreApplication::setOrganizationName(QStringLiteral("Genyleap"));
    QCoreApplication::setApplicationName(QStringLiteral("GenyDL"));
#ifdef Q_OS_WIN
    // Native Messaging uses binary length-prefixed stdio; text-mode CRT
    // newline conversion corrupts framing on Windows.
    _setmode(_fileno(stdin), _O_BINARY);
    _setmode(_fileno(stdout), _O_BINARY);
#endif
    unsigned char length[4]{};
    if (!std::cin.read(reinterpret_cast<char*>(length), 4)) return 1;
    const uint32_t bytes = uint32_t(length[0]) | (uint32_t(length[1]) << 8)
        | (uint32_t(length[2]) << 16) | (uint32_t(length[3]) << 24);
    if (bytes == 0 || bytes > kMaxMessage) {
        respond(false, QStringLiteral("invalid message size"));
        return 1;
    }
    QByteArray data(static_cast<qsizetype>(bytes), Qt::Uninitialized);
    if (!std::cin.read(data.data(), bytes)) {
        respond(false, QStringLiteral("incomplete message"));
        return 1;
    }
    const QJsonDocument document = QJsonDocument::fromJson(data);
    const QJsonObject request = document.object();
    const QString type = request.value(QStringLiteral("type")).toString();
    const QString requestId = request.value(QStringLiteral("requestId")).toString();
    const int version = request.value(QStringLiteral("protocolVersion")).toInt(1);
    if (!document.isObject()
        || (type != QStringLiteral("download.prompt")
            && type != QStringLiteral("download.request")
            && type != QStringLiteral("integration.ping"))
        || (type != QStringLiteral("integration.ping")
            && !request.value(QStringLiteral("url")).isString())
        || (version != 1 && version != 2)
        || (version == 2 && requestId.isEmpty())) {
        respond(false, QStringLiteral("invalid request"), requestId);
        return 1;
    }
    const bool accepted = sendToApplication(
        data, type == QStringLiteral("download.prompt"), requestId,
        type != QStringLiteral("integration.ping"));
    respond(accepted, accepted ? QStringLiteral("GenyDL accepted download")
                              : QStringLiteral("not accepted; keep browser download"), requestId);
    return 0;
}
