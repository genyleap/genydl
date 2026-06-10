module;
#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QNetworkInformation>
#include <QProcess>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QTimer>
#include <algorithm>
#if defined(Q_OS_WIN)
#include <QSettings>
#endif

module genydl.services.release_center_service;

namespace {

constexpr int kRequestTimeoutMs = 30000;
constexpr int kMaxTransientRequestAttempts = 2;

QString dateTimeText(const QDateTime& value)
{
    return value.isValid() ? value.toLocalTime().toString(QStringLiteral("yyyy-MM-dd HH:mm")) : QStringLiteral("--");
}

QDateTime variantDateTime(const QVariant& value)
{
    if (value.canConvert<QDateTime>()) {
        return value.toDateTime();
    }
    const QString text = value.toString();
    return text.isEmpty() ? QDateTime() : QDateTime::fromString(text, Qt::ISODate);
}

QString statusText(const QString& status)
{
    if (status == QStringLiteral("up_to_date")) return QStringLiteral("Up to date");
    if (status == QStringLiteral("update_available")) return QStringLiteral("Update available");
    if (status == QStringLiteral("downloaded")) return QStringLiteral("Ready to install");
    if (status == QStringLiteral("check_failed")) return QStringLiteral("Check failed");
    if (status == QStringLiteral("not_installed")) return QStringLiteral("Not installed");
    return QStringLiteral("Never checked");
}

int statusRank(const QString& status)
{
    if (status == QStringLiteral("update_available")) return 0;
    if (status == QStringLiteral("downloaded")) return 1;
    if (status == QStringLiteral("not_installed")) return 2;
    if (status == QStringLiteral("check_failed")) return 3;
    if (status == QStringLiteral("never_checked")) return 4;
    return 5;
}

// Score a release asset for how well it matches the current OS + CPU arch, used
// to auto-pick the right download for a one-click update. Higher is better;
// 0 means "no platform signal" and a negative score means it looks like the
// wrong OS entirely.
int platformAssetScore(const QString& nameRaw)
{
    const QString name = nameRaw.toLower();
    int score = 0;

#if defined(Q_OS_MACOS)
    const QStringList good{QStringLiteral("mac"), QStringLiteral("macos"), QStringLiteral("osx"),
                           QStringLiteral("darwin"), QStringLiteral(".dmg"), QStringLiteral(".pkg")};
    const QStringList bad{QStringLiteral("win"), QStringLiteral(".exe"), QStringLiteral(".msi"),
                          QStringLiteral("linux"), QStringLiteral(".appimage"), QStringLiteral(".deb"),
                          QStringLiteral(".rpm")};
#elif defined(Q_OS_WIN)
    const QStringList good{QStringLiteral("win"), QStringLiteral("windows"), QStringLiteral(".exe"),
                           QStringLiteral(".msi")};
    const QStringList bad{QStringLiteral("mac"), QStringLiteral(".dmg"), QStringLiteral(".pkg"),
                          QStringLiteral("linux"), QStringLiteral(".appimage"), QStringLiteral(".deb"),
                          QStringLiteral(".rpm"), QStringLiteral("darwin")};
#else // Linux / other
    const QStringList good{QStringLiteral("linux"), QStringLiteral(".appimage"), QStringLiteral(".deb"),
                           QStringLiteral(".rpm"), QStringLiteral(".tar.gz"), QStringLiteral(".tar.xz")};
    const QStringList bad{QStringLiteral("mac"), QStringLiteral(".dmg"), QStringLiteral(".pkg"),
                          QStringLiteral("win"), QStringLiteral(".exe"), QStringLiteral(".msi"),
                          QStringLiteral("darwin")};
#endif

    for (const QString& token : good) if (name.contains(token)) { score += 10; break; }
    for (const QString& token : bad)  if (name.contains(token)) { score -= 20; break; }

    // CPU architecture bonus.
#if defined(Q_PROCESSOR_ARM)
    if (name.contains(QStringLiteral("arm64")) || name.contains(QStringLiteral("aarch64"))
        || name.contains(QStringLiteral("apple"))) score += 4;
    if (name.contains(QStringLiteral("x86_64")) || name.contains(QStringLiteral("amd64"))
        || name.contains(QStringLiteral("x64"))) score -= 2;
#else
    if (name.contains(QStringLiteral("x86_64")) || name.contains(QStringLiteral("amd64"))
        || name.contains(QStringLiteral("x64")) || name.contains(QStringLiteral("intel"))) score += 4;
    if (name.contains(QStringLiteral("arm64")) || name.contains(QStringLiteral("aarch64"))) score -= 2;
#endif
    return score;
}

// Returns the single best-matching asset for this platform, or an empty list if
// nothing scores positively (caller should fall back to the full picker).
QVariantList bestPlatformAssets(const QVariantList& assets)
{
    int bestScore = 0;
    QVariantMap best;
    for (const QVariant& v : assets) {
        const QVariantMap a = v.toMap();
        const int s = platformAssetScore(a.value(QStringLiteral("name")).toString());
        if (s > bestScore) { bestScore = s; best = a; }
    }
    QVariantList out;
    if (!best.isEmpty()) out.append(best);
    return out;
}

// Returns the absolute path of a completed download for the given asset, or an
// empty string. "Completed" means the final file exists, no ".part"/".partN"
// sibling remains, and the size matches when the asset size is known.
QString completedDownloadPath(const QStringList& roots, const QString& assetName, qint64 size)
{
    if (assetName.trimmed().isEmpty()) return {};
    for (const QString& root : roots) {
        if (root.isEmpty()) continue;
        QDir dir(root);
        if (!dir.exists()) continue;

        // Scan the root and one level of sub-folders (category folders).
        QStringList searchDirs{dir.absolutePath()};
        const auto subDirs = dir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
        for (const QString& sub : subDirs) {
            searchDirs.append(dir.absoluteFilePath(sub));
        }

        for (const QString& searchDir : searchDirs) {
            const QString candidate = QDir(searchDir).absoluteFilePath(assetName);
            QFileInfo info(candidate);
            if (!info.exists() || !info.isFile()) continue;
            if (QFile::exists(candidate + QStringLiteral(".part"))) continue;
            if (QFile::exists(candidate + QStringLiteral(".part0"))) continue;
            if (size > 0 && info.size() != size) continue;
            return info.absoluteFilePath();
        }
    }
    return {};
}

// Loose name match shared by all platform installed-version scanners. Tolerates
// "GenyConnect" vs "GenyConnect.app" vs "Geny Connect".
[[maybe_unused]] bool nameMatches(const QString& base, const QStringList& candidateNames)
{
    for (const QString& name : candidateNames) {
        const QString trimmed = name.trimmed();
        if (trimmed.isEmpty()) continue;
        if (base.compare(trimmed, Qt::CaseInsensitive) == 0) return true;
        const QString a = base.toLower().remove(QLatin1Char(' '));
        const QString b = trimmed.toLower().remove(QLatin1Char(' '));
        if (a == b) return true;
    }
    return false;
}

#if defined(Q_OS_MACOS)
// Best-effort: locate an installed .app bundle whose name matches one of the
// candidates and read CFBundleShortVersionString via `defaults read`.
QString macInstalledVersion(const QStringList& candidateNames)
{
    const QStringList appDirs{
        QStringLiteral("/Applications"),
        QDir::homePath() + QStringLiteral("/Applications")
    };
    for (const QString& appDir : appDirs) {
        QDir dir(appDir);
        if (!dir.exists()) continue;
        const auto bundles = dir.entryList(QStringList{QStringLiteral("*.app")}, QDir::Dirs);
        for (const QString& bundle : bundles) {
            const QString base = bundle.left(bundle.size() - 4); // strip ".app"
            if (!nameMatches(base, candidateNames)) continue;

            const QString infoPlist = dir.absoluteFilePath(bundle)
                + QStringLiteral("/Contents/Info");
            QProcess process;
            process.start(QStringLiteral("/usr/bin/defaults"),
                          {QStringLiteral("read"), infoPlist,
                           QStringLiteral("CFBundleShortVersionString")});
            if (!process.waitForFinished(2000)) {
                process.kill();
                process.waitForFinished(500);
                continue;
            }
            const QString version = QString::fromUtf8(process.readAllStandardOutput()).trimmed();
            if (!version.isEmpty()) return version;
        }
    }
    return {};
}
#endif // Q_OS_MACOS

#if defined(Q_OS_WIN)
// Scan the Windows "Uninstall" registry hives for a DisplayName matching one of
// the candidates and return its DisplayVersion.
QString windowsInstalledVersion(const QStringList& candidateNames)
{
    const QStringList hives{
        QStringLiteral("HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall"),
        QStringLiteral("HKEY_LOCAL_MACHINE\\SOFTWARE\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall"),
        QStringLiteral("HKEY_CURRENT_USER\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall")
    };
    for (const QString& hive : hives) {
        QSettings reg(hive, QSettings::NativeFormat);
        const QStringList keys = reg.childGroups();
        for (const QString& key : keys) {
            reg.beginGroup(key);
            const QString display = reg.value(QStringLiteral("DisplayName")).toString();
            const QString version = reg.value(QStringLiteral("DisplayVersion")).toString();
            reg.endGroup();
            if (!display.isEmpty() && nameMatches(display, candidateNames) && !version.isEmpty()) {
                return version;
            }
        }
    }
    return {};
}
#endif // Q_OS_WIN

#if !defined(Q_OS_MACOS) && !defined(Q_OS_WIN)
// Linux/other best-effort: find an executable named like the app on PATH and ask
// it for its version. Conservative — returns empty when nothing parses cleanly.
QString linuxInstalledVersion(const QStringList& candidateNames)
{
    for (const QString& nameRaw : candidateNames) {
        const QString name = nameRaw.trimmed();
        if (name.isEmpty()) continue;
        const QString exe = QStandardPaths::findExecutable(name.toLower());
        if (exe.isEmpty()) continue;

        for (const QString& flag : {QStringLiteral("--version"), QStringLiteral("-v")}) {
            QProcess process;
            process.start(exe, {flag});
            if (!process.waitForFinished(1500)) {
                process.kill();
                process.waitForFinished(300);
                continue;
            }
            const QString out = QString::fromUtf8(process.readAllStandardOutput())
                + QString::fromUtf8(process.readAllStandardError());
            const QRegularExpression re(QStringLiteral("\\b(\\d+\\.\\d+(?:\\.\\d+)?)\\b"));
            const auto m = re.match(out);
            if (m.hasMatch()) return m.captured(1);
        }
    }
    return {};
}
#endif // !macOS && !Windows

QJsonValue variantToJson(const QVariant& value)
{
    return QJsonValue::fromVariant(value);
}

bool isTransientGitHubNetworkError(QNetworkReply::NetworkError error)
{
    switch (error) {
    case QNetworkReply::RemoteHostClosedError:
    case QNetworkReply::TimeoutError:
    case QNetworkReply::TemporaryNetworkFailureError:
    case QNetworkReply::NetworkSessionFailedError:
    case QNetworkReply::ProxyTimeoutError:
    case QNetworkReply::UnknownNetworkError:
        return true;
    default:
        return false;
    }
}

QString gitHubNetworkErrorMessage(QNetworkReply::NetworkError error, const QString& detail)
{
    switch (error) {
    case QNetworkReply::TimeoutError:
    case QNetworkReply::ProxyTimeoutError:
        return QStringLiteral("GitHub request timed out. Check the connection and try again.");
    case QNetworkReply::RemoteHostClosedError:
        return QStringLiteral("GitHub closed the connection before the response finished. Try again.");
    case QNetworkReply::HostNotFoundError:
        return QStringLiteral("Could not reach GitHub. Check the network connection and try again.");
    case QNetworkReply::TemporaryNetworkFailureError:
    case QNetworkReply::NetworkSessionFailedError:
        return QStringLiteral("Network connection failed while contacting GitHub. Try again later.");
    default:
        break;
    }
    return QStringLiteral("Network error while contacting GitHub: %1").arg(detail);
}

QVariantMap releaseToAppFields(const genydl::github::ReleaseInfo& release)
{
    return {
        {QStringLiteral("latestTag"), release.tagName},
        {QStringLiteral("latestReleaseId"), release.id},
        {QStringLiteral("latestPublishedAt"), release.publishedAt},
        {QStringLiteral("latestReleaseName"), release.name},
        {QStringLiteral("latestBody"), release.body},
        {QStringLiteral("latestHtmlUrl"), release.htmlUrl.toString()},
        {QStringLiteral("latestAssets"), release.assetsToVariantList()},
        {QStringLiteral("latestSourceAssets"), release.sourceAssetsToVariantList()}
    };
}

} // namespace

