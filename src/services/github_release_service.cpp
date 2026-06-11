module;
#include <QCoreApplication>
#include <QCollator>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QStringList>
#include <algorithm>

module genydl.services.github_release_service;

namespace {

constexpr int kRequestTimeoutMs = 30000;

QString jsonString(const QJsonObject& object, const QString& key)
{
    const QJsonValue value = object.value(key);
    return value.isString() ? value.toString() : QString();
}

qint64 jsonInteger64(const QJsonObject& object, const QString& key)
{
    const QJsonValue value = object.value(key);
    if (value.isDouble()) {
        return static_cast<qint64>(value.toDouble());
    }
    if (value.isString()) {
        bool ok = false;
        const qint64 parsed = value.toString().toLongLong(&ok);
        return ok ? parsed : 0;
    }
    return 0;
}

QDateTime jsonDateTime(const QJsonObject& object, const QString& key)
{
    const QString value = jsonString(object, key);
    if (value.isEmpty()) {
        return {};
    }
    return QDateTime::fromString(value, Qt::ISODate);
}

QString apiErrorMessageFromBody(const QByteArray& responseBody)
{
    const QJsonDocument doc = QJsonDocument::fromJson(responseBody);
    if (!doc.isObject()) {
        return {};
    }

    const QString message = doc.object().value(QStringLiteral("message")).toString().trimmed();
    return message;
}

} // namespace

