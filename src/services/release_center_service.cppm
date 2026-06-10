/*!
 * @file        release_center_service.cppm
 * @brief       Persistent GitHub Release Center tracker service.
 * @details     Tracks GitHub repositories that publish releases, checks for
 *              newer releases asynchronously, persists state, and exposes a
 *              QML-friendly model for the Release Center page.
 *
 * @author      <a href='https://github.com/thecompez'>Kambiz Asadzadeh</a>
 * @since       06 Jun 2026
 * @copyright   Copyright (c) 2026 Genyleap. All rights reserved.
 * @license     https://github.com/genyleap/genydl/blob/main/LICENSE.md
 */

module;
#include <QObject>
#include <QDateTime>
#include <QHash>
#include <QNetworkAccessManager>
#include <QNetworkInformation>
#include <QNetworkReply>
#include <QPointer>
#include <QTimer>
#include <QUrl>
#include <QVariantList>
#include <QVariantMap>
#include <QVector>

#ifndef Q_MOC_RUN
export module genydl.services.release_center_service;
import genydl.services.github_release_service;
import genydl.utils.version_utils;
#endif

#ifdef Q_MOC_RUN
#define GENYDL_MODULE_EXPORT
#else
#define GENYDL_MODULE_EXPORT export
#endif

GENYDL_MODULE_EXPORT namespace genydl::releasecenter {

struct TrackedGitHubApp {
    QString displayName;
    QString owner;
    QString repo;
    QString originalUrl;
    QString description;
    QUrl avatarUrl;
    QUrl htmlUrl;
    QUrl homepageUrl;
    QString language;
    QString licenseName;
    QString licenseSpdxId;
    int stars = 0;
    int forks = 0;
    int watchers = 0;
    QString knownTag;
    qint64 knownReleaseId = 0;
    QDateTime knownPublishedAt;
    // Discovered install state. installedVersion is the version GenyDL believes
    // is present on this machine; installSource records how it was detected
    // ("os", "download", "manual") or is empty when nothing was found.
    QString installedVersion;
    QString installSource;
    QStringList downloadedAssets;
    QString latestTag;
    qint64 latestReleaseId = 0;
    QDateTime latestPublishedAt;
    QString latestReleaseName;
    QString latestBody;
    QUrl latestHtmlUrl;
    QVariantList latestAssets;
    QVariantList latestSourceAssets;   // synthetic source-archive entries (tar.gz/zip)
    QDateTime lastCheckedAt;
    QString status = QStringLiteral("never_checked");
    QString errorMessage;
    bool notificationsEnabled = true;
    bool includePrereleases = false;
    bool autoCheckEnabled = true;
    QStringList assetFilters;

    [[nodiscard]] QString repositoryName() const;
    [[nodiscard]] QVariantMap toVariantMap() const;
};

[[nodiscard]] TrackedGitHubApp appFromVariantMap(const QVariantMap& map);
[[nodiscard]] QVariantMap appToVariantMap(const TrackedGitHubApp& app);
[[nodiscard]] QVariantList appsToVariantList(const QVector<TrackedGitHubApp>& apps);
[[nodiscard]] QByteArray saveDocumentForApps(const QVector<TrackedGitHubApp>& apps,
                                             const QVariantMap& settings);
[[nodiscard]] bool loadDocumentIntoApps(const QByteArray& data,
                                        QVector<TrackedGitHubApp>* apps,
                                        QVariantMap* settingsOut,
                                        QString* errorMessage = nullptr);
[[nodiscard]] bool releaseIsNewerThanKnown(const genydl::github::ReleaseInfo& release,
                                           const TrackedGitHubApp& app);

} // namespace genydl::releasecenter

