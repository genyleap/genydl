#include "browser_integration_manager.h"
#include "browser_host_registration.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSettings>
#include <QStandardPaths>
#include <QVariantMap>

namespace {
struct BrowserInfo {
    const char* code;
    const char* label;
    const char* macFolder;
    const char* linuxFolder;
};

const BrowserInfo kBrowsers[] = {
    {"firefox", "Firefox", "Mozilla", ".mozilla"},
    {"chrome", "Google Chrome", "Google/Chrome", ".config/google-chrome"},
    {"edge", "Microsoft Edge", "Microsoft Edge", ".config/microsoft-edge"},
    {"brave", "Brave", "BraveSoftware/Brave-Browser", ".config/BraveSoftware/Brave-Browser"},
    {"chromium", "Chromium", "Chromium", ".config/chromium"},
    {"vivaldi", "Vivaldi", "Vivaldi", ".config/vivaldi"},
};

bool knownBrowser(const QString& code)
{
    for (const BrowserInfo& info : kBrowsers)
        if (code == QLatin1StringView(info.code)) return true;
    return false;
}

bool validId(const QString& id)
{
    if (id.size() != 32) return false;
    for (QChar c : id)
        if (c < QLatin1Char('a') || c > QLatin1Char('p')) return false;
    return true;
}

QString manifestPath(const BrowserInfo& browser)
{
    const QString filename = QStringLiteral("com.genyleap.genydl.json");
#ifdef Q_OS_WIN
    const QString base = QStandardPaths::writableLocation(
        QStandardPaths::AppLocalDataLocation);
    QString manifestPrefix = QString::fromLatin1(browser.code);
    // Windows Brave and Vivaldi use the Google Chrome registry host entry.
    if (manifestPrefix == QStringLiteral("brave")
        || manifestPrefix == QStringLiteral("vivaldi"))
        manifestPrefix = QStringLiteral("chrome");
    return QDir(base).filePath(QStringLiteral("NativeMessagingHosts/")
        + manifestPrefix + QLatin1Char('-') + filename);
#elif defined(Q_OS_MACOS)
    const QString base = QDir::homePath() + QStringLiteral("/Library/Application Support/");
    return base + QString::fromLatin1(browser.macFolder)
        + QStringLiteral("/NativeMessagingHosts/") + filename;
#else
    const QString root = QDir::homePath();
    if (QLatin1StringView(browser.code) == QLatin1StringView("firefox"))
        return root + QStringLiteral("/.mozilla/native-messaging-hosts/") + filename;
    return root + QLatin1Char('/') + QString::fromLatin1(browser.linuxFolder)
        + QStringLiteral("/NativeMessagingHosts/") + filename;
#endif
}
}

BrowserIntegrationManager::BrowserIntegrationManager(QObject* parent)
    : QObject(parent)
{
}

QVariantList BrowserIntegrationManager::statuses() const
{
    QVariantList result;
    QString executable = QCoreApplication::applicationDirPath()
        + QStringLiteral("/GenyDLNativeHost");
#ifdef Q_OS_WIN
    executable += QStringLiteral(".exe");
#endif
    const bool nativePresent = QFileInfo::exists(executable);
    QSettings settings;

    for (const BrowserInfo& browser : kBrowsers) {
        const QString code = QString::fromLatin1(browser.code);
        const QString path = manifestPath(browser);
        QFile file(path);
        QJsonObject manifest;
        if (file.open(QIODevice::ReadOnly))
            manifest = QJsonDocument::fromJson(file.readAll()).object();
        const bool registered = nativePresent
            && manifest.value(QStringLiteral("path")).toString() == executable
            && manifest.value(QStringLiteral("name")).toString()
                == QStringLiteral("com.genyleap.genydl");

        const QString savedId = settings.value(
            QStringLiteral("browserIntegration/extensionIds/") + code)
            .toStringList().value(0);
        QVariantMap row{
            {QStringLiteral("code"), code},
            {QStringLiteral("name"), QString::fromLatin1(browser.label)},
            {QStringLiteral("hostRegistered"), registered},
            {QStringLiteral("nativeExecutablePresent"), nativePresent},
            {QStringLiteral("manifestPath"), path},
            {QStringLiteral("savedExtensionId"), savedId},
            {QStringLiteral("statusText"), registered
                ? QStringLiteral("Native host registered — extension permission not verified")
                : QStringLiteral("Native host not configured")}
        };
        result.append(row);
    }
#ifdef Q_OS_MACOS
    result.append(QVariantMap{
        {QStringLiteral("code"), QStringLiteral("safari")},
        {QStringLiteral("name"), QStringLiteral("Safari")},
        {QStringLiteral("hostRegistered"), false},
        {QStringLiteral("nativeExecutablePresent"), nativePresent},
        {QStringLiteral("manifestPath"), QString()},
        {QStringLiteral("savedExtensionId"), QString()},
        {QStringLiteral("statusText"),
            QStringLiteral("Manual Services only; signed Safari Web Extension pending")}
    });
#endif
    return result;
}

bool BrowserIntegrationManager::registerExtensionId(const QString& browser,
                                                     const QString& rawId)
{
    if (browser == QStringLiteral("firefox") || !knownBrowser(browser)) return false;
    const QString id = rawId.trimmed().toLower();
    if (!validId(id)) return false;
    QSettings settings;
    settings.setValue(QStringLiteral("browserIntegration/extensionIds/") + browser,
                      QStringList{id});
    settings.sync();
    if (settings.status() != QSettings::NoError) return false;
    registerBrowserNativeHosts();
    return true;
}

void BrowserIntegrationManager::repairNativeHosts()
{
    registerBrowserNativeHosts();
}
