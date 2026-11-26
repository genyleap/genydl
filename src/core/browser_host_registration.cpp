#include "browser_host_registration.h"
#include "browser_config.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>
#include <QSettings>
#include <QStandardPaths>
#include <QStringList>
#ifdef Q_OS_WIN
#include <windows.h>
#endif

namespace {
constexpr auto kHostName = "com.genyleap.genydl";
constexpr auto kFirefoxId = "download-links@genydl.genyleap.com";
// Stable ID generated from the public "key" in manifest.chromium.json.
// This is for unpacked development builds, not an assertion of store identity.
constexpr auto kChromiumDevId = "dhmfclimdfgeemdecnghagiodcmiafdb";

bool writeManifest(const QString& filename, const QJsonObject& json)
{
    const QFileInfo info(filename);
    if (!QDir().mkpath(info.absolutePath())) return false;
    QSaveFile out(filename);
    if (!out.open(QIODevice::WriteOnly | QIODevice::Truncate)) return false;
    const QByteArray bytes = QJsonDocument(json).toJson(QJsonDocument::Indented);
    if (out.write(bytes) != bytes.size()) return false;
    return out.commit();
}

bool validChromiumId(const QString& raw)
{
    if (raw.size() != 32) return false;
    for (const QChar c : raw) {
        if (c < QLatin1Char('a') || c > QLatin1Char('p')) return false;
    }
    return true;
}

QStringList extensionIds(const QString& name, const QStringList& configured)
{
    QStringList ids;
    QSettings settings;
    const QStringList extra = settings.value(
        QStringLiteral("browserIntegration/extensionIds/") + name).toStringList();
    for (const QString& raw : configured + extra) {
        const QString id = raw.trimmed().toLower();
        if (validChromiumId(id) && !ids.contains(id)) ids << id;
    }
    return ids;
}

bool browserEnabled(const QString& browser)
{
    // Keep existing Firefox integrations enabled during upgrade. Other
    // browsers are opt-in through the desktop settings UI.
    QSettings settings;
    return settings.value(QStringLiteral("browserIntegration/enabled/") + browser,
                          browser == QStringLiteral("firefox")).toBool();
}

void removeOwnedManifest(const QString& path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) return;
    const QJsonObject manifest = QJsonDocument::fromJson(file.readAll()).object();
    file.close();
    if (manifest.value(QStringLiteral("name")).toString()
        == QStringLiteral("com.genyleap.genydl"))
        QFile::remove(path);
}

QJsonObject chromiumManifest(const QJsonObject& base, const QStringList& ids)
{
    if (ids.isEmpty()) return {};
    QJsonObject result(base);
    QJsonArray origins;
    for (const QString& id : ids)
        origins.append(QStringLiteral("chrome-extension://") + id + QLatin1Char('/'));
    result.insert(QStringLiteral("allowed_origins"), origins);
    return result;
}

#ifdef Q_OS_WIN
void removeRegistryKey(const QString& key)
{
    // Remove only GenyDL's dedicated host registration key, never browser
    // policy keys or other vendors' native messaging hosts.
    RegDeleteKeyW(HKEY_CURRENT_USER, reinterpret_cast<LPCWSTR>(key.utf16()));
}