namespace genydl::github {

bool RepositoryRequest::isValid() const
{
    return !owner.isEmpty() && !repo.isEmpty();
}

QString RepositoryRequest::repositoryName() const
{
    return owner + QLatin1Char('/') + repo;
}

bool RepositoryInfo::isValid() const
{
    return !owner.isEmpty() && !repo.isEmpty();
}

QString RepositoryInfo::repositoryName() const
{
    return owner + QLatin1Char('/') + repo;
}

QVariantMap RepositoryInfo::toVariantMap() const
{
    return {
        {QStringLiteral("owner"), owner},
        {QStringLiteral("repo"), repo},
        {QStringLiteral("repository"), repositoryName()},
        {QStringLiteral("fullName"), fullName.isEmpty() ? repositoryName() : fullName},
        {QStringLiteral("description"), description},
        {QStringLiteral("avatarUrl"), avatarUrl.toString()},
        {QStringLiteral("htmlUrl"), htmlUrl.toString()},
        {QStringLiteral("homepageUrl"), homepageUrl.toString()},
        {QStringLiteral("language"), language},
        {QStringLiteral("licenseName"), licenseName},
        {QStringLiteral("licenseSpdxId"), licenseSpdxId},
        {QStringLiteral("stars"), stars},
        {QStringLiteral("forks"), forks},
        {QStringLiteral("watchers"), watchers}
    };
}

bool ReleaseRequest::isValid() const
{
    return !owner.isEmpty() && !repo.isEmpty()
           && (kind == ReleaseRequestKind::Latest || !tag.isEmpty());
}

QString ReleaseRequest::repositoryName() const
{
    return owner + QLatin1Char('/') + repo;
}

QVariantMap ReleaseAsset::toVariantMap() const
{
    return {
        {QStringLiteral("name"), name},
        {QStringLiteral("size"), size},
        {QStringLiteral("sizeText"), humanSize(size)},
        {QStringLiteral("downloadUrl"), downloadUrl.toString()},
        {QStringLiteral("contentType"), contentType},
        {QStringLiteral("downloadCount"), downloadCount},
        {QStringLiteral("createdAt"), createdAt},
        {QStringLiteral("updatedAt"), updatedAt},
        {QStringLiteral("digest"), digest}
    };
}

QString ReleaseInfo::repositoryName() const
{
    return owner + QLatin1Char('/') + repo;
}

QVariantMap ReleaseInfo::toVariantMap() const
{
    return {
        {QStringLiteral("id"), id},
        {QStringLiteral("owner"), owner},
        {QStringLiteral("repo"), repo},
        {QStringLiteral("repository"), repositoryName()},
        {QStringLiteral("name"), name},
        {QStringLiteral("tagName"), tagName},
        {QStringLiteral("body"), body},
        {QStringLiteral("htmlUrl"), htmlUrl.toString()},
        {QStringLiteral("publishedAt"), publishedAt},
        {QStringLiteral("publishedText"), publishedAt.isValid()
             ? publishedAt.toLocalTime().toString(QStringLiteral("yyyy-MM-dd HH:mm"))
             : QString()},
        {QStringLiteral("prerelease"), prerelease},
        {QStringLiteral("draft"), draft}
    };
}

QVariantList ReleaseInfo::assetsToVariantList() const
{
    QVariantList list;
    list.reserve(assets.size());
    for (const ReleaseAsset& asset : assets) {
        list.append(asset.toVariantMap());
    }
    return list;
}

QVariantList ReleaseInfo::sourceAssetsToVariantList() const
{
    QVariantList list;
    const QString stem = (repo.isEmpty() ? QStringLiteral("source") : repo)
        + (tagName.isEmpty() ? QString() : (QLatin1Char('-') + tagName));

    auto makeSource = [&](const QUrl& url, const QString& suffix, const QString& contentType) {
        if (!url.isValid() || url.isEmpty()) return;
        QVariantMap map;
        map.insert(QStringLiteral("name"), stem + suffix);
        map.insert(QStringLiteral("size"), 0);              // unknown; GitHub omits it
        map.insert(QStringLiteral("downloadUrl"), url.toString());
        map.insert(QStringLiteral("contentType"), contentType);
        map.insert(QStringLiteral("downloadCount"), 0);
        map.insert(QStringLiteral("isSource"), true);       // flag for the UI
        list.append(map);
    };

    makeSource(zipballUrl, QStringLiteral("-source.zip"), QStringLiteral("application/zip"));
    makeSource(tarballUrl, QStringLiteral("-source.tar.gz"), QStringLiteral("application/gzip"));
    return list;
}

std::optional<ReleaseRequest> parseReleaseUrl(const QString& value)
{
    const QUrl url(value.trimmed());
    if (!url.isValid()) {
        return std::nullopt;
    }

    const QString scheme = url.scheme().toLower();
    const QString host = url.host().toLower();
    if (scheme != QStringLiteral("https") || host != QStringLiteral("github.com")) {
        return std::nullopt;
    }

    const QString path = url.path();
    const QStringList segments = path.split(QLatin1Char('/'), Qt::SkipEmptyParts);
    if (segments.size() < 4) {
        return std::nullopt;
    }

    if (segments.at(2) != QStringLiteral("releases")) {
        return std::nullopt;
    }

    ReleaseRequest request;
    request.owner = QUrl::fromPercentEncoding(segments.at(0).toUtf8());
    request.repo = QUrl::fromPercentEncoding(segments.at(1).toUtf8());

    if (segments.size() == 4 && segments.at(3) == QStringLiteral("latest")) {
        request.kind = ReleaseRequestKind::Latest;
        return request.isValid() ? std::optional<ReleaseRequest>(request) : std::nullopt;
    }

    if (segments.size() >= 5 && segments.at(3) == QStringLiteral("tag")) {
        request.kind = ReleaseRequestKind::Tag;
        const QString encodedTag = segments.mid(4).join(QLatin1Char('/'));
        request.tag = QUrl::fromPercentEncoding(encodedTag.toUtf8());
        return request.isValid() ? std::optional<ReleaseRequest>(request) : std::nullopt;
    }

    return std::nullopt;
}

std::optional<RepositoryRequest> parseRepositoryUrl(const QString& value)
{
    const QUrl url(value.trimmed());
    if (!url.isValid()) {
        return std::nullopt;
    }

    const QString scheme = url.scheme().toLower();
    const QString host = url.host().toLower();
    if (scheme != QStringLiteral("https") || host != QStringLiteral("github.com")) {
        return std::nullopt;
    }

    const QStringList segments = url.path().split(QLatin1Char('/'), Qt::SkipEmptyParts);
    if (segments.size() < 2) {
        return std::nullopt;
    }
    if (segments.size() > 4) {
        return std::nullopt;
    }
    if (segments.size() >= 3 && segments.at(2) != QStringLiteral("releases")) {
        return std::nullopt;
    }
    if (segments.size() == 4 && segments.at(3) != QStringLiteral("latest")) {
        return std::nullopt;
    }

    RepositoryRequest request;
    request.owner = QUrl::fromPercentEncoding(segments.at(0).toUtf8());
    request.repo = QUrl::fromPercentEncoding(segments.at(1).toUtf8());
    request.originalUrl = value.trimmed();
    return request.isValid() ? std::optional<RepositoryRequest>(request) : std::nullopt;
}

QUrl apiUrlForRequest(const ReleaseRequest& request)
{
    if (!request.isValid()) {
        return {};
    }

    const QString base = QStringLiteral("https://api.github.com/repos/%1/%2/releases/")
                             .arg(QString::fromUtf8(QUrl::toPercentEncoding(request.owner, QByteArray(), "/")),
                                  QString::fromUtf8(QUrl::toPercentEncoding(request.repo, QByteArray(), "/")));
    if (request.kind == ReleaseRequestKind::Latest) {
        return QUrl(base + QStringLiteral("latest"));
    }

    return QUrl(base + QStringLiteral("tags/")
                + QString::fromUtf8(QUrl::toPercentEncoding(request.tag, QByteArray(), "/")));
}

QUrl repositoryApiUrlForRepository(const RepositoryRequest& request)
{
    if (!request.isValid()) {
        return {};
    }
    return QUrl(QStringLiteral("https://api.github.com/repos/%1/%2")
                    .arg(QString::fromUtf8(QUrl::toPercentEncoding(request.owner, QByteArray(), "/")),
                         QString::fromUtf8(QUrl::toPercentEncoding(request.repo, QByteArray(), "/"))));
}

QUrl latestReleaseApiUrlForRepository(const RepositoryRequest& request)
{
    if (!request.isValid()) {
        return {};
    }
    const QString base = QStringLiteral("https://api.github.com/repos/%1/%2/releases/latest")
                             .arg(QString::fromUtf8(QUrl::toPercentEncoding(request.owner, QByteArray(), "/")),
                                  QString::fromUtf8(QUrl::toPercentEncoding(request.repo, QByteArray(), "/")));
    return QUrl(base);
}

QUrl releasesApiUrlForRepository(const RepositoryRequest& request)
{
    if (!request.isValid()) {
        return {};
    }
    const QString base = QStringLiteral("https://api.github.com/repos/%1/%2/releases")
                             .arg(QString::fromUtf8(QUrl::toPercentEncoding(request.owner, QByteArray(), "/")),
                                  QString::fromUtf8(QUrl::toPercentEncoding(request.repo, QByteArray(), "/")));
    return QUrl(base);
}

QString humanSize(qint64 bytes)
{
    if (bytes < 0) {
        bytes = 0;
    }

    static const QStringList units{
        QStringLiteral("B"),
        QStringLiteral("KB"),
        QStringLiteral("MB"),
        QStringLiteral("GB"),
        QStringLiteral("TB")
    };

    double value = static_cast<double>(bytes);
    int unitIndex = 0;
    while (value >= 1024.0 && unitIndex < units.size() - 1) {
        value /= 1024.0;
        ++unitIndex;
    }

    if (unitIndex == 0) {
        return QStringLiteral("%1 B").arg(bytes);
    }
    return QStringLiteral("%1 %2").arg(value, 0, 'f', value >= 10.0 ? 1 : 2).arg(units.at(unitIndex));
}

QString userFriendlyApiError(int statusCode, const QByteArray& responseBody, bool rateLimitExhausted)
{
    if (rateLimitExhausted) {
        return QStringLiteral("GitHub API rate limit reached. Try again later or configure a GitHub token when token support is enabled.");
    }

    switch (statusCode) {
    case 401:
        return QStringLiteral("GitHub refused the request. This release may require authentication.");
    case 403:
        return QStringLiteral("GitHub refused the request. This can happen for private repositories or API rate limits.");
    case 404:
        return QStringLiteral("GitHub repository or release was not found.");
    case 422:
        return QStringLiteral("GitHub could not resolve that release tag.");
    default:
        break;
    }

    const QString message = apiErrorMessageFromBody(responseBody);
    if (!message.isEmpty()) {
        return QStringLiteral("GitHub API error: %1").arg(message);
    }

    if (statusCode > 0) {
        return QStringLiteral("GitHub API request failed with HTTP %1.").arg(statusCode);
    }
    return QStringLiteral("GitHub release request failed.");
}

std::optional<ReleaseInfo> parseReleaseJson(const QByteArray& data, QString* errorMessage)
{
    QJsonParseError parseError;
    const QJsonDocument doc = QJsonDocument::fromJson(data, &parseError);
    if (parseError.error != QJsonParseError::NoError || !doc.isObject()) {
        if (errorMessage) {
            *errorMessage = QStringLiteral("GitHub returned malformed release data.");
        }
        return std::nullopt;
    }

    const QJsonObject object = doc.object();
    ReleaseInfo release;
    release.id = jsonInteger64(object, QStringLiteral("id"));
    release.name = jsonString(object, QStringLiteral("name"));
    release.tagName = jsonString(object, QStringLiteral("tag_name"));
    release.body = jsonString(object, QStringLiteral("body"));
    release.htmlUrl = QUrl(jsonString(object, QStringLiteral("html_url")));
    release.publishedAt = jsonDateTime(object, QStringLiteral("published_at"));
    release.prerelease = object.value(QStringLiteral("prerelease")).toBool(false);
    release.draft = object.value(QStringLiteral("draft")).toBool(false);
    release.tarballUrl = QUrl(jsonString(object, QStringLiteral("tarball_url")));
    release.zipballUrl = QUrl(jsonString(object, QStringLiteral("zipball_url")));

    const QJsonObject repoObject = object.value(QStringLiteral("repository")).toObject();
    release.owner = repoObject.value(QStringLiteral("owner")).toObject().value(QStringLiteral("login")).toString();
    release.repo = repoObject.value(QStringLiteral("name")).toString();

    const QJsonArray assets = object.value(QStringLiteral("assets")).toArray();
    release.assets.reserve(assets.size());
    for (const QJsonValue& item : assets) {
        if (!item.isObject()) {
            continue;
        }

        const QJsonObject assetObject = item.toObject();
        ReleaseAsset asset;
        asset.name = jsonString(assetObject, QStringLiteral("name"));
        asset.size = jsonInteger64(assetObject, QStringLiteral("size"));
        asset.downloadUrl = QUrl(jsonString(assetObject, QStringLiteral("browser_download_url")));
        asset.contentType = jsonString(assetObject, QStringLiteral("content_type"));
        asset.downloadCount = static_cast<int>(jsonInteger64(assetObject, QStringLiteral("download_count")));
        asset.createdAt = jsonDateTime(assetObject, QStringLiteral("created_at"));
        asset.updatedAt = jsonDateTime(assetObject, QStringLiteral("updated_at"));
        asset.digest = jsonString(assetObject, QStringLiteral("digest"));

        if (!asset.name.isEmpty() && asset.downloadUrl.isValid()) {
            release.assets.push_back(asset);
        }
    }

    QCollator collator;
    collator.setNumericMode(true);
    collator.setCaseSensitivity(Qt::CaseInsensitive);
    std::sort(release.assets.begin(), release.assets.end(), [&collator](const ReleaseAsset& lhs, const ReleaseAsset& rhs) {
        return collator.compare(lhs.name, rhs.name) < 0;
    });

    return release;
}

std::optional<RepositoryInfo> parseRepositoryJson(const QByteArray& data, QString* errorMessage)
{
    QJsonParseError parseError;
    const QJsonDocument doc = QJsonDocument::fromJson(data, &parseError);
    if (parseError.error != QJsonParseError::NoError || !doc.isObject()) {
        if (errorMessage) {
            *errorMessage = QStringLiteral("GitHub returned malformed repository data.");
        }
        return std::nullopt;
    }

    const QJsonObject object = doc.object();
    RepositoryInfo info;
    info.owner = object.value(QStringLiteral("owner")).toObject().value(QStringLiteral("login")).toString();
    info.repo = jsonString(object, QStringLiteral("name"));
    info.fullName = jsonString(object, QStringLiteral("full_name"));
    info.description = jsonString(object, QStringLiteral("description"));
    info.avatarUrl = QUrl(object.value(QStringLiteral("owner")).toObject().value(QStringLiteral("avatar_url")).toString());
    info.htmlUrl = QUrl(jsonString(object, QStringLiteral("html_url")));
    info.homepageUrl = QUrl(jsonString(object, QStringLiteral("homepage")));
    info.language = jsonString(object, QStringLiteral("language"));
    const QJsonObject license = object.value(QStringLiteral("license")).toObject();
    info.licenseName = license.value(QStringLiteral("name")).toString();
    info.licenseSpdxId = license.value(QStringLiteral("spdx_id")).toString();
    info.stars = static_cast<int>(jsonInteger64(object, QStringLiteral("stargazers_count")));
    info.forks = static_cast<int>(jsonInteger64(object, QStringLiteral("forks_count")));
    info.watchers = static_cast<int>(jsonInteger64(object, QStringLiteral("watchers_count")));

    if (!info.isValid()) {
        if (errorMessage) {
            *errorMessage = QStringLiteral("GitHub repository metadata is missing owner or repository name.");
        }
        return std::nullopt;
    }
    return info;
}

std::optional<ReleaseInfo> parseLatestReleaseFromListJson(const QByteArray& data,
                                                          bool includePrereleases,
                                                          QString* errorMessage)
{
    QJsonParseError parseError;
    const QJsonDocument doc = QJsonDocument::fromJson(data, &parseError);
    if (parseError.error != QJsonParseError::NoError || !doc.isArray()) {
        if (errorMessage) {
            *errorMessage = QStringLiteral("GitHub returned malformed release list data.");
        }
        return std::nullopt;
    }

    const QJsonArray releases = doc.array();
    std::optional<ReleaseInfo> latest;
    for (const QJsonValue& value : releases) {
        if (!value.isObject()) {
            continue;
        }

        const QJsonDocument releaseDoc(value.toObject());
        auto release = parseReleaseJson(releaseDoc.toJson(QJsonDocument::Compact), errorMessage);
        if (!release) {
            return std::nullopt;
        }
        if (release->draft) {
            continue;
        }
        if (release->prerelease && !includePrereleases) {
            continue;
        }
        if (!latest || isNewerRelease(*release, *latest)) {
            latest = *release;
        }
    }

    if (!latest && errorMessage) {
        *errorMessage = QStringLiteral("This repository does not publish matching releases.");
    }
    return latest;
}

bool isNewerRelease(const ReleaseInfo& candidate, const ReleaseInfo& known)
{
    if (candidate.publishedAt.isValid() && known.publishedAt.isValid()
        && candidate.publishedAt != known.publishedAt) {
        return candidate.publishedAt > known.publishedAt;
    }
    if (candidate.id > 0 && known.id > 0 && candidate.id != known.id) {
        return candidate.id > known.id;
    }
    if (known.tagName.isEmpty()) {
        return !candidate.tagName.isEmpty();
    }
    return false;
}

} // namespace genydl::github

