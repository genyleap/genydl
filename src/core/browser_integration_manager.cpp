#include "browser_integration_manager.h"
#include "browser_host_registration.h"
#include "browser_store_config.h"
#include "browser_config.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QDesktopServices>
#include <QUrl>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QSettings>
#include <QStandardPaths>
#include <QStringList>
#include <QVariantMap>

namespace {
struct BrowserInfo {
    const char* code;
    const char* label;
    const char* macName;
    const char* macFolder;
    const char* linuxFolder;
    const char* extensionPage;
    bool activeInRelease;
};

constexpr BrowserInfo kBrowsers[] = {
    {"firefox", "Firefox", "Firefox", "Mozilla", ".mozilla", "about:addons", true},
    {"chrome", "Google Chrome", "Google Chrome", "Google/Chrome",
     ".config/google-chrome", "chrome://extensions", true},
    {"edge", "Microsoft Edge", "Microsoft Edge", "Microsoft Edge",
     ".config/microsoft-edge", "edge://extensions", false},
    {"brave", "Brave", "Brave Browser", "BraveSoftware/Brave-Browser",
     ".config/BraveSoftware/Brave-Browser", "brave://extensions", false},
    {"chromium", "Chromium", "Chromium", "Chromium",
     ".config/chromium", "chrome://extensions", false},
    {"vivaldi", "Vivaldi", "Vivaldi", "Vivaldi",
     ".config/vivaldi", "vivaldi://extensions", false},
};

const BrowserInfo* browserInfo(const QString& code)
{
    for (const BrowserInfo& browser : kBrowsers) {
        if (code == QString::fromLatin1(browser.code)) return &browser;
    }
    return nullptr;
}

QUrl verifiedStoreUrl(const QString& browser)
{
    QString raw;
    QString expectedHost;
    if (browser == QStringLiteral("firefox")) {
        raw = QString::fromLatin1(GENYDL_FIREFOX_STORE_URL).trimmed();
        // Old CMake build directories can keep the former empty cached value.
        // The user-provided Mozilla listing is now the canonical install URL.
        if (raw.isEmpty())
            raw = QStringLiteral(
                "https://addons.mozilla.org/en-US/firefox/addon/genydl-download-with-genydl/");
        expectedHost = QStringLiteral("addons.mozilla.org");
    } else if (browser == QStringLiteral("chrome")) {
        raw = QString::fromLatin1(GENYDL_CHROME_STORE_URL).trimmed();
        expectedHost = QStringLiteral("chromewebstore.google.com");
    } else if (browser == QStringLiteral("edge")) {
        raw = QString::fromLatin1(GENYDL_EDGE_STORE_URL).trimmed();
        expectedHost = QStringLiteral("microsoftedge.microsoft.com");
    } else {
        return {};
    }
    const QUrl url(raw);
    if (url.scheme() != QStringLiteral("https")
        || url.host() != expectedHost || !url.userInfo().isEmpty())
        return {};
    if (browser == QStringLiteral("firefox")) {
        if (!url.path().contains(QStringLiteral("/firefox/addon/")))
            return {};
    } else if (!url.path().contains(QStringLiteral("/detail/"))) {
        return {};
    }
    return url;
}

QString manifestPath(const BrowserInfo& browser)
{
    const QString filename = QStringLiteral("com.genyleap.genydl.json");
#ifdef Q_OS_WIN
    const QString base = QStandardPaths::writableLocation(
        QStandardPaths::AppLocalDataLocation);
    QString prefix = QString::fromLatin1(browser.code);
    if (prefix == QStringLiteral("brave") || prefix == QStringLiteral("vivaldi"))
        prefix = QStringLiteral("chrome");
    return QDir(base).filePath(QStringLiteral("NativeMessagingHosts/")
                              + prefix + QLatin1Char('-') + filename);
#elif defined(Q_OS_MACOS)
    return QDir::homePath() + QStringLiteral("/Library/Application Support/")
        + QString::fromLatin1(browser.macFolder)
        + QStringLiteral("/NativeMessagingHosts/") + filename;
#else
    if (QString::fromLatin1(browser.code) == QStringLiteral("firefox"))
        return QDir::homePath() + QStringLiteral("/.mozilla/native-messaging-hosts/") + filename;
    return QDir::homePath() + QLatin1Char('/')
        + QString::fromLatin1(browser.linuxFolder)
        + QStringLiteral("/NativeMessagingHosts/") + filename;
#endif
}

QStringList linuxNames(const QString& code)
{
    if (code == QStringLiteral("firefox")) return {QStringLiteral("firefox")};
    if (code == QStringLiteral("chrome"))
        return {QStringLiteral("google-chrome-stable"), QStringLiteral("google-chrome")};
    if (code == QStringLiteral("edge"))
        return {QStringLiteral("microsoft-edge-stable"), QStringLiteral("microsoft-edge")};
    if (code == QStringLiteral("brave"))
        return {QStringLiteral("brave-browser"), QStringLiteral("brave")};
    if (code == QStringLiteral("chromium"))
        return {QStringLiteral("chromium"), QStringLiteral("chromium-browser")};
    if (code == QStringLiteral("vivaldi"))
        return {QStringLiteral("vivaldi-stable"), QStringLiteral("vivaldi")};
    return {};
}

QString browserExecutable(const BrowserInfo& browser)
{
    const QString code = QString::fromLatin1(browser.code);
#ifdef Q_OS_MACOS
    const QString bundle = QString::fromLatin1(browser.macName) + QStringLiteral(".app");
    for (const QString& base : {QStringLiteral("/Applications"),
                                QDir::homePath() + QStringLiteral("/Applications")}) {
        if (QFileInfo::exists(QDir(base).filePath(bundle)))
            return QString::fromLatin1(browser.macName);
    }
    return {};
#elif defined(Q_OS_WIN)
    QString rel;
    if (code == QStringLiteral("firefox")) rel = QStringLiteral("Mozilla Firefox/firefox.exe");
    if (code == QStringLiteral("chrome")) rel = QStringLiteral("Google/Chrome/Application/chrome.exe");
    if (code == QStringLiteral("edge")) rel = QStringLiteral("Microsoft/Edge/Application/msedge.exe");
    if (code == QStringLiteral("brave")) rel = QStringLiteral("BraveSoftware/Brave-Browser/Application/brave.exe");
    if (code == QStringLiteral("chromium")) rel = QStringLiteral("Chromium/Application/chrome.exe");
    if (code == QStringLiteral("vivaldi")) rel = QStringLiteral("Vivaldi/Application/vivaldi.exe");
    for (const QString& base : {qEnvironmentVariable("LOCALAPPDATA"),
                                qEnvironmentVariable("PROGRAMFILES"),
                                qEnvironmentVariable("PROGRAMFILES(X86)")}) {
        const QString candidate = QDir(base).filePath(rel);
        if (!base.isEmpty() && QFileInfo::exists(candidate)) return candidate;
    }
    for (const QString& name : linuxNames(code)) {
        const QString executable = QStandardPaths::findExecutable(name + QStringLiteral(".exe"));
        if (!executable.isEmpty()) return executable;
    }
    return {};
#else
    for (const QString& name : linuxNames(code)) {
        const QString executable = QStandardPaths::findExecutable(name);
        if (!executable.isEmpty()) return executable;
    }
    return {};
#endif
}

QString developmentExtensionFolder(const QString& code)
{
    const QString name = code == QStringLiteral("firefox")
        ? QStringLiteral("firefox") : QStringLiteral("chrome");
    QDir current(QCoreApplication::applicationDirPath());
    // Covers <build>/bin/GenyDL.app/Contents/MacOS as well as <build>/bin
    // while avoiding a hard-coded source checkout or user home directory.
    for (int depth = 0; depth < 7; ++depth) {
        const QString candidate = current.filePath(
            QStringLiteral("browser-extensions/") + name);
        if (QFileInfo::exists(QDir(candidate).filePath(QStringLiteral("manifest.json"))))
            return candidate;
        if (!current.cdUp()) break;
    }
    return {};
}

bool isManifestReady(const QString& path, const QString& nativeExecutable,
                     const QString& code)
{
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly)) return false;
    const QJsonObject obj = QJsonDocument::fromJson(f.readAll()).object();
    if (!QFileInfo::exists(nativeExecutable)
        || obj.value(QStringLiteral("name")).toString()
            != QStringLiteral("com.genyleap.genydl")
        || obj.value(QStringLiteral("path")).toString() != nativeExecutable)
        return false;
    if (code == QStringLiteral("firefox"))
        return obj.value(QStringLiteral("allowed_extensions")).toArray().contains(
            QStringLiteral("download-links@genydl.genyleap.com"));
    const QJsonArray origins = obj.value(QStringLiteral("allowed_origins")).toArray();
    if (origins.contains(QStringLiteral("chrome-extension://dhmfclimdfgeemdecnghagiodcmiafdb/")))
        return true; // Pinned unpacked Chrome build.
    const QString publishedId = QString::fromLatin1(GENYDL_CHROME_EXTENSION_ID).trimmed();
    return publishedId.size() == 32
        && origins.contains(QStringLiteral("chrome-extension://") + publishedId + QLatin1Char('/'));
}
}