GENYDL_MODULE_EXPORT class GitHubReleaseTrackerService : public QObject {
    Q_OBJECT

    Q_PROPERTY(QVariantList apps READ apps NOTIFY appsChanged)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY errorMessageChanged)
    Q_PROPERTY(QString rateLimitWarning READ rateLimitWarning NOTIFY rateLimitWarningChanged)
    Q_PROPERTY(QVariantMap preview READ preview NOTIFY previewChanged)
    Q_PROPERTY(QVariantList previewAssets READ previewAssets NOTIFY previewAssetsChanged)
    Q_PROPERTY(bool automaticChecksEnabled READ automaticChecksEnabled WRITE setAutomaticChecksEnabled NOTIFY settingsChanged)
    Q_PROPERTY(int checkIntervalHours READ checkIntervalHours WRITE setCheckIntervalHours NOTIFY settingsChanged)
    Q_PROPERTY(bool showNotifications READ showNotifications WRITE setShowNotifications NOTIFY settingsChanged)
    Q_PROPERTY(bool defaultIncludePrereleases READ defaultIncludePrereleases WRITE setDefaultIncludePrereleases NOTIFY settingsChanged)
    Q_PROPERTY(QString userAgent READ userAgent WRITE setUserAgent NOTIFY settingsChanged)
    Q_PROPERTY(QString githubToken READ githubToken WRITE setGithubToken NOTIFY settingsChanged)
    // Release-date display format: "relative" | "datetime" | "day" | "month".
    Q_PROPERTY(QString dateFormat READ dateFormat WRITE setDateFormat NOTIFY settingsChanged)
    // What happens when an update is found: "notify" | "ask" | "auto".
    Q_PROPERTY(QString downloadPolicy READ downloadPolicy WRITE setDownloadPolicy NOTIFY settingsChanged)
    // Only run automatic checks while the window is open (no background tray polling).
    Q_PROPERTY(bool onlyWhenOpen READ onlyWhenOpen WRITE setOnlyWhenOpen NOTIFY settingsChanged)
    // Allow checks to run while minimized to tray (requires onlyWhenOpen == false).
    Q_PROPERTY(bool backgroundChecks READ backgroundChecks WRITE setBackgroundChecks NOTIFY settingsChanged)
    // Skip automatic checks on metered connections where the platform reports it.
    Q_PROPERTY(bool wifiOnly READ wifiOnly WRITE setWifiOnly NOTIFY settingsChanged)
    // Whether the main window is currently visible/active. Bound from QML so the
    // scheduler can honor "only when open" / "background checks".
    Q_PROPERTY(bool windowActive READ windowActive WRITE setWindowActive NOTIFY windowActiveChanged)

public:
    explicit GitHubReleaseTrackerService(QObject* parent = nullptr);

    [[nodiscard]] QVariantList apps() const;
    [[nodiscard]] bool loading() const;
    [[nodiscard]] QString errorMessage() const;
    [[nodiscard]] QString rateLimitWarning() const;
    [[nodiscard]] QVariantMap preview() const;
    [[nodiscard]] QVariantList previewAssets() const;
    [[nodiscard]] bool automaticChecksEnabled() const;
    [[nodiscard]] int checkIntervalHours() const;
    [[nodiscard]] bool showNotifications() const;
    [[nodiscard]] bool defaultIncludePrereleases() const;
    [[nodiscard]] QString userAgent() const;
    [[nodiscard]] QString githubToken() const;
    [[nodiscard]] QString dateFormat() const;
    [[nodiscard]] QString downloadPolicy() const;
    [[nodiscard]] bool onlyWhenOpen() const;
    [[nodiscard]] bool backgroundChecks() const;
    [[nodiscard]] bool wifiOnly() const;
    [[nodiscard]] bool windowActive() const;

    void setAutomaticChecksEnabled(bool enabled);
    void setCheckIntervalHours(int hours);
    void setShowNotifications(bool enabled);
    void setDefaultIncludePrereleases(bool enabled);
    void setUserAgent(const QString& value);
    void setGithubToken(const QString& value);
    void setDateFormat(const QString& value);
    void setDownloadPolicy(const QString& value);
    void setOnlyWhenOpen(bool value);
    void setBackgroundChecks(bool value);
    void setWifiOnly(bool value);
    void setWindowActive(bool value);

    Q_INVOKABLE bool isSupportedUrl(const QString& value) const;
    Q_INVOKABLE QString normalizedRepository(const QString& value) const;
    Q_INVOKABLE void previewApp(const QString& value);
    Q_INVOKABLE bool confirmPreview(const QString& displayName);
    Q_INVOKABLE void clearPreview();
    Q_INVOKABLE void removeApp(int index);
    Q_INVOKABLE void checkApp(int index);
    Q_INVOKABLE void checkAll();
    Q_INVOKABLE void setAppAutoCheckEnabled(int index, bool enabled);
    Q_INVOKABLE void setAppIncludePrereleases(int index, bool enabled);
    Q_INVOKABLE void setAppNotificationsEnabled(int index, bool enabled);
    Q_INVOKABLE void markLatestKnown(int index);
    Q_INVOKABLE void reload();

    // App-Store style install detection. Roots are the folders GenyDL scans for
    // completed downloads (set once from main). refreshInstallStates re-runs the
    // download/OS scan for every tracked app. isAssetDownloaded lets the asset
    // picker disable assets that are already on disk.
    Q_INVOKABLE void setDownloadRoots(const QStringList& roots);
    Q_INVOKABLE void refreshInstallStates();
    Q_INVOKABLE bool isAssetDownloaded(const QString& assetName, qint64 size) const;
    Q_INVOKABLE QString downloadedAssetPath(const QString& assetName, qint64 size) const;
    // Best asset(s) matching the current OS/arch for a one-click update; empty
    // when nothing matches confidently (caller opens the full asset picker).
    Q_INVOKABLE QVariantList platformAssetsForApp(int index) const;