GitHubReleaseService::GitHubReleaseService(QObject* parent)
    : QObject(parent)
{
}

bool GitHubReleaseService::loading() const
{
    return m_loading;
}

QString GitHubReleaseService::errorMessage() const
{
    return m_errorMessage;
}

QVariantMap GitHubReleaseService::release() const
{
    return m_release;
}

QVariantList GitHubReleaseService::assets() const
{
    return m_assets;
}

QString GitHubReleaseService::githubToken() const
{
    return m_githubToken;
}

void GitHubReleaseService::setGithubToken(const QString& token)
{
    const QString trimmed = token.trimmed();
    if (m_githubToken == trimmed) {
        return;
    }
    m_githubToken = trimmed;
    emit githubTokenChanged();
}

bool GitHubReleaseService::isReleaseUrl(const QString& value) const
{
    return genydl::github::parseReleaseUrl(value).has_value();
}

QString GitHubReleaseService::apiUrlFor(const QString& value) const
{
    const auto request = genydl::github::parseReleaseUrl(value);
    return request ? genydl::github::apiUrlForRequest(*request).toString() : QString();
}

void GitHubReleaseService::fetchRelease(const QString& value)
{
    const auto request = genydl::github::parseReleaseUrl(value);
    if (!request) {
        finishWithError(QStringLiteral("This is not a supported GitHub release URL."));
        return;
    }

    if (m_activeReply) {
        m_activeReply->abort();
        m_activeReply->deleteLater();
        m_activeReply.clear();
    }

    resetReleaseInfo();
    setErrorMessage(QString());
    setLoading(true);

    QNetworkRequest networkRequest(genydl::github::apiUrlForRequest(*request));
    networkRequest.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    networkRequest.setAttribute(QNetworkRequest::Http2AllowedAttribute, false);
    networkRequest.setTransferTimeout(kRequestTimeoutMs);
    networkRequest.setRawHeader("User-Agent", userAgent().toUtf8());
    networkRequest.setRawHeader("Accept", "application/vnd.github+json");
    networkRequest.setRawHeader("X-GitHub-Api-Version", "2022-11-28");
    if (!m_githubToken.isEmpty()) {
        networkRequest.setRawHeader("Authorization", QByteArray("Bearer ") + m_githubToken.toUtf8());
    }

    QNetworkReply* reply = m_network.get(networkRequest);
    m_activeReply = reply;

    connect(reply, &QNetworkReply::finished, this, [this, reply, request]() {
        QPointer<QNetworkReply> replyGuard(reply);
        if (m_activeReply == reply) {
            m_activeReply.clear();
        }

        const int statusCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        // Guard against reading a transport-failed (closed) socket — that logs
        // "QSslSocket: device not open". HTTP error statuses keep it open.
        const QByteArray responseBody = reply->isOpen() ? reply->readAll() : QByteArray();
        const bool rateLimitExhausted = reply->rawHeader("X-RateLimit-Remaining") == QByteArray("0");
        const QNetworkReply::NetworkError networkError = reply->error();
        reply->deleteLater();

        if (networkError != QNetworkReply::NoError) {
            const QString message = statusCode >= 400
                ? genydl::github::userFriendlyApiError(statusCode, responseBody, rateLimitExhausted)
                : networkErrorMessage(networkError, replyGuard ? replyGuard->errorString() : QStringLiteral("request failed"));
            finishWithError(message);
            return;
        }

        if (statusCode >= 400) {
            finishWithError(genydl::github::userFriendlyApiError(statusCode, responseBody, rateLimitExhausted));
            return;
        }

        QString parseError;
        auto release = genydl::github::parseReleaseJson(responseBody, &parseError);
        if (!release) {
            finishWithError(parseError.isEmpty() ? QStringLiteral("GitHub returned malformed release data.") : parseError);
            return;
        }

        if (release->owner.isEmpty()) {
            release->owner = request->owner;
        }
        if (release->repo.isEmpty()) {
            release->repo = request->repo;
        }
        if (release->tagName.isEmpty()) {
            release->tagName = request->tag;
        }

        setReleaseInfo(*release);
        setLoading(false);
        emit releaseReady();
    });
}