BrowserIntegrationManager::BrowserIntegrationManager(QObject* parent) : QObject(parent) {}

QVariantList BrowserIntegrationManager::statuses() const
{
    QVariantList result;
    QString nativeBinary = QCoreApplication::applicationFilePath();
    QSettings settings;
    for (const BrowserInfo& browser : kBrowsers) {
        if (!browser.activeInRelease) continue;
        const QString code = QString::fromLatin1(browser.code);
        const bool enabled = settings.value(
            QStringLiteral("browserIntegration/enabled/") + code,
            code == QStringLiteral("firefox")).toBool();
        const bool ready = isManifestReady(manifestPath(browser), nativeBinary, code);
        const bool installed = !browserExecutable(browser).isEmpty();
        const QDateTime lastSeen = QDateTime::fromString(settings.value(
            QStringLiteral("browserIntegration/lastSeen/") + code).toString(),
            Qt::ISODateWithMs);
        const bool connected = enabled && ready && lastSeen.isValid()
            && lastSeen.secsTo(QDateTime::currentDateTimeUtc()) >= 0
            && lastSeen.secsTo(QDateTime::currentDateTimeUtc()) < 150;
        QString status;
        if (!enabled)
            status = QStringLiteral("Off — downloads stay in the browser");
        else if (!ready)
            status = QStringLiteral("Native connection not configured");
        else if (connected)
            status = QStringLiteral("Connected — extension replied");
        else
            status = QStringLiteral("Not connected — extension not responding");
        result.append(QVariantMap{
            {QStringLiteral("code"), code},
            {QStringLiteral("name"), QString::fromLatin1(browser.label)},
            {QStringLiteral("enabled"), enabled},
            {QStringLiteral("ready"), ready},
            {QStringLiteral("connected"), connected},
            {QStringLiteral("storeInstallAvailable"),
                verifiedStoreUrl(code).isValid()},
            {QStringLiteral("browserInstalled"), installed},
            {QStringLiteral("extensionFilesAvailable"),
                !developmentExtensionFolder(code).isEmpty()},
            {QStringLiteral("supported"), true},
            {QStringLiteral("statusText"), status}
        });
    }
    return result;
}

