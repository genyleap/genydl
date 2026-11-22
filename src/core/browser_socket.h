#pragma once

#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QFileDevice>
#include <QStandardPaths>
#include <QString>

// Both GenyDL and its native-messaging executable must resolve the same
// per-user endpoint. On macOS, Unix socket permission flags are not enforced;
// use a private filesystem directory to protect the socket instead.
namespace genydl::browser {
inline QString socketName()
{
#ifdef Q_OS_WIN
    const auto token = QCryptographicHash::hash(QDir::homePath().toUtf8(),
        QCryptographicHash::Sha256).toHex().left(20);
    return QStringLiteral("genydl-browser-") + QString::fromLatin1(token);
#else
    const QString data = QStandardPaths::writableLocation(
        QStandardPaths::AppLocalDataLocation);
    if (data.isEmpty()) return {};
    const QString privateDir = QDir(data).filePath(QStringLiteral("browser-ipc"));
    if (!QDir().mkpath(privateDir)) return {};
    if (!QFile::setPermissions(privateDir, QFileDevice::ReadOwner |
        QFileDevice::WriteOwner | QFileDevice::ExeOwner))
        return {};
    return QDir(privateDir).filePath(QStringLiteral("bridge.sock"));
#endif
}
}
