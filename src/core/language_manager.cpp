module;

#include <QCoreApplication>
#include <QGuiApplication>
#include <QLocale>
#include <QQmlEngine>
#include <QSettings>
#include <QTranslator>
#include <iterator>

module genydl.core.language_manager;

namespace {
constexpr auto kSettingsGroup = "ui";
constexpr auto kLanguageKey = "language";

struct LanguageEntry {
    const char* code;
    const char* locale;
    const char* nativeName;
};

constexpr LanguageEntry kLanguages[] = {
    {"system", "",      "System default"},
    {"en",     "en_US", "English"},
    {"fa",     "fa_IR", "فارسی"},
    {"ar",     "ar",    "العربية"},
    {"tr",     "tr_TR", "Türkçe"},
    {"de",     "de_DE", "Deutsch"},
    {"fr",     "fr_FR", "Français"},
    {"es",     "es_ES", "Español"},
    {"ru",     "ru_RU", "Русский"},
    {"zh_CN",  "zh_CN", "简体中文"},
};

const LanguageEntry* entryForCode(const QString& code)
{
    for (const auto& entry : kLanguages) {
        if (code.compare(QLatin1String(entry.code), Qt::CaseInsensitive) == 0) {
            return &entry;
        }
    }
    return nullptr;
}
}

LanguageManager::LanguageManager(QObject* parent)
    : QObject(parent)
    , m_translator(new QTranslator(this))
{
    QSettings settings;
    settings.beginGroup(QLatin1String(kSettingsGroup));
    m_currentLanguage = normalizeLanguageCode(
        settings.value(QLatin1String(kLanguageKey), QStringLiteral("system")).toString());
    settings.endGroup();
    m_currentLocale = resolveLocale(m_currentLanguage);
}

LanguageManager::~LanguageManager() = default;

QString LanguageManager::currentLanguage() const
{
    return m_currentLanguage;
}

QString LanguageManager::currentLocale() const
{
    return m_currentLocale;
}

bool LanguageManager::rightToLeft() const
{
    return QLocale(m_currentLocale).textDirection() == Qt::RightToLeft;
}

QVariantList LanguageManager::availableLanguages() const
{
    QVariantList result;
    result.reserve(static_cast<qsizetype>(std::size(kLanguages)));
    for (const auto& entry : kLanguages) {
        QVariantMap item;
        item.insert(QStringLiteral("code"), QLatin1String(entry.code));
        item.insert(QStringLiteral("locale"), QLatin1String(entry.locale));
        item.insert(QStringLiteral("name"),
                    QLatin1String(entry.code) == QLatin1String("system")
                        ? tr("System default")
                        : QString::fromUtf8(entry.nativeName));
        result.push_back(item);
    }
    return result;
}

void LanguageManager::setQmlEngine(QQmlEngine* engine)
{
    m_engine = engine;
    if (applyLanguage(false)) return;

    const QString failedLanguage = m_currentLanguage;
    m_currentLanguage = QStringLiteral("en");
    m_currentLocale = QStringLiteral("en_US");
    applyLanguage(true);
    emit currentLanguageChanged();
    emit languageChangeFailed(failedLanguage);
}

bool LanguageManager::setLanguage(const QString& languageCode)
{
    const QString normalized = normalizeLanguageCode(languageCode);
    if (normalized == m_currentLanguage) {
        return true;
    }

    const QString previousLanguage = m_currentLanguage;
    const QString previousLocale = m_currentLocale;
    m_currentLanguage = normalized;
    m_currentLocale = resolveLocale(normalized);

    if (!applyLanguage(true)) {
        m_currentLanguage = previousLanguage;
        m_currentLocale = previousLocale;
        applyLanguage(false);
        emit languageChangeFailed(languageCode);
        return false;
    }

    emit currentLanguageChanged();
    return true;
}

QString LanguageManager::nativeLanguageName(const QString& languageCode) const
{
    const auto* entry = entryForCode(normalizeLanguageCode(languageCode));
    if (!entry) return languageCode;
    return QLatin1String(entry->code) == QLatin1String("system")
               ? tr("System default")
               : QString::fromUtf8(entry->nativeName);
}