bool BrowserIntegrationManager::setEnabled(const QString& code, bool enabled)
{
    const BrowserInfo* browser = browserInfo(code);
    if (!browser || !browser->activeInRelease) return false;
    QSettings settings;
    const QString key = QStringLiteral("browserIntegration/enabled/") + code;
    settings.setValue(key, enabled);
    if (!enabled) settings.remove(QStringLiteral("browserIntegration/lastSeen/") + code);
    settings.sync();
    if (settings.status() != QSettings::NoError) return false;
    registerBrowserNativeHosts();
    if (!enabled) return true;
    QString nativeBinary = QCoreApplication::applicationFilePath();
    return isManifestReady(manifestPath(*browser), nativeBinary, code);
}

bool BrowserIntegrationManager::openBrowserExtensions(const QString& code) const
{
    const BrowserInfo* browser = browserInfo(code);
    if (!browser) return false;
    const QString executable = browserExecutable(*browser);
    if (executable.isEmpty()) return false;
    const QString page = QString::fromLatin1(browser->extensionPage);
#ifdef Q_OS_MACOS
    return QProcess::startDetached(QStringLiteral("/usr/bin/open"),
        {QStringLiteral("-a"), executable, page});
#else
    return QProcess::startDetached(executable, {page});
#endif
}

bool BrowserIntegrationManager::openStoreListing(const QString& code) const
{
    const BrowserInfo* browser = browserInfo(code);
    if (!browser) return false;
    const QUrl url = verifiedStoreUrl(code);
    if (!url.isValid()) return false;
    const QString executable = browserExecutable(*browser);
    if (executable.isEmpty()) return false;
#ifdef Q_OS_MACOS
    return QProcess::startDetached(QStringLiteral("/usr/bin/open"),
        {QStringLiteral("-a"), executable, url.toString()});
#else
    return QProcess::startDetached(executable, {url.toString()});
#endif
}

bool BrowserIntegrationManager::revealExtensionFiles(const QString& code) const
{
    if (!browserInfo(code)) return false;
    const QString folder = developmentExtensionFolder(code);
    if (folder.isEmpty()) return false;
    return QDesktopServices::openUrl(QUrl::fromLocalFile(folder));
}

void BrowserIntegrationManager::repairNativeHosts()
{
    registerBrowserNativeHosts();
}