namespace genydl::releasecenter {

QString TrackedGitHubApp::repositoryName() const
{
    return owner + QLatin1Char('/') + repo;
}

QVariantMap TrackedGitHubApp::toVariantMap() const
{
    return {
        {QStringLiteral("displayName"), displayName},
        {QStringLiteral("owner"), owner},
        {QStringLiteral("repo"), repo},
        {QStringLiteral("repository"), repositoryName()},
        {QStringLiteral("originalUrl"), originalUrl},
        {QStringLiteral("description"), description},
        {QStringLiteral("avatarUrl"), avatarUrl.toString()},
        {QStringLiteral("htmlUrl"), htmlUrl.toString()},
        {QStringLiteral("homepageUrl"), homepageUrl.toString()},
        {QStringLiteral("language"), language},
        {QStringLiteral("licenseName"), licenseName},
        {QStringLiteral("licenseSpdxId"), licenseSpdxId},
        {QStringLiteral("stars"), stars},
        {QStringLiteral("forks"), forks},
        {QStringLiteral("watchers"), watchers},
        {QStringLiteral("knownTag"), knownTag},
        {QStringLiteral("knownReleaseId"), knownReleaseId},
        {QStringLiteral("knownPublishedAt"), knownPublishedAt},
        {QStringLiteral("knownPublishedText"), dateTimeText(knownPublishedAt)},
        {QStringLiteral("installedVersion"), installedVersion},
        {QStringLiteral("installSource"), installSource},
        {QStringLiteral("downloadedAssets"), downloadedAssets},
        {QStringLiteral("latestTag"), latestTag},
        {QStringLiteral("latestReleaseId"), latestReleaseId},
        {QStringLiteral("latestPublishedAt"), latestPublishedAt},
        {QStringLiteral("latestPublishedText"), dateTimeText(latestPublishedAt)},
        {QStringLiteral("latestReleaseName"), latestReleaseName},
        {QStringLiteral("latestBody"), latestBody},
        {QStringLiteral("latestHtmlUrl"), latestHtmlUrl.toString()},
        {QStringLiteral("latestAssets"), latestAssets},
        {QStringLiteral("latestSourceAssets"), latestSourceAssets},
        {QStringLiteral("lastCheckedAt"), lastCheckedAt},
        {QStringLiteral("lastCheckedText"), dateTimeText(lastCheckedAt)},
        {QStringLiteral("status"), status},
        {QStringLiteral("statusText"), statusText(status)},
        {QStringLiteral("errorMessage"), errorMessage},
        {QStringLiteral("notificationsEnabled"), notificationsEnabled},
        {QStringLiteral("includePrereleases"), includePrereleases},
        {QStringLiteral("autoCheckEnabled"), autoCheckEnabled},
        {QStringLiteral("assetFilters"), assetFilters}
    };
}

TrackedGitHubApp appFromVariantMap(const QVariantMap& map)
{
    genydl::releasecenter::TrackedGitHubApp app;
    app.displayName = map.value(QStringLiteral("displayName")).toString();
    app.owner = map.value(QStringLiteral("owner")).toString();
    app.repo = map.value(QStringLiteral("repo")).toString();
    app.originalUrl = map.value(QStringLiteral("originalUrl")).toString();
    app.description = map.value(QStringLiteral("description")).toString();
    app.avatarUrl = QUrl(map.value(QStringLiteral("avatarUrl")).toString());
    app.htmlUrl = QUrl(map.value(QStringLiteral("htmlUrl")).toString());
    app.homepageUrl = QUrl(map.value(QStringLiteral("homepageUrl")).toString());
    app.language = map.value(QStringLiteral("language")).toString();
    app.licenseName = map.value(QStringLiteral("licenseName")).toString();
    app.licenseSpdxId = map.value(QStringLiteral("licenseSpdxId")).toString();
    app.stars = map.value(QStringLiteral("stars")).toInt();
    app.forks = map.value(QStringLiteral("forks")).toInt();
    app.watchers = map.value(QStringLiteral("watchers")).toInt();
    app.knownTag = map.value(QStringLiteral("knownTag")).toString();
    app.knownReleaseId = map.value(QStringLiteral("knownReleaseId")).toLongLong();
    app.knownPublishedAt = variantDateTime(map.value(QStringLiteral("knownPublishedAt")));
    app.installedVersion = map.value(QStringLiteral("installedVersion")).toString();
    app.installSource = map.value(QStringLiteral("installSource")).toString();
    app.latestTag = map.value(QStringLiteral("latestTag")).toString();
    app.latestReleaseId = map.value(QStringLiteral("latestReleaseId")).toLongLong();
    app.latestPublishedAt = variantDateTime(map.value(QStringLiteral("latestPublishedAt")));
    app.latestReleaseName = map.value(QStringLiteral("latestReleaseName")).toString();
    app.latestBody = map.value(QStringLiteral("latestBody")).toString();
    app.latestHtmlUrl = QUrl(map.value(QStringLiteral("latestHtmlUrl")).toString());
    app.latestAssets = map.value(QStringLiteral("latestAssets")).toList();
    app.latestSourceAssets = map.value(QStringLiteral("latestSourceAssets")).toList();
    app.lastCheckedAt = variantDateTime(map.value(QStringLiteral("lastCheckedAt")));
    app.status = map.value(QStringLiteral("status"), QStringLiteral("never_checked")).toString();
    app.errorMessage = map.value(QStringLiteral("errorMessage")).toString();
    app.notificationsEnabled = map.value(QStringLiteral("notificationsEnabled"), true).toBool();
    app.includePrereleases = map.value(QStringLiteral("includePrereleases"), false).toBool();
    app.autoCheckEnabled = map.value(QStringLiteral("autoCheckEnabled"), true).toBool();
    app.assetFilters = map.value(QStringLiteral("assetFilters")).toStringList();
    return app;
}

QVariantMap appToVariantMap(const TrackedGitHubApp& app)
{
    return app.toVariantMap();
}

QVariantList appsToVariantList(const QVector<TrackedGitHubApp>& apps)
{
    QVector<int> indexes;
    indexes.reserve(apps.size());
    for (int i = 0; i < apps.size(); ++i) {
        indexes.push_back(i);
    }
    std::sort(indexes.begin(), indexes.end(), [&apps](int lhs, int rhs) {
        const int lhsRank = statusRank(apps.at(lhs).status);
        const int rhsRank = statusRank(apps.at(rhs).status);
        if (lhsRank != rhsRank) return lhsRank < rhsRank;
        return apps.at(lhs).displayName.compare(apps.at(rhs).displayName, Qt::CaseInsensitive) < 0;
    });

    QVariantList list;
    list.reserve(apps.size());
    for (int index : indexes) {
        QVariantMap map = apps.at(index).toVariantMap();
        map.insert(QStringLiteral("rowIndex"), index);
        list.append(map);
    }
    return list;
}

QByteArray saveDocumentForApps(const QVector<TrackedGitHubApp>& apps,
                               const QVariantMap& settings)
{
    QJsonArray appArray;
    for (const TrackedGitHubApp& app : apps) {
        appArray.append(QJsonObject::fromVariantMap(app.toVariantMap()));
    }

    QJsonObject root;
    root.insert(QStringLiteral("version"), 1);
    root.insert(QStringLiteral("settings"), QJsonObject::fromVariantMap(settings));
    root.insert(QStringLiteral("apps"), appArray);
    return QJsonDocument(root).toJson(QJsonDocument::Indented);
}

bool loadDocumentIntoApps(const QByteArray& data,
                          QVector<TrackedGitHubApp>* apps,
                          QVariantMap* settingsOut,
                          QString* errorMessage)
{
    QJsonParseError parseError;
    const QJsonDocument doc = QJsonDocument::fromJson(data, &parseError);
    if (parseError.error != QJsonParseError::NoError || !doc.isObject()) {
        if (errorMessage) {
            *errorMessage = QStringLiteral("Release Center storage is malformed.");
        }
        return false;
    }

    const QJsonObject root = doc.object();
    if (settingsOut) {
        *settingsOut = root.value(QStringLiteral("settings")).toObject().toVariantMap();
    }

    QVector<TrackedGitHubApp> loaded;
    const QJsonArray appArray = root.value(QStringLiteral("apps")).toArray();
    loaded.reserve(appArray.size());
    for (const QJsonValue& value : appArray) {
        if (!value.isObject()) continue;
        TrackedGitHubApp app = appFromVariantMap(value.toObject().toVariantMap());
        if (!app.owner.isEmpty() && !app.repo.isEmpty()) {
            loaded.push_back(app);
        }
    }
    if (apps) {
        *apps = loaded;
    }
    return true;
}

bool releaseIsNewerThanKnown(const genydl::github::ReleaseInfo& release, const TrackedGitHubApp& app)
{
    genydl::github::ReleaseInfo known;
    known.id = app.knownReleaseId;
    known.tagName = app.knownTag;
    known.publishedAt = app.knownPublishedAt;
    return genydl::github::isNewerRelease(release, known);
}

} // namespace genydl::releasecenter