void GitHubReleaseService::clear()
{
    if (m_activeReply) {
        m_activeReply->abort();
        m_activeReply->deleteLater();
        m_activeReply.clear();
    }
    setLoading(false);
    setErrorMessage(QString());
    resetReleaseInfo();
}

void GitHubReleaseService::setLoading(bool value)
{
    if (m_loading == value) {
        return;
    }
    m_loading = value;
    emit loadingChanged();
}

void GitHubReleaseService::setErrorMessage(const QString& value)
{
    if (m_errorMessage == value) {
        return;
    }
    m_errorMessage = value;
    emit errorMessageChanged();
}

void GitHubReleaseService::setReleaseInfo(const genydl::github::ReleaseInfo& info)
{
    const QVariantMap release = info.toVariantMap();
    const QVariantList assets = info.assetsToVariantList();

    if (m_release != release) {
        m_release = release;
        emit releaseChanged();
    }
    if (m_assets != assets) {
        m_assets = assets;
        emit assetsChanged();
    }
}

void GitHubReleaseService::resetReleaseInfo()
{
    if (!m_release.isEmpty()) {
        m_release.clear();
        emit releaseChanged();
    }
    if (!m_assets.isEmpty()) {
        m_assets.clear();
        emit assetsChanged();
    }
}

void GitHubReleaseService::finishWithError(const QString& message)
{
    setLoading(false);
    setErrorMessage(message);
    emit fetchFailed(message);
}

QString GitHubReleaseService::userAgent() const
{
    const QString version = QCoreApplication::applicationVersion().isEmpty()
        ? QStringLiteral("0.1.0")
        : QCoreApplication::applicationVersion();
    return QStringLiteral("GenyDL/%1").arg(version);
}

QString GitHubReleaseService::networkErrorMessage(QNetworkReply::NetworkError error, const QString& detail) const
{
    switch (error) {
    case QNetworkReply::TimeoutError:
        return QStringLiteral("GitHub release request timed out. Check the connection and try again.");
    case QNetworkReply::HostNotFoundError:
        return QStringLiteral("Could not reach GitHub. Check the network connection and try again.");
    case QNetworkReply::ConnectionRefusedError:
    case QNetworkReply::RemoteHostClosedError:
    case QNetworkReply::TemporaryNetworkFailureError:
    case QNetworkReply::NetworkSessionFailedError:
        return QStringLiteral("Network connection failed while contacting GitHub. Try again later.");
    default:
        break;
    }

    return QStringLiteral("Network error while contacting GitHub: %1").arg(detail);
}