QString LanguageManager::statusLabel(const QString& status) const
{
    if (status == QLatin1String("All")) return QCoreApplication::translate("DownloadStatus", "All");
    if (status == QLatin1String("Unfinished")) return QCoreApplication::translate("DownloadStatus", "Unfinished");
    if (status == QLatin1String("History")) return QCoreApplication::translate("DownloadStatus", "History");
    if (status == QLatin1String("Idle")) return QCoreApplication::translate("DownloadStatus", "Idle");
    if (status == QLatin1String("Active")) return QCoreApplication::translate("DownloadStatus", "Active");
    if (status == QLatin1String("Queued")) return QCoreApplication::translate("DownloadStatus", "Queued");
    if (status == QLatin1String("Paused")) return QCoreApplication::translate("DownloadStatus", "Paused");
    if (status == QLatin1String("Done")) return QCoreApplication::translate("DownloadStatus", "Done");
    if (status == QLatin1String("Complete")) return QCoreApplication::translate("DownloadStatus", "Complete");
    if (status == QLatin1String("Error")) return QCoreApplication::translate("DownloadStatus", "Error");
    if (status == QLatin1String("Canceled")) return QCoreApplication::translate("DownloadStatus", "Canceled");
    if (status == QLatin1String("Checking")) return QCoreApplication::translate("DownloadStatus", "Checking");
    if (status == QLatin1String("Metadata")) return QCoreApplication::translate("DownloadStatus", "Metadata");
    if (status == QLatin1String("Downloading")) return QCoreApplication::translate("DownloadStatus", "Downloading");
    if (status == QLatin1String("Seeding")) return QCoreApplication::translate("DownloadStatus", "Seeding");
    if (status == QLatin1String("Waiting")) return QCoreApplication::translate("DownloadStatus", "Waiting");
    if (status == QLatin1String("Receiving Data")) return QCoreApplication::translate("DownloadStatus", "Receiving Data");
    if (status == QLatin1String("Finalizing")) return QCoreApplication::translate("DownloadStatus", "Finalizing");
    if (status == QLatin1String("Online")) return QCoreApplication::translate("NetworkStatus", "Online");
    if (status == QLatin1String("Offline")) return QCoreApplication::translate("NetworkStatus", "Offline");
    if (status == QLatin1String("Local")) return QCoreApplication::translate("NetworkStatus", "Local");
    if (status == QLatin1String("Limited")) return QCoreApplication::translate("NetworkStatus", "Limited");
    if (status == QLatin1String("Unknown")) return QCoreApplication::translate("NetworkStatus", "Unknown");
    if (status == QLatin1String("Verifying")) return QCoreApplication::translate("VerificationStatus", "Verifying");
    if (status == QLatin1String("Failed")) return QCoreApplication::translate("VerificationStatus", "Failed");
    if (status == QLatin1String("Computed")) return QCoreApplication::translate("VerificationStatus", "Computed");
    if (status == QLatin1String("Mismatch")) return QCoreApplication::translate("VerificationStatus", "Mismatch");
    if (status == QLatin1String("OK")) return QCoreApplication::translate("VerificationStatus", "OK");
    return status;
}

QString LanguageManager::categoryLabel(const QString& category) const
{
    if (category == QLatin1String("Auto")) return QCoreApplication::translate("DownloadCategory", "Auto");
    if (category == QLatin1String("Video")) return QCoreApplication::translate("DownloadCategory", "Video");
    if (category == QLatin1String("Audio")) return QCoreApplication::translate("DownloadCategory", "Audio");
    if (category == QLatin1String("Images")) return QCoreApplication::translate("DownloadCategory", "Images");
    if (category == QLatin1String("Subtitles")) return QCoreApplication::translate("DownloadCategory", "Subtitles");
    if (category == QLatin1String("Archives")) return QCoreApplication::translate("DownloadCategory", "Archives");
    if (category == QLatin1String("Documents")) return QCoreApplication::translate("DownloadCategory", "Documents");
    if (category == QLatin1String("Programs")) return QCoreApplication::translate("DownloadCategory", "Programs");
    if (category == QLatin1String("Windows")) return QCoreApplication::translate("DownloadCategory", "Windows");
    if (category == QLatin1String("macOS")) return QCoreApplication::translate("DownloadCategory", "macOS");
    if (category == QLatin1String("Linux")) return QCoreApplication::translate("DownloadCategory", "Linux");
    if (category == QLatin1String("Android")) return QCoreApplication::translate("DownloadCategory", "Android");
    if (category == QLatin1String("Games")) return QCoreApplication::translate("DownloadCategory", "Games");
    if (category == QLatin1String("Disk Images")) return QCoreApplication::translate("DownloadCategory", "Disk Images");
    if (category == QLatin1String("Fonts")) return QCoreApplication::translate("DownloadCategory", "Fonts");
    if (category == QLatin1String("Code")) return QCoreApplication::translate("DownloadCategory", "Code");
    if (category == QLatin1String("Torrents")) return QCoreApplication::translate("DownloadCategory", "Torrents");
    if (category == QLatin1String("Torrent")) return QCoreApplication::translate("DownloadCategory", "Torrent");
    if (category == QLatin1String("IPFS")) return QCoreApplication::translate("DownloadCategory", "IPFS");
    if (category == QLatin1String("Arweave")) return QCoreApplication::translate("DownloadCategory", "Arweave");
    if (category == QLatin1String("NFT")) return QCoreApplication::translate("DownloadCategory", "NFT");
    if (category == QLatin1String("Other")) return QCoreApplication::translate("DownloadCategory", "Other");
    return category;
}

