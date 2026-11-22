// Browser native-messaging host. Exactly one framed JSON request per process.
// No commands are executed from untrusted browser input.
#include "browser_socket.h"
#include <QCoreApplication>
#include <QCryptographicHash>
#include <QDir>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLocalSocket>
#include <QProcess>
#include <QThread>
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

void respond(bool ok, const QString& message)
{
    const QByteArray data = QJsonDocument(QJsonObject{
        {QStringLiteral("ok"), ok},
        {QStringLiteral("message"), message}
    }).toJson(QJsonDocument::Compact);
    const uint32_t size = static_cast<uint32_t>(data.size());
    const char len[4] = {
        static_cast<char>(size & 0xff), static_cast<char>((size >> 8) & 0xff),
        static_cast<char>((size >> 16) & 0xff), static_cast<char>((size >> 24) & 0xff)
    };
    std::cout.write(len, 4);
    std::cout.write(data.constData(), data.size());
    std::cout.flush();
}

bool sendToApplication(const QByteArray& json)
{
    QLocalSocket socket;
    socket.connectToServer(endpoint());
    if (!socket.waitForConnected(350)) {
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
    if (!socket.waitForReadyRead(2500)) return false;
    const QJsonDocument reply = QJsonDocument::fromJson(socket.readAll().trimmed());
    return reply.isObject() && reply.object().value(QStringLiteral("ok")).toBool();
}
}

int main(int argc, char** argv)
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
    if (!document.isObject()
        || request.value(QStringLiteral("type")).toString() != QStringLiteral("download.request")
        || !request.value(QStringLiteral("url")).isString()) {
        respond(false, QStringLiteral("invalid request"));
        return 1;
    }
    respond(sendToApplication(data), QStringLiteral("forwarded to GenyDL if accepted"));
    return 0;
}