GitHubReleaseTrackerService::GitHubReleaseTrackerService(QObject* parent)
    : QObject(parent)
{
    load();
    QNetworkInformation::loadDefaultBackend();   // best-effort; for metered detection
    connect(&m_autoTimer, &QTimer::timeout, this, &GitHubReleaseTrackerService::runScheduledCheck);
    startAutoTimer();
}

QVariantList GitHubReleaseTrackerService::apps() const
{
    return genydl::releasecenter::appsToVariantList(m_apps);
}

bool GitHubReleaseTrackerService::loading() const { return m_loading; }
QString GitHubReleaseTrackerService::errorMessage() const { return m_errorMessage; }
QString GitHubReleaseTrackerService::rateLimitWarning() const { return m_rateLimitWarning; }
QVariantMap GitHubReleaseTrackerService::preview() const { return m_preview; }
QVariantList GitHubReleaseTrackerService::previewAssets() const { return m_previewAssets; }
bool GitHubReleaseTrackerService::automaticChecksEnabled() const { return m_automaticChecksEnabled; }
int GitHubReleaseTrackerService::checkIntervalHours() const { return m_checkIntervalHours; }
bool GitHubReleaseTrackerService::showNotifications() const { return m_showNotifications; }
bool GitHubReleaseTrackerService::defaultIncludePrereleases() const { return m_defaultIncludePrereleases; }
QString GitHubReleaseTrackerService::userAgent() const
{
    if (!m_userAgent.trimmed().isEmpty()) return m_userAgent.trimmed();
    const QString version = QCoreApplication::applicationVersion().isEmpty()
        ? QStringLiteral("0.1.0")
        : QCoreApplication::applicationVersion();
    return QStringLiteral("GenyDLDownloadManager/%1").arg(version);
}
QString GitHubReleaseTrackerService::githubToken() const { return m_githubToken; }

