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
 * @license     https://github.com/genyleap/tondar/blob/main/LICENSE.md
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
export module tondar.services.github_release_service;
#endif

#ifdef Q_MOC_RUN
#define TONDAR_MODULE_EXPORT
#else
#define TONDAR_MODULE_EXPORT export
#endif

TONDAR_MODULE_EXPORT namespace tondar::github {

enum class ReleaseRequestKind {
    Tag,
    Latest
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

    [[nodiscard]] QVariantMap toVariantMap() const;
};

struct ReleaseInfo {
    QString owner;
    QString repo;
    QString name;
    QString tagName;
    QString body;
    QDateTime publishedAt;
    QVector<ReleaseAsset> assets;

    [[nodiscard]] QString repositoryName() const;
    [[nodiscard]] QVariantMap toVariantMap() const;
    [[nodiscard]] QVariantList assetsToVariantList() const;
};

[[nodiscard]] std::optional<ReleaseRequest> parseReleaseUrl(const QString& value);
[[nodiscard]] QUrl apiUrlForRequest(const ReleaseRequest& request);
[[nodiscard]] QString humanSize(qint64 bytes);
[[nodiscard]] QString userFriendlyApiError(int statusCode,
                                           const QByteArray& responseBody,
                                           bool rateLimitExhausted = false);
[[nodiscard]] std::optional<ReleaseInfo> parseReleaseJson(const QByteArray& data,
                                                          QString* errorMessage = nullptr);

} // namespace tondar::github

TONDAR_MODULE_EXPORT class GitHubReleaseService : public QObject {
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
    void setReleaseInfo(const tondar::github::ReleaseInfo& info);
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
