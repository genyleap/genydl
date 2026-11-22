#include "browser_host_registration.h"
#include "browser_config.h"

#include <QCoreApplication>
#include <QDir>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>
#include <QStringList>
#ifdef Q_OS_WIN
#include <windows.h>
#endif

namespace {
constexpr auto kHostName = "com.genyleap.genydl";
constexpr auto kFirefoxId = "download-links@genydl.genyleap.com";

bool writeManifest(const QString& filename, const QJsonObject& json)
{
    const QFileInfo info(filename);
    if (!QDir().mkpath(info.absolutePath())) return false;
    QSaveFile out(filename);
    if (!out.open(QIODevice::WriteOnly | QIODevice::Truncate)) return false;
    if (out.write(QJsonDocument(json).toJson(QJsonDocument::Indented)) < 0) return false;
    return out.commit();
}

#ifdef Q_OS_WIN
void writeRegistryKey(const QString& key, const QString& value)
{
    HKEY handle = nullptr;
    if (RegCreateKeyExW(HKEY_CURRENT_USER,
            reinterpret_cast<LPCWSTR>(key.utf16()), 0, nullptr, 0, KEY_SET_VALUE,
            nullptr, &handle, nullptr) != ERROR_SUCCESS) return;
    const std::wstring path = value.toStdWString();
    RegSetValueExW(handle, nullptr, 0, REG_SZ,
        reinterpret_cast<const BYTE*>(path.c_str()),
        static_cast<DWORD>((path.size() + 1) * sizeof(wchar_t)));
    RegCloseKey(handle);
}
#endif
}

void registerBrowserNativeHosts()
{
    QString hostBinary = QCoreApplication::applicationDirPath()
        + QStringLiteral("/GenyDLNativeHost");
#ifdef Q_OS_WIN
    hostBinary += QStringLiteral(".exe");
#endif
    if (!QFileInfo::exists(hostBinary)) return;

    const QString hostFilename = QString::fromLatin1(kHostName) + QStringLiteral(".json");
    const QJsonObject base{
        {QStringLiteral("name"), QString::fromLatin1(kHostName)},
        {QStringLiteral("description"), QStringLiteral("GenyDL browser download handoff")},
        {QStringLiteral("path"), hostBinary},
        {QStringLiteral("type"), QStringLiteral("stdio")}
    };

    QJsonObject firefox(base);
    firefox.insert(QStringLiteral("allowed_extensions"), QJsonArray{
        QString::fromLatin1(kFirefoxId)});
    const QString chromeId = QString::fromLatin1(GENYDL_CHROMIUM_EXTENSION_ID).trimmed();
    QJsonObject chromium(base);
    if (chromeId.size() == 32) {
        bool valid = true;
        for (QChar c : chromeId)
            valid = valid && (c >= QLatin1Char('a') && c <= QLatin1Char('p'));
        if (valid) {
            chromium.insert(QStringLiteral("allowed_origins"), QJsonArray{
                QStringLiteral("chrome-extension://") + chromeId + QStringLiteral("/")});
        }
    }

#ifdef Q_OS_WIN
    const QString data = QDir::homePath() + QStringLiteral("/AppData/Roaming/GenyDL/NativeMessaging");
    const QString firefoxPath = QDir(data).filePath(QStringLiteral("firefox-") + hostFilename);
    if (writeManifest(firefoxPath, firefox)) {
        writeRegistryKey(QStringLiteral("Software\\Mozilla\\NativeMessagingHosts\\") + QString::fromLatin1(kHostName),
                         firefoxPath);
    }
    if (chromium.contains(QStringLiteral("allowed_origins"))) {
        const QString chromePath = QDir(data).filePath(hostFilename);
        if (writeManifest(chromePath, chromium)) {
            for (const QString& vendor : {QStringLiteral("Google\\Chrome"),
                                          QStringLiteral("Microsoft\\Edge"),
                                          QStringLiteral("BraveSoftware\\Brave")}) {
                writeRegistryKey(QStringLiteral("Software\\") + vendor +
                    QStringLiteral("\\NativeMessagingHosts\\") + QString::fromLatin1(kHostName),
                    chromePath);
            }
        }
    }
#elif defined(Q_OS_MACOS)
    const QString home = QDir::homePath() + QStringLiteral("/Library/Application Support/");
    writeManifest(home + QStringLiteral("Mozilla/NativeMessagingHosts/") + hostFilename, firefox);
    if (chromium.contains(QStringLiteral("allowed_origins"))) {
        for (const QString& vendor : {QStringLiteral("Google/Chrome/NativeMessagingHosts/"),
                                      QStringLiteral("Microsoft Edge/NativeMessagingHosts/"),
                                      QStringLiteral("BraveSoftware/Brave-Browser/NativeMessagingHosts/")}) {
            writeManifest(home + vendor + hostFilename, chromium);
        }
    }
#else
    const QString home = QDir::homePath();
    writeManifest(home + QStringLiteral("/.mozilla/native-messaging-hosts/") + hostFilename, firefox);
    if (chromium.contains(QStringLiteral("allowed_origins"))) {
        for (const QString& browser : {QStringLiteral("google-chrome"),
                                       QStringLiteral("microsoft-edge"),
                                       QStringLiteral("BraveSoftware/Brave-Browser"),
                                       QStringLiteral("chromium")}) {
            writeManifest(home + QStringLiteral("/.config/") + browser
                        + QStringLiteral("/NativeMessagingHosts/") + hostFilename, chromium);
        }
    }
#endif
}