void GitHubReleaseTrackerService::setAutomaticChecksEnabled(bool enabled)
{
    if (m_automaticChecksEnabled == enabled) return;
    m_automaticChecksEnabled = enabled;
    save();
    startAutoTimer();
    emit settingsChanged();
}

void GitHubReleaseTrackerService::setCheckIntervalHours(int hours)
{
    const int normalized = std::max(1, std::min(168, hours));
    if (m_checkIntervalHours == normalized) return;
    m_checkIntervalHours = normalized;
    save();
    startAutoTimer();
    emit settingsChanged();
}

void GitHubReleaseTrackerService::setShowNotifications(bool enabled)
{
    if (m_showNotifications == enabled) return;
    m_showNotifications = enabled;
    save();
    emit settingsChanged();
}

void GitHubReleaseTrackerService::setDefaultIncludePrereleases(bool enabled)
{
    if (m_defaultIncludePrereleases == enabled) return;
    m_defaultIncludePrereleases = enabled;
    save();
    emit settingsChanged();
}

void GitHubReleaseTrackerService::setUserAgent(const QString& value)
{
    const QString trimmed = value.trimmed();
    if (m_userAgent == trimmed) return;
    m_userAgent = trimmed;
    save();
    emit settingsChanged();
}

void GitHubReleaseTrackerService::setGithubToken(const QString& value)
{
    const QString trimmed = value.trimmed();
    if (m_githubToken == trimmed) return;
    m_githubToken = trimmed;
    save();
    emit settingsChanged();
}

QString GitHubReleaseTrackerService::dateFormat() const { return m_dateFormat; }
QString GitHubReleaseTrackerService::downloadPolicy() const { return m_downloadPolicy; }
bool GitHubReleaseTrackerService::onlyWhenOpen() const { return m_onlyWhenOpen; }
bool GitHubReleaseTrackerService::backgroundChecks() const { return m_backgroundChecks; }
bool GitHubReleaseTrackerService::wifiOnly() const { return m_wifiOnly; }

void GitHubReleaseTrackerService::setDateFormat(const QString& value)
{
    static const QStringList allowed{QStringLiteral("relative"), QStringLiteral("datetime"),
                                     QStringLiteral("day"), QStringLiteral("month")};
    const QString next = allowed.contains(value) ? value : QStringLiteral("datetime");
    if (m_dateFormat == next) return;
    m_dateFormat = next;
    save();
    emit settingsChanged();
}

void GitHubReleaseTrackerService::setDownloadPolicy(const QString& value)
{
    static const QStringList allowed{QStringLiteral("notify"), QStringLiteral("ask"),
                                     QStringLiteral("auto")};
    const QString next = allowed.contains(value) ? value : QStringLiteral("notify");
    if (m_downloadPolicy == next) return;
    m_downloadPolicy = next;
    save();
    emit settingsChanged();
}

void GitHubReleaseTrackerService::setOnlyWhenOpen(bool value)
{
    if (m_onlyWhenOpen == value) return;
    m_onlyWhenOpen = value;
    save();
    startAutoTimer();
    emit settingsChanged();
}

void GitHubReleaseTrackerService::setBackgroundChecks(bool value)
{
    if (m_backgroundChecks == value) return;
    m_backgroundChecks = value;
    save();
    startAutoTimer();
    emit settingsChanged();
}

void GitHubReleaseTrackerService::setWifiOnly(bool value)
{
    if (m_wifiOnly == value) return;
    m_wifiOnly = value;
    save();
    emit settingsChanged();
}

bool GitHubReleaseTrackerService::windowActive() const { return m_windowActive; }

void GitHubReleaseTrackerService::setWindowActive(bool value)
{
    if (m_windowActive == value) return;
    m_windowActive = value;
    emit windowActiveChanged();
}

bool GitHubReleaseTrackerService::meteredConnection() const
{
    auto* info = QNetworkInformation::instance();
    if (info && info->supports(QNetworkInformation::Feature::Metered)) {
        return info->isMetered();
    }
    return false;   // unknown -> treat as non-metered (fail open)
}

