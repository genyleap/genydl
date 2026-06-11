/*!
 * @file        github_release_service.cppm
 * @brief       GitHub release URL parsing and asset discovery service.
 * @details     Provides a small, testable service for detecting GitHub release
 *              URLs, fetching release metadata from the GitHub REST API, and
 *              exposing release assets to QML.
 *
 * @author      <a href='https://github.com/thecompez'>Kambiz Asadzadeh</a>
 * @since       09 Feb 2026
 * @copyright   Copyright (c) 2026 Genyleap. All rights reserved.
 * @license     https://github.com/genyleap/genydl/blob/main/LICENSE.md
 */

module;
#include <QObject>
#include <QDateTime>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QPointer>
#include <QString>
#include <QUrl>
#include <QVariantList>
#include <QVariantMap>
#include <QVector>
#include <optional>

#ifndef Q_MOC_RUN
#  include <QtCore/qtmochelpers.h>
export module genydl.services.github_release_service;
#endif

#ifdef Q_MOC_RUN
#define GENYDL_MODULE_EXPORT
#else
#define GENYDL_MODULE_EXPORT export
#endif

GENYDL_MODULE_EXPORT namespace genydl::github {

enum class ReleaseRequestKind {
    Tag,
    Latest
};

struct RepositoryRequest {
    QString owner;
    QString repo;
    QString originalUrl;

    [[nodiscard]] bool isValid() const;
    [[nodiscard]] QString repositoryName() const;
};

struct RepositoryInfo {
    QString owner;
    QString repo;
    QString fullName;
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

    [[nodiscard]] bool isValid() const;
    [[nodiscard]] QString repositoryName() const;
    [[nodiscard]] QVariantMap toVariantMap() const;
};

struct ReleaseRequest {
    QString owner;
    QString repo;
    QString tag;
    ReleaseRequestKind kind = ReleaseRequestKind::Tag;

    [[nodiscard]] bool isValid() const;
    [[nodiscard]] QString repositoryName() const;
};

struct ReleaseAsset {
    QString name;
    qint64 size = 0;
    QUrl downloadUrl;
    QString contentType;
    int downloadCount = 0;
    QDateTime createdAt;
    QDateTime updatedAt;
    QString digest;   // GitHub integrity digest, e.g. "sha256:<hex>" (may be empty)

    [[nodiscard]] QVariantMap toVariantMap() const;
};

struct ReleaseInfo {
    qint64 id = 0;
    QString owner;
    QString repo;
    QString name;
    QString tagName;
    QString body;
    QUrl htmlUrl;
    QDateTime publishedAt;
    bool prerelease = false;
    bool draft = false;
    QVector<ReleaseAsset> assets;
    QUrl tarballUrl;   // GitHub auto-generated source archive (.tar.gz)
    QUrl zipballUrl;   // GitHub auto-generated source archive (.zip)

    [[nodiscard]] QString repositoryName() const;
    [[nodiscard]] QVariantMap toVariantMap() const;
    [[nodiscard]] QVariantList assetsToVariantList() const;
    // Synthetic "asset" entries for the source-code archives (tar.gz / zip).
    // Sizes are unknown (GitHub does not report them) and reported as 0.
    [[nodiscard]] QVariantList sourceAssetsToVariantList() const;
};

[[nodiscard]] std::optional<ReleaseRequest> parseReleaseUrl(const QString& value);
[[nodiscard]] std::optional<RepositoryRequest> parseRepositoryUrl(const QString& value);
[[nodiscard]] QUrl repositoryApiUrlForRepository(const RepositoryRequest& request);
[[nodiscard]] QUrl apiUrlForRequest(const ReleaseRequest& request);
[[nodiscard]] QUrl latestReleaseApiUrlForRepository(const RepositoryRequest& request);
[[nodiscard]] QUrl releasesApiUrlForRepository(const RepositoryRequest& request);
[[nodiscard]] QString humanSize(qint64 bytes);
[[nodiscard]] QString userFriendlyApiError(int statusCode,
                                           const QByteArray& responseBody,
                                           bool rateLimitExhausted = false);
[[nodiscard]] std::optional<ReleaseInfo> parseReleaseJson(const QByteArray& data,
                                                          QString* errorMessage = nullptr);
[[nodiscard]] std::optional<RepositoryInfo> parseRepositoryJson(const QByteArray& data,
                                                               QString* errorMessage = nullptr);
[[nodiscard]] std::optional<ReleaseInfo> parseLatestReleaseFromListJson(const QByteArray& data,
                                                                        bool includePrereleases,
                                                                        QString* errorMessage = nullptr);
[[nodiscard]] bool isNewerRelease(const ReleaseInfo& candidate, const ReleaseInfo& known);

} // namespace genydl::github

GENYDL_MODULE_EXPORT class GitHubReleaseService : public QObject {
    Q_OBJECT

    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY errorMessageChanged)
    Q_PROPERTY(QVariantMap release READ release NOTIFY releaseChanged)
    Q_PROPERTY(QVariantList assets READ assets NOTIFY assetsChanged)
    Q_PROPERTY(QString githubToken READ githubToken WRITE setGithubToken NOTIFY githubTokenChanged)

public:
    explicit GitHubReleaseService(QObject* parent = nullptr);

    [[nodiscard]] bool loading() const;
    [[nodiscard]] QString errorMessage() const;
    [[nodiscard]] QVariantMap release() const;
    [[nodiscard]] QVariantList assets() const;
    [[nodiscard]] QString githubToken() const;
    void setGithubToken(const QString& token);

    Q_INVOKABLE bool isReleaseUrl(const QString& value) const;
    Q_INVOKABLE QString apiUrlFor(const QString& value) const;
    Q_INVOKABLE void fetchRelease(const QString& value);
    Q_INVOKABLE void clear();

signals:
    void loadingChanged();
    void errorMessageChanged();
    void releaseChanged();
    void assetsChanged();
    void githubTokenChanged();
    void releaseReady();
    void fetchFailed(const QString& message);

private:
    void setLoading(bool value);
    void setErrorMessage(const QString& value);
    void setReleaseInfo(const genydl::github::ReleaseInfo& info);
    void resetReleaseInfo();
    void finishWithError(const QString& message);
    [[nodiscard]] QString userAgent() const;
    [[nodiscard]] QString networkErrorMessage(QNetworkReply::NetworkError error, const QString& detail) const;

    QNetworkAccessManager m_network;
    QPointer<QNetworkReply> m_activeReply;
    bool m_loading = false;
    QString m_errorMessage;
    QString m_githubToken;
    QVariantMap m_release;
    QVariantList m_assets;
};

#include "github_release_service.moc"