bool writeRegistryKey(const QString& key, const QString& value)
{
    HKEY handle = nullptr;
    if (RegCreateKeyExW(HKEY_CURRENT_USER,
            reinterpret_cast<LPCWSTR>(key.utf16()), 0, nullptr, 0, KEY_SET_VALUE,
            nullptr, &handle, nullptr) != ERROR_SUCCESS) return false;
    const std::wstring path = value.toStdWString();
    const LSTATUS result = RegSetValueExW(handle, nullptr, 0, REG_SZ,
        reinterpret_cast<const BYTE*>(path.c_str()),
        static_cast<DWORD>((path.size() + 1) * sizeof(wchar_t)));
    RegCloseKey(handle);
    return result == ERROR_SUCCESS;
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

    const QString filename = QString::fromLatin1(kHostName) + QStringLiteral(".json");
    const QJsonObject base{
        {QStringLiteral("name"), QString::fromLatin1(kHostName)},
        {QStringLiteral("description"), QStringLiteral("GenyDL browser download bridge")},
        {QStringLiteral("path"), hostBinary},
        {QStringLiteral("type"), QStringLiteral("stdio")}
    };

    QJsonObject firefox(base);
    firefox.insert(QStringLiteral("allowed_extensions"),
                   QJsonArray{QString::fromLatin1(kFirefoxId)});

    const QString legacy = QString::fromLatin1(GENYDL_CHROMIUM_EXTENSION_ID);
    const QString chromeId = QString::fromLatin1(GENYDL_CHROME_EXTENSION_ID);
    // Only Firefox and Google Chrome are supported for this release.
    const QStringList chromeIds = extensionIds(
        QStringLiteral("chrome"), {chromeId, legacy, QString::fromLatin1(kChromiumDevId)});
    const QJsonObject chrome = chromiumManifest(
        base, browserEnabled(QStringLiteral("chrome")) ? chromeIds : QStringList{});

#ifdef Q_OS_WIN
    const QString userData = QStandardPaths::writableLocation(
        QStandardPaths::AppLocalDataLocation);
    if (userData.isEmpty()) return;
    const QDir nativeDir(QDir(userData).filePath(QStringLiteral("NativeMessagingHosts")));
    const QString firefoxPath = nativeDir.filePath(QStringLiteral("firefox-") + filename);
    const QString firefoxKey = QStringLiteral("Software\\Mozilla\\NativeMessagingHosts\\")
        + QString::fromLatin1(kHostName);
    if (browserEnabled(QStringLiteral("firefox"))) {
        if (writeManifest(firefoxPath, firefox))
            writeRegistryKey(firefoxKey, firefoxPath);
    } else {
        removeOwnedManifest(firefoxPath);
        removeRegistryKey(firefoxKey);
    }
    const QString chromePath = nativeDir.filePath(QStringLiteral("chrome-") + filename);
    const QString chromeKey = QStringLiteral(
        "Software\\Google\\Chrome\\NativeMessagingHosts\\") + QString::fromLatin1(kHostName);
    if (chrome.isEmpty()) {
        removeOwnedManifest(chromePath);
        removeRegistryKey(chromeKey);
    } else if (writeManifest(chromePath, chrome)) {
        writeRegistryKey(chromeKey, chromePath);
    }

    // Remove registrations owned by older GenyDL builds. Never touch
    // unrelated native messaging hosts or other applications' registry keys.
    for (const QString& removed : {QStringLiteral("edge"), QStringLiteral("brave"),
                                   QStringLiteral("chromium"), QStringLiteral("vivaldi")}) {
        removeOwnedManifest(nativeDir.filePath(removed + QLatin1Char('-') + filename));
    }
    for (const QString& obsoleteRegistry : {
             QStringLiteral("Software\\Microsoft\\Edge\\NativeMessagingHosts\\"),
             QStringLiteral("Software\\Chromium\\NativeMessagingHosts\\")}) {
        removeRegistryKey(obsoleteRegistry + QString::fromLatin1(kHostName));
    }
#elif defined(Q_OS_MACOS)
    const QString home = QDir::homePath() + QStringLiteral("/Library/Application Support/");
    const QString firefoxPath = home + QStringLiteral("Mozilla/NativeMessagingHosts/") + filename;
    if (browserEnabled(QStringLiteral("firefox")))
        writeManifest(firefoxPath, firefox);
    else
        removeOwnedManifest(firefoxPath);
    const QString chromePath = home + QStringLiteral("Google/Chrome/NativeMessagingHosts/") + filename;
    if (chrome.isEmpty()) removeOwnedManifest(chromePath);
    else writeManifest(chromePath, chrome);
    for (const QString& oldFolder : {
             QStringLiteral("Microsoft Edge"), QStringLiteral("BraveSoftware/Brave-Browser"),
             QStringLiteral("Chromium"), QStringLiteral("Vivaldi")}) {
        removeOwnedManifest(home + oldFolder + QStringLiteral("/NativeMessagingHosts/") + filename);
    }
#else
    const QString home = QDir::homePath();
    const QString firefoxPath = home + QStringLiteral("/.mozilla/native-messaging-hosts/") + filename;
    if (browserEnabled(QStringLiteral("firefox")))
        writeManifest(firefoxPath, firefox);
    else
        removeOwnedManifest(firefoxPath);
    const QString chromePath = home + QStringLiteral("/.config/google-chrome/NativeMessagingHosts/") + filename;
    if (chrome.isEmpty()) removeOwnedManifest(chromePath);
    else writeManifest(chromePath, chrome);
    for (const QString& oldFolder : {
             QStringLiteral("microsoft-edge"),
             QStringLiteral("BraveSoftware/Brave-Browser"),
             QStringLiteral("chromium"), QStringLiteral("vivaldi")}) {
        removeOwnedManifest(home + QStringLiteral("/.config/") + oldFolder
                            + QStringLiteral("/NativeMessagingHosts/") + filename);
    }
#endif
}