void GitHubReleaseTrackerService::runScheduledCheck()
{
    // "Only when open": require the window to be active. Otherwise allow checks
    // while minimized only when background checks are explicitly enabled.
    const bool allowedByVisibility = m_windowActive
        || (!m_onlyWhenOpen && m_backgroundChecks);
    if (!allowedByVisibility) return;

    // Respect metered connections when the user asked to check on Wi-Fi only.
    if (m_wifiOnly && meteredConnection()) return;

    checkAll();
}

bool GitHubReleaseTrackerService::isSupportedUrl(const QString& value) const
{
    return genydl::github::parseRepositoryUrl(value).has_value();
}

QString GitHubReleaseTrackerService::normalizedRepository(const QString& value) const
{
    const auto repo = genydl::github::parseRepositoryUrl(value);
    return repo ? repo->repositoryName() : QString();
}

void GitHubReleaseTrackerService::previewApp(const QString& value)
{
    const auto repo = genydl::github::parseRepositoryUrl(value);
    if (!repo) {
        setErrorMessage(QStringLiteral("Paste a GitHub repository or releases page URL."));
        return;
    }

    startRequest(genydl::github::repositoryApiUrlForRepository(*repo), RequestMode::RepositoryPreview, -1, *repo, m_defaultIncludePrereleases);
}

bool GitHubReleaseTrackerService::confirmPreview(const QString& displayName)
{
    if (m_preview.isEmpty() || !m_previewRepo.isValid()) {
        setErrorMessage(QStringLiteral("No GitHub release preview is ready."));
        return false;
    }
    for (const auto& app : m_apps) {
        if (app.owner.compare(m_previewRepo.owner, Qt::CaseInsensitive) == 0
            && app.repo.compare(m_previewRepo.repo, Qt::CaseInsensitive) == 0) {
            setErrorMessage(QStringLiteral("This repository is already tracked in Release Center."));
            return false;
        }
    }

    genydl::releasecenter::TrackedGitHubApp app;
    app.owner = m_previewRepo.owner;
    app.repo = m_previewRepo.repo;
    app.originalUrl = m_previewRepo.originalUrl;
    app.description = m_preview.value(QStringLiteral("description")).toString();
    app.avatarUrl = QUrl(m_preview.value(QStringLiteral("avatarUrl")).toString());
    app.htmlUrl = QUrl(m_preview.value(QStringLiteral("htmlUrl")).toString());
    app.homepageUrl = QUrl(m_preview.value(QStringLiteral("homepageUrl")).toString());
    app.language = m_preview.value(QStringLiteral("language")).toString();
    app.licenseName = m_preview.value(QStringLiteral("licenseName")).toString();
    app.licenseSpdxId = m_preview.value(QStringLiteral("licenseSpdxId")).toString();
    app.stars = m_preview.value(QStringLiteral("stars")).toInt();
    app.forks = m_preview.value(QStringLiteral("forks")).toInt();
    app.watchers = m_preview.value(QStringLiteral("watchers")).toInt();
    app.displayName = displayName.trimmed().isEmpty()
        ? m_preview.value(QStringLiteral("displayName")).toString()
        : displayName.trimmed();
    // A freshly tracked repository is NOT considered installed: the user has
    // only added it to watch. "knownTag" represents the version the user has
    // actually downloaded/installed via GenyDL and stays empty until then.
    app.knownTag.clear();
    app.knownReleaseId = 0;
    app.knownPublishedAt = QDateTime();
    app.latestTag = m_preview.value(QStringLiteral("latestTag")).toString();
    app.latestReleaseId = m_preview.value(QStringLiteral("latestReleaseId")).toLongLong();
    app.latestPublishedAt = variantDateTime(m_preview.value(QStringLiteral("latestPublishedAt")));
    app.latestReleaseName = m_preview.value(QStringLiteral("latestReleaseName")).toString();
    app.latestBody = m_preview.value(QStringLiteral("latestBody")).toString();
    app.latestHtmlUrl = QUrl(m_preview.value(QStringLiteral("latestHtmlUrl")).toString());
    app.latestAssets = m_previewAssets;
    app.latestSourceAssets = m_preview.value(QStringLiteral("latestSourceAssets")).toList();
    app.lastCheckedAt = QDateTime::currentDateTimeUtc();
    app.notificationsEnabled = true;
    app.includePrereleases = m_defaultIncludePrereleases;
    app.autoCheckEnabled = true;
    // Discover whether this app is already installed/downloaded rather than
    // assuming "not installed".
    detectInstallState(app);

    m_apps.push_back(app);
    save();
    clearPreview();
    emit appsChanged();
    return true;
}

void GitHubReleaseTrackerService::clearPreview()
{
    if (!m_preview.isEmpty()) {
        m_preview.clear();
        emit previewChanged();
    }
    if (!m_previewAssets.isEmpty()) {
        m_previewAssets.clear();
        emit previewAssetsChanged();
    }
    m_previewRepo = {};
}

void GitHubReleaseTrackerService::removeApp(int index)
{
    if (index < 0 || index >= m_apps.size()) return;
    m_apps.removeAt(index);
    save();
    emit appsChanged();
}

void GitHubReleaseTrackerService::checkApp(int index)
{
    if (index < 0 || index >= m_apps.size()) return;
    const auto repo = genydl::github::RepositoryRequest{
        m_apps.at(index).owner,
        m_apps.at(index).repo,
        m_apps.at(index).originalUrl
    };
    const bool includePrereleases = m_apps.at(index).includePrereleases;
    const QUrl url = includePrereleases
        ? genydl::github::releasesApiUrlForRepository(repo)
        : genydl::github::latestReleaseApiUrlForRepository(repo);
    startRequest(url, RequestMode::Check, index, repo, includePrereleases);
}

void GitHubReleaseTrackerService::checkAll()
{
    if (m_activeReply) return;
    m_pendingChecks.clear();
    for (int i = 0; i < m_apps.size(); ++i) {
        if (m_apps.at(i).autoCheckEnabled) {
            m_pendingChecks.append(i);
        }
    }
    runNextPendingCheck();
}

void GitHubReleaseTrackerService::setAppAutoCheckEnabled(int index, bool enabled)
{
    if (index < 0 || index >= m_apps.size() || m_apps[index].autoCheckEnabled == enabled) return;
    m_apps[index].autoCheckEnabled = enabled;
    save();
    emit appsChanged();
}

void GitHubReleaseTrackerService::setAppIncludePrereleases(int index, bool enabled)
{
    if (index < 0 || index >= m_apps.size() || m_apps[index].includePrereleases == enabled) return;
    m_apps[index].includePrereleases = enabled;
    save();
    emit appsChanged();
}