signals:
    void appsChanged();
    void loadingChanged();
    void errorMessageChanged();
    void rateLimitWarningChanged();
    void previewChanged();
    void previewAssetsChanged();
    void settingsChanged();
    void windowActiveChanged();
    void appUpdateFound(const QString& displayName, const QString& tagName, int index);
    void appCheckFinished(int index);
    // Emitted when an update is auto-downloaded or the user should be asked to
    // download it, per downloadPolicy. assets is the chosen asset variant list.
    void appAutoDownloadRequested(int index, const QVariantList& assets, bool autoStart);

private:
    enum class RequestMode {
        None,
        RepositoryPreview,
        Preview,
        Check
    };

    void load();
    void save();
    void startAutoTimer();
    // Called by the auto timer; honors only-when-open / background / wifi-only
    // gates before kicking off checkAll().
    void runScheduledCheck();
    [[nodiscard]] bool meteredConnection() const;
    void setLoading(bool value);
    void setErrorMessage(const QString& value);
    void setRateLimitWarning(const QString& value);
    void setPreviewRelease(const genydl::github::RepositoryRequest& repo,
                           const genydl::github::ReleaseInfo& release);
    void startRequest(const QUrl& url,
                      RequestMode mode,
                      int appIndex,
                      const genydl::github::RepositoryRequest& repo,
                      bool includePrereleases,
                      int attempt = 0);
    void handleReply(QNetworkReply* reply,
                     RequestMode mode,
                     int appIndex,
                     genydl::github::RepositoryRequest repo,
                     bool includePrereleases,
                     int attempt);
    void applyCheckResult(int appIndex, const genydl::github::ReleaseInfo& release);
    void detectInstallState(genydl::releasecenter::TrackedGitHubApp& app) const;
    // Cached, platform-dispatched installed-version lookup (avoids re-spawning the
    // synchronous OS scan on every refresh; TTL ~60s).
    [[nodiscard]] QString osInstalledVersion(const QStringList& candidateNames) const;
    void runNextPendingCheck();
    [[nodiscard]] QNetworkRequest makeRequest(const QUrl& url) const;
    [[nodiscard]] QString storagePath() const;
    [[nodiscard]] QString fallbackDisplayName(const genydl::github::RepositoryRequest& repo,
                                              const genydl::github::ReleaseInfo& release) const;

    QNetworkAccessManager m_network;
    QPointer<QNetworkReply> m_activeReply;
    QTimer m_autoTimer;
    QVector<genydl::releasecenter::TrackedGitHubApp> m_apps;
    QList<int> m_pendingChecks;
    bool m_loading = false;
    QString m_errorMessage;
    QString m_rateLimitWarning;
    QVariantMap m_preview;
    QVariantList m_previewAssets;
    genydl::github::RepositoryRequest m_previewRepo;
    // Conservative defaults: automatic checks OFF, low frequency, notify-only.
    bool m_automaticChecksEnabled = false;
    int m_checkIntervalHours = 24;
    bool m_showNotifications = true;
    bool m_defaultIncludePrereleases = false;
    QString m_userAgent;
    QString m_githubToken;
    QString m_dateFormat = QStringLiteral("datetime");
    QString m_downloadPolicy = QStringLiteral("notify");
    bool m_onlyWhenOpen = true;
    bool m_backgroundChecks = false;
    bool m_wifiOnly = false;
    bool m_windowActive = true;
    QStringList m_downloadRoots;
    mutable QHash<QString, QString> m_installVersionCache;
    mutable QHash<QString, qint64> m_installVersionCacheAt;
};

#include "release_center_service.moc"