QString LanguageManager::queueLabel(const QString& queue) const
{
    // Queue names are user data. Only the built-in default queue has a
    // translatable display label; its stable English identifier remains intact.
    if (queue == QLatin1String("General"))
        return QCoreApplication::translate("DownloadQueue", "General");
    return queue;
}

QString LanguageManager::pauseReasonLabel(const QString& reason) const
{
    if (reason == QLatin1String("User")) return QCoreApplication::translate("PauseReason", "User");
    if (reason == QLatin1String("Network")) return QCoreApplication::translate("PauseReason", "Network");
    if (reason == QLatin1String("Network changed")) return QCoreApplication::translate("PauseReason", "Network changed");
    if (reason == QLatin1String("Network offline")) return QCoreApplication::translate("PauseReason", "Network offline");
    if (reason == QLatin1String("Server busy")) return QCoreApplication::translate("PauseReason", "Server busy");
    return reason;
}

QString LanguageManager::releaseStatusLabel(const QString& status) const
{
    if (status == QLatin1String("up_to_date")) return QCoreApplication::translate("ReleaseCenterService", "Up to date");
    if (status == QLatin1String("update_available")) return QCoreApplication::translate("ReleaseCenterService", "Update available");
    if (status == QLatin1String("downloaded")) return QCoreApplication::translate("ReleaseCenterService", "Ready to install");
    if (status == QLatin1String("check_failed")) return QCoreApplication::translate("ReleaseCenterService", "Check failed");
    if (status == QLatin1String("not_installed")) return QCoreApplication::translate("ReleaseCenterService", "Not installed");
    return QCoreApplication::translate("ReleaseCenterService", "Never checked");
}

QString LanguageManager::gatewayHealthLabel(int health) const
{
    switch (health) {
    case 1: return QCoreApplication::translate("GatewayService", "Healthy");
    case 2: return QCoreApplication::translate("GatewayService", "Slow");
    case 3: return QCoreApplication::translate("GatewayService", "Down");
    default: return QCoreApplication::translate("GatewayService", "Unknown");
    }
}

QString LanguageManager::normalizeLanguageCode(const QString& languageCode) const
{
    QString code = languageCode.trimmed();
    if (code.isEmpty()) {
        return QStringLiteral("system");
    }
    code.replace(QLatin1Char('-'), QLatin1Char('_'));

    if (entryForCode(code)) {
        return entryForCode(code)->code;
    }

    const QString prefix = code.section(QLatin1Char('_'), 0, 0).toLower();
    for (const auto& entry : kLanguages) {
        const QString supported = QLatin1String(entry.code);
        if (supported.section(QLatin1Char('_'), 0, 0).compare(prefix, Qt::CaseInsensitive) == 0
            && supported != QLatin1String("system")) {
            return supported;
        }
    }
    return QStringLiteral("system");
}

QString LanguageManager::resolveLocale(const QString& languageCode) const
{
    if (languageCode != QLatin1String("system")) {
        const auto* entry = entryForCode(languageCode);
        return entry ? QLatin1String(entry->locale) : QStringLiteral("en_US");
    }

    const QStringList uiLanguages = QLocale::system().uiLanguages();
    for (const QString& preferred : uiLanguages) {
        const QString supported = normalizeLanguageCode(preferred);
        if (supported != QLatin1String("system")) {
            const auto* entry = entryForCode(supported);
            return entry ? QLatin1String(entry->locale) : QLocale::system().name();
        }
    }
    return QLocale::system().name();
}

bool LanguageManager::applyLanguage(bool persist)
{
    if (m_translator) {
        QCoreApplication::removeTranslator(m_translator);
    }

    const QString catalogCode = normalizeLanguageCode(m_currentLocale);
    if (catalogCode != QLatin1String("en") && catalogCode != QLatin1String("system")) {
        const QString resourcePath =
            QStringLiteral(":/i18n/genydl_%1.qm").arg(catalogCode);
        if (!m_translator->load(resourcePath)) {
            return false;
        }
        QCoreApplication::installTranslator(m_translator);
    }

    const QLocale locale(m_currentLocale);
    QLocale::setDefault(locale);
    QGuiApplication::setLayoutDirection(locale.textDirection());

    if (m_engine) {
        m_engine->retranslate();
    }

    if (persist) {
        QSettings settings;
        settings.beginGroup(QLatin1String(kSettingsGroup));
        settings.setValue(QLatin1String(kLanguageKey), m_currentLanguage);
        settings.endGroup();
    }
    return true;
}