void GitHubReleaseTrackerService::setAppNotificationsEnabled(int index, bool enabled)
{
    if (index < 0 || index >= m_apps.size() || m_apps[index].notificationsEnabled == enabled) return;
    m_apps[index].notificationsEnabled = enabled;
    save();
    emit appsChanged();
}

void GitHubReleaseTrackerService::markLatestKnown(int index)
{
    if (index < 0 || index >= m_apps.size()) return;
    auto& app = m_apps[index];
    app.knownTag = app.latestTag;
    app.knownReleaseId = app.latestReleaseId;
    app.knownPublishedAt = app.latestPublishedAt;
    app.installedVersion = app.latestTag;
    app.installSource = QStringLiteral("manual");
    app.status = QStringLiteral("up_to_date");
    app.errorMessage.clear();
    save();
    emit appsChanged();
}

void GitHubReleaseTrackerService::reload()
{
    load();
    emit appsChanged();
}

void GitHubReleaseTrackerService::load()
{
    QFile file(storagePath());
    if (!file.exists()) return;
    if (!file.open(QIODevice::ReadOnly)) {
        setErrorMessage(QStringLiteral("Could not read Release Center storage."));
        return;
    }

    QString error;
    QVariantMap settings;
    if (!genydl::releasecenter::loadDocumentIntoApps(file.readAll(), &m_apps, &settings, &error)) {
        setErrorMessage(error);
    } else {
        m_automaticChecksEnabled = settings.value(QStringLiteral("automaticChecksEnabled"), false).toBool();
        m_checkIntervalHours = std::max(1, settings.value(QStringLiteral("checkIntervalHours"), 24).toInt());
        m_showNotifications = settings.value(QStringLiteral("showNotifications"), true).toBool();
        m_defaultIncludePrereleases = settings.value(QStringLiteral("defaultIncludePrereleases"), false).toBool();
        m_userAgent = settings.value(QStringLiteral("userAgent")).toString();
        m_githubToken = settings.value(QStringLiteral("githubToken")).toString();
        m_dateFormat = settings.value(QStringLiteral("dateFormat"), QStringLiteral("datetime")).toString();
        m_downloadPolicy = settings.value(QStringLiteral("downloadPolicy"), QStringLiteral("notify")).toString();
        m_onlyWhenOpen = settings.value(QStringLiteral("onlyWhenOpen"), true).toBool();
        m_backgroundChecks = settings.value(QStringLiteral("backgroundChecks"), false).toBool();
        m_wifiOnly = settings.value(QStringLiteral("wifiOnly"), false).toBool();
    }

    // Re-evaluate install/download state for every tracked app on load so the
    // status reflects the current machine rather than the persisted snapshot.
    for (auto& app : m_apps) {
        detectInstallState(app);
    }
}

void GitHubReleaseTrackerService::save()
{
    const QString path = storagePath();
    QDir().mkpath(QFileInfo(path).absolutePath());
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        setErrorMessage(QStringLiteral("Could not save Release Center storage."));
        return;
    }
    const QVariantMap settings{
        {QStringLiteral("automaticChecksEnabled"), m_automaticChecksEnabled},
        {QStringLiteral("checkIntervalHours"), m_checkIntervalHours},
        {QStringLiteral("showNotifications"), m_showNotifications},
        {QStringLiteral("defaultIncludePrereleases"), m_defaultIncludePrereleases},
        {QStringLiteral("userAgent"), m_userAgent},
        {QStringLiteral("githubToken"), m_githubToken},
        {QStringLiteral("dateFormat"), m_dateFormat},
        {QStringLiteral("downloadPolicy"), m_downloadPolicy},
        {QStringLiteral("onlyWhenOpen"), m_onlyWhenOpen},
        {QStringLiteral("backgroundChecks"), m_backgroundChecks},
        {QStringLiteral("wifiOnly"), m_wifiOnly}
    };
    file.write(genydl::releasecenter::saveDocumentForApps(m_apps, settings));
}

void GitHubReleaseTrackerService::startAutoTimer()
{
    m_autoTimer.stop();
    if (!m_automaticChecksEnabled) return;
    m_autoTimer.setInterval(std::max(1, m_checkIntervalHours) * 60 * 60 * 1000);
    m_autoTimer.start();
}

void GitHubReleaseTrackerService::setLoading(bool value)
{
    if (m_loading == value) return;
    m_loading = value;
    emit loadingChanged();
}

void GitHubReleaseTrackerService::setErrorMessage(const QString& value)
{
    if (m_errorMessage == value) return;
    m_errorMessage = value;
    emit errorMessageChanged();
}

void GitHubReleaseTrackerService::setRateLimitWarning(const QString& value)
{
    if (m_rateLimitWarning == value) return;
    m_rateLimitWarning = value;
    emit rateLimitWarningChanged();
}

void GitHubReleaseTrackerService::setPreviewRelease(const genydl::github::RepositoryRequest& repo,
                                                    const genydl::github::ReleaseInfo& release)
{
    QVariantMap map = releaseToAppFields(release);
    for (auto it = m_preview.constBegin(); it != m_preview.constEnd(); ++it) {
        map.insert(it.key(), it.value());
    }
    map.insert(QStringLiteral("owner"), repo.owner);
    map.insert(QStringLiteral("repo"), repo.repo);
    map.insert(QStringLiteral("repository"), repo.repositoryName());
    map.insert(QStringLiteral("originalUrl"), repo.originalUrl);
    if (map.value(QStringLiteral("displayName")).toString().isEmpty()) {
        map.insert(QStringLiteral("displayName"), fallbackDisplayName(repo, release));
    }
    m_preview = map;
    m_previewAssets = release.assetsToVariantList();
    m_previewRepo = repo;
    emit previewChanged();
    emit previewAssetsChanged();
}

void GitHubReleaseTrackerService::startRequest(const QUrl& url,
                                               RequestMode mode,
                                               int appIndex,
                                               const genydl::github::RepositoryRequest& repo,
                                               bool includePrereleases,
                                               int attempt)
{
    if (m_activeReply) {
        m_activeReply->abort();
        m_activeReply->deleteLater();
        m_activeReply.clear();
    }

    setErrorMessage(QString());
    setLoading(true);
    QNetworkReply* reply = m_network.get(makeRequest(url));
    m_activeReply = reply;
    connect(reply, &QNetworkReply::finished, this, [this, reply, mode, appIndex, repo, includePrereleases, attempt]() {
        handleReply(reply, mode, appIndex, repo, includePrereleases, attempt);
    });
}

