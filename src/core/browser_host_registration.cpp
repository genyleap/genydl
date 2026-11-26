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
    // Keep all browser adapters in the registry for future releases, but
    // activate only the currently supported desktop integrations.
    if (browser != QStringLiteral("firefox") && browser != QStringLiteral("chrome"))
        return false;
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

struct BrowserTarget {
    QString key;
    QString macFolder;
    QString linuxFolder;
    QString windowsRegistry;
    QStringList ids;
};
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
    const QString edgeId = QString::fromLatin1(GENYDL_EDGE_EXTENSION_ID);
    const QString braveId = QString::fromLatin1(GENYDL_BRAVE_EXTENSION_ID);
    const QString vivaldiId = QString::fromLatin1(GENYDL_VIVALDI_EXTENSION_ID);

    const QList<BrowserTarget> targets{
        {QStringLiteral("chrome"), QStringLiteral("Google/Chrome"),
         QStringLiteral("google-chrome"), QStringLiteral("Google\\Chrome"),
         extensionIds(QStringLiteral("chrome"), {chromeId, legacy, QString::fromLatin1(kChromiumDevId)})},
        {QStringLiteral("edge"), QStringLiteral("Microsoft Edge"),
         QStringLiteral("microsoft-edge"), QStringLiteral("Microsoft\\Edge"),
         extensionIds(QStringLiteral("edge"), {edgeId, chromeId, legacy, QString::fromLatin1(kChromiumDevId)})},
        {QStringLiteral("brave"), QStringLiteral("BraveSoftware/Brave-Browser"),
         QStringLiteral("BraveSoftware/Brave-Browser"), QStringLiteral("BraveSoftware\\Brave"),
         extensionIds(QStringLiteral("brave"), {braveId, chromeId, legacy, QString::fromLatin1(kChromiumDevId)})},
        {QStringLiteral("chromium"), QStringLiteral("Chromium"),
         QStringLiteral("chromium"), QStringLiteral("Chromium"),
         extensionIds(QStringLiteral("chromium"), {chromeId, legacy, QString::fromLatin1(kChromiumDevId)})},
        {QStringLiteral("vivaldi"), QStringLiteral("Vivaldi"),
         QStringLiteral("vivaldi"), QStringLiteral("Vivaldi"),
         extensionIds(QStringLiteral("vivaldi"), {vivaldiId, chromeId, legacy, QString::fromLatin1(kChromiumDevId)})}
    };

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
    // Brave and Vivaldi on Windows discover native hosts through Chrome's
    // registry location. Put every explicitly configured Chrome-family ID
    // in that one allowlist; writing independent Brave/Vivaldi registry keys
    // would not be reliably discovered by these browsers.
    QStringList chromeFamilyIds;
    for (const BrowserTarget& target : targets) {
        if (target.key != QStringLiteral("chrome")
            && target.key != QStringLiteral("brave")
            && target.key != QStringLiteral("vivaldi"))
            continue;
        if (!browserEnabled(target.key)) continue;
        for (const QString& id : target.ids)
            if (!chromeFamilyIds.contains(id)) chromeFamilyIds.append(id);
    }
    for (const BrowserTarget& target : targets) {
        if (target.key == QStringLiteral("brave")
            || target.key == QStringLiteral("vivaldi"))
            continue;
        const QJsonObject manifest = chromiumManifest(
            base, target.key == QStringLiteral("chrome") ? chromeFamilyIds
                : browserEnabled(target.key) ? target.ids : QStringList{});
        const QString path = nativeDir.filePath(target.key + QLatin1Char('-') + filename);
        const QString key = QStringLiteral("Software\\") + target.windowsRegistry
                          + QStringLiteral("\\NativeMessagingHosts\\")
                          + QString::fromLatin1(kHostName);
        if (manifest.isEmpty()) {
            removeOwnedManifest(path);
            removeRegistryKey(key);
        } else if (writeManifest(path, manifest)) {
            writeRegistryKey(key, path);
        }
    }
#elif defined(Q_OS_MACOS)
    const QString home = QDir::homePath() + QStringLiteral("/Library/Application Support/");
    const QString firefoxPath = home + QStringLiteral("Mozilla/NativeMessagingHosts/") + filename;
    if (browserEnabled(QStringLiteral("firefox")))
        writeManifest(firefoxPath, firefox);
    else
        removeOwnedManifest(firefoxPath);
    for (const BrowserTarget& target : targets) {
        const QString path = home + target.macFolder
            + QStringLiteral("/NativeMessagingHosts/") + filename;
        const QJsonObject manifest = chromiumManifest(
            base, browserEnabled(target.key) ? target.ids : QStringList{});
        if (manifest.isEmpty()) removeOwnedManifest(path);
        else writeManifest(path, manifest);
    }
#else
    const QString home = QDir::homePath();
    const QString firefoxPath = home + QStringLiteral("/.mozilla/native-messaging-hosts/") + filename;
    if (browserEnabled(QStringLiteral("firefox")))
        writeManifest(firefoxPath, firefox);
    else
        removeOwnedManifest(firefoxPath);
    for (const BrowserTarget& target : targets) {
        const QString path = home + QStringLiteral("/.config/") + target.linuxFolder
            + QStringLiteral("/NativeMessagingHosts/") + filename;
        const QJsonObject manifest = chromiumManifest(
            base, browserEnabled(target.key) ? target.ids : QStringList{});
        if (manifest.isEmpty()) removeOwnedManifest(path);
        else writeManifest(path, manifest);
    }
#endif
}