void GitHubReleaseTrackerService::handleReply(QNetworkReply* reply,
                                              RequestMode mode,
                                              int appIndex,
                                              genydl::github::RepositoryRequest repo,
                                              bool includePrereleases,
                                              int attempt)
{
    if (m_activeReply == reply) {
        m_activeReply.clear();
    }

    const int statusCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    // Reading a transport-failed (e.g. SSL handshake) reply whose socket is
    // already closed logs "QSslSocket: device not open"; guard with isOpen().
    // HTTP error statuses (4xx/5xx) keep the socket open, so their JSON body is
    // still read here.
    const QByteArray body = reply->isOpen() ? reply->readAll() : QByteArray();
    const bool rateLimited = reply->rawHeader("X-RateLimit-Remaining") == QByteArray("0");
    const QByteArray reset = reply->rawHeader("X-RateLimit-Reset");
    const QNetworkReply::NetworkError networkError = reply->error();
    const QString networkDetail = reply->errorString();
    reply->deleteLater();

    if (rateLimited) {
        const qint64 resetSeconds = QString::fromUtf8(reset).toLongLong();
        const QDateTime resetAt = resetSeconds > 0 ? QDateTime::fromSecsSinceEpoch(resetSeconds) : QDateTime();
        setRateLimitWarning(resetAt.isValid()
                            ? QStringLiteral("GitHub API rate limit reached. Automatic checks paused until %1.")
                                  .arg(resetAt.toLocalTime().toString(QStringLiteral("yyyy-MM-dd HH:mm")))
                            : QStringLiteral("GitHub API rate limit reached. Automatic checks paused."));
        m_pendingChecks.clear();
    }

    auto fail = [this, mode, appIndex](const QString& message) {
        setLoading(false);
        setErrorMessage(message);
        if (mode == RequestMode::Check && appIndex >= 0 && appIndex < m_apps.size()) {
            m_apps[appIndex].status = QStringLiteral("check_failed");
            m_apps[appIndex].errorMessage = message;
            m_apps[appIndex].lastCheckedAt = QDateTime::currentDateTimeUtc();
            save();
            emit appsChanged();
            emit appCheckFinished(appIndex);
        }
        runNextPendingCheck();
    };

    if (networkError != QNetworkReply::NoError) {
        if (statusCode < 400
            && isTransientGitHubNetworkError(networkError)
            && attempt < kMaxTransientRequestAttempts) {
            QTimer::singleShot(350 * (attempt + 1), this, [this, mode, appIndex, repo, includePrereleases, attempt, url = reply->url()]() {
                startRequest(url, mode, appIndex, repo, includePrereleases, attempt + 1);
            });
            return;
        }
        if (mode == RequestMode::RepositoryPreview && statusCode < 400) {
            m_preview = {
                {QStringLiteral("owner"), repo.owner},
                {QStringLiteral("repo"), repo.repo},
                {QStringLiteral("repository"), repo.repositoryName()},
                {QStringLiteral("originalUrl"), repo.originalUrl},
                {QStringLiteral("displayName"), repo.repo},
                {QStringLiteral("htmlUrl"), QStringLiteral("https://github.com/%1").arg(repo.repositoryName())}
            };
            emit previewChanged();

            const QUrl releaseUrl = includePrereleases
                ? genydl::github::releasesApiUrlForRepository(repo)
                : genydl::github::latestReleaseApiUrlForRepository(repo);
            startRequest(releaseUrl, RequestMode::Preview, appIndex, repo, includePrereleases);
            return;
        }
        fail(statusCode >= 400
             ? genydl::github::userFriendlyApiError(statusCode, body, rateLimited)
             : gitHubNetworkErrorMessage(networkError, networkDetail));
        return;
    }
    if (statusCode >= 400) {
        fail(genydl::github::userFriendlyApiError(statusCode, body, rateLimited));
        return;
    }

    if (mode == RequestMode::RepositoryPreview) {
        QString parseError;
        auto repoInfo = genydl::github::parseRepositoryJson(body, &parseError);
        if (!repoInfo) {
            m_preview = {
                {QStringLiteral("owner"), repo.owner},
                {QStringLiteral("repo"), repo.repo},
                {QStringLiteral("repository"), repo.repositoryName()},
                {QStringLiteral("originalUrl"), repo.originalUrl},
                {QStringLiteral("displayName"), repo.repo},
                {QStringLiteral("htmlUrl"), QStringLiteral("https://github.com/%1").arg(repo.repositoryName())}
            };
            emit previewChanged();

            const QUrl releaseUrl = includePrereleases
                ? genydl::github::releasesApiUrlForRepository(repo)
                : genydl::github::latestReleaseApiUrlForRepository(repo);
            startRequest(releaseUrl, RequestMode::Preview, appIndex, repo, includePrereleases);
            return;
        }

        m_preview = repoInfo->toVariantMap();
        m_preview.insert(QStringLiteral("displayName"), repoInfo->repo);
        emit previewChanged();

        const QUrl releaseUrl = includePrereleases
            ? genydl::github::releasesApiUrlForRepository(repo)
            : genydl::github::latestReleaseApiUrlForRepository(repo);
        startRequest(releaseUrl, RequestMode::Preview, appIndex, repo, includePrereleases);
        return;
    }

    QString parseError;
    std::optional<genydl::github::ReleaseInfo> release = includePrereleases
        ? genydl::github::parseLatestReleaseFromListJson(body, true, &parseError)
        : genydl::github::parseReleaseJson(body, &parseError);
    if (!release) {
        fail(parseError.isEmpty() ? QStringLiteral("This repository does not publish releases.") : parseError);
        return;
    }
    if (release->owner.isEmpty()) release->owner = repo.owner;
    if (release->repo.isEmpty()) release->repo = repo.repo;

    if (mode == RequestMode::Preview) {
        setPreviewRelease(repo, *release);
        setLoading(false);
    } else if (mode == RequestMode::Check) {
        applyCheckResult(appIndex, *release);
        setLoading(false);
        emit appCheckFinished(appIndex);
    }
    runNextPendingCheck();
}

void GitHubReleaseTrackerService::applyCheckResult(int appIndex, const genydl::github::ReleaseInfo& release)
{
    if (appIndex < 0 || appIndex >= m_apps.size()) return;

    auto& app = m_apps[appIndex];
    app.latestTag = release.tagName;
    app.latestReleaseId = release.id;
    app.latestPublishedAt = release.publishedAt;
    app.latestReleaseName = release.name;
    app.latestBody = release.body;
    app.latestHtmlUrl = release.htmlUrl;
    app.latestAssets = release.assetsToVariantList();
    app.latestSourceAssets = release.sourceAssetsToVariantList();
    app.lastCheckedAt = QDateTime::currentDateTimeUtc();
    app.errorMessage.clear();

    // Status reflects what is actually present on this machine: an installed app
    // bundle (OS scan), a completed download, or a manually marked version. The
    // detector never silently pretends a freshly-tracked repo is up to date.
    const QString previousStatus = app.status;
    detectInstallState(app);

    save();
    emit appsChanged();

    const bool newlyAvailable = app.status == QStringLiteral("update_available")
        && previousStatus != QStringLiteral("update_available");
    if (newlyAvailable) {
        if (app.notificationsEnabled && m_showNotifications) {
            emit appUpdateFound(app.displayName, release.tagName, appIndex);
        }
        // Apply the download policy. "notify" only raises the notification above;
        // "ask" and "auto" additionally surface the best platform asset so the UI
        // can prompt or start the download directly.
        if (m_downloadPolicy != QStringLiteral("notify")) {
            const QVariantList chosen = bestPlatformAssets(app.latestAssets);
            if (!chosen.isEmpty()) {
                emit appAutoDownloadRequested(appIndex, chosen,
                                              m_downloadPolicy == QStringLiteral("auto"));
            }
        }
    }
}

QVariantList GitHubReleaseTrackerService::platformAssetsForApp(int index) const
{
    if (index < 0 || index >= m_apps.size()) return {};
    return bestPlatformAssets(m_apps[index].latestAssets);
}

QString GitHubReleaseTrackerService::osInstalledVersion(const QStringList& candidateNames) const
{
    const QString key = candidateNames.join(QLatin1Char('\x1f')).toLower();
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    const auto at = m_installVersionCacheAt.constFind(key);
    if (at != m_installVersionCacheAt.constEnd() && (now - at.value()) < 60000) {
        return m_installVersionCache.value(key);
    }

    QString version;
#if defined(Q_OS_MACOS)
    version = macInstalledVersion(candidateNames);
#elif defined(Q_OS_WIN)
    version = windowsInstalledVersion(candidateNames);
#else
    version = linuxInstalledVersion(candidateNames);
#endif

    m_installVersionCache.insert(key, version);
    m_installVersionCacheAt.insert(key, now);
    return version;
}

void GitHubReleaseTrackerService::detectInstallState(genydl::releasecenter::TrackedGitHubApp& app) const
{
    // 1) Which of the latest release's assets are already downloaded & complete.
    app.downloadedAssets.clear();
    for (const QVariant& assetVariant : app.latestAssets) {
        const QVariantMap asset = assetVariant.toMap();
        const QString name = asset.value(QStringLiteral("name")).toString();
        const qint64 size = asset.value(QStringLiteral("size")).toLongLong();
        if (!completedDownloadPath(m_downloadRoots, name, size).isEmpty()) {
            app.downloadedAssets.append(name);
        }
    }

    const QString latest = app.latestTag;
    const bool latestDownloaded = !app.downloadedAssets.isEmpty();

    // OS-level installed version (strongest signal for "what is installed"),
    // cached + platform-dispatched (macOS bundle scan / Windows registry / Linux PATH).
    const QString osVersion = osInstalledVersion(QStringList{app.displayName, app.repo});
    const bool osHasLatest = !osVersion.isEmpty() && !latest.isEmpty()
        && genydl::utils::compareVersions(osVersion, latest) >= 0;

    // 1) The latest release's assets are downloaded and the installed copy (if any)
    //    is NOT already at that version. This is the App-Store "downloaded, ready to
    //    install/update" state: the user fetched the newest release through GenyDL,
    //    so that is the most useful thing to surface — it takes precedence over an
    //    older installed build that would otherwise read "update available".
    if (latestDownloaded && !osHasLatest) {
        app.installedVersion.clear();
        app.installSource = QStringLiteral("download");
        app.status = QStringLiteral("downloaded");
        return;
    }

    // 2) OS-level installed version.
    if (!osVersion.isEmpty()) {
        app.installedVersion = osVersion;
        app.installSource = QStringLiteral("os");
        app.status = (!latest.isEmpty() && genydl::utils::compareVersions(osVersion, latest) < 0)
            ? QStringLiteral("update_available")
            : QStringLiteral("up_to_date");
        return;
    }

    // 3) A version the user manually marked as installed.
    if (!app.knownTag.isEmpty()) {
        app.installedVersion = app.knownTag;
        app.installSource = QStringLiteral("manual");
        app.status = (!latest.isEmpty() && genydl::utils::compareVersions(app.knownTag, latest) < 0)
            ? QStringLiteral("update_available")
            : QStringLiteral("up_to_date");
        return;
    }

    // 4) Nothing found.
    app.installedVersion.clear();
    app.installSource.clear();
    app.status = QStringLiteral("not_installed");
}

void GitHubReleaseTrackerService::setDownloadRoots(const QStringList& roots)
{
    QStringList cleaned;
    for (const QString& root : roots) {
        const QString trimmed = root.trimmed();
        if (!trimmed.isEmpty() && !cleaned.contains(trimmed)) {
            cleaned.append(trimmed);
        }
    }
    if (cleaned == m_downloadRoots) return;
    m_downloadRoots = cleaned;
    refreshInstallStates();
}

void GitHubReleaseTrackerService::refreshInstallStates()
{
    if (m_apps.isEmpty()) return;
    bool changed = false;
    for (auto& app : m_apps) {
        const QString before = app.status;
        const QString beforeVersion = app.installedVersion;
        detectInstallState(app);
        if (app.status != before || app.installedVersion != beforeVersion) {
            changed = true;
        }
    }
    if (changed) {
        save();
        emit appsChanged();
    }
}

bool GitHubReleaseTrackerService::isAssetDownloaded(const QString& assetName, qint64 size) const
{
    return !completedDownloadPath(m_downloadRoots, assetName, size).isEmpty();
}

QString GitHubReleaseTrackerService::downloadedAssetPath(const QString& assetName, qint64 size) const
{
    return completedDownloadPath(m_downloadRoots, assetName, size);
}

void GitHubReleaseTrackerService::runNextPendingCheck()
{
    if (m_activeReply || m_pendingChecks.isEmpty()) {
        if (!m_activeReply) setLoading(false);
        return;
    }

    const int index = m_pendingChecks.takeFirst();
    if (index >= 0 && index < m_apps.size()) {
        checkApp(index);
    } else {
        runNextPendingCheck();
    }
}

QNetworkRequest GitHubReleaseTrackerService::makeRequest(const QUrl& url) const
{
    QNetworkRequest request(url);
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    request.setAttribute(QNetworkRequest::Http2AllowedAttribute, false);
    request.setTransferTimeout(kRequestTimeoutMs);
    request.setRawHeader("User-Agent", userAgent().toUtf8());
    request.setRawHeader("Accept", "application/vnd.github+json");
    request.setRawHeader("X-GitHub-Api-Version", "2022-11-28");
    if (!m_githubToken.isEmpty()) {
        request.setRawHeader("Authorization", QByteArray("Bearer ") + m_githubToken.toUtf8());
    }
    return request;
}

QString GitHubReleaseTrackerService::storagePath() const
{
    QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    if (dir.isEmpty()) {
        dir = QDir::home().filePath(QStringLiteral(".genydl"));
    }
    return QDir(dir).filePath(QStringLiteral("release-center.json"));
}

QString GitHubReleaseTrackerService::fallbackDisplayName(const genydl::github::RepositoryRequest& repo,
                                                         const genydl::github::ReleaseInfo& release) const
{
    if (!release.name.trimmed().isEmpty()) {
        return repo.repo;
    }
    return repo.repo;
}
