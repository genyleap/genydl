#include <QtTest/QtTest>

import genydl.utils.version_utils;
import genydl.utils.download_utils;
import genydl.utils.category_utils;
import genydl.services.github_release_service;
import genydl.services.release_center_service;
import genydl.services.torrent_session;
import genydl.utils.ipfs_resolver;
import genydl.core.language_manager;

namespace utils = genydl::utils;
namespace github = genydl::github;
namespace releasecenter = genydl::releasecenter;
namespace ipfs = genydl::ipfs;

class BackendTests final : public QObject
{
    Q_OBJECT

private slots:
    void compareVersions_data();
    void compareVersions();
    void detectChecksumAlgo();
    void normalizeChecksum();
    void extractChecksumFromText();
    void normalizeHost();
    void detectCategory();
    void parseGitHubReleaseTagUrl();
    void parseGitHubReleaseLatestUrl();
    void rejectNonGitHubReleaseUrl();
    void parseGitHubReleaseJsonWithAssets();
    void parseGitHubReleaseJsonWithEmptyAssets();
    void mapGitHubApiErrors();
    void parseGitHubRepositoryUrlsForReleaseCenter();
    void rejectInvalidReleaseCenterUrls();
    void parseGitHubRepositoryMetadata();
    void detectNewerReleaseByPublishedDate();
    void filterPrereleasesFromReleaseList();
    void includePrereleasesFromReleaseList();
    void persistReleaseCenterApps();
    void exposeReleaseAssetsForPickerIntegration();
    void torrentSessionAvailabilityContract();
    void parseCidV0();
    void parseCidV1DagPb();
    void parseRawCidIsVerifiable();
    void rejectInvalidCid();
    void detectIpfsInputs();
    void parseIpfsReferenceWithSubPath();
    void buildIpfsGatewayUrl();
    void languageCatalogContract();
};

void BackendTests::compareVersions_data()
{
    QTest::addColumn<QString>("lhs");
    QTest::addColumn<QString>("rhs");
    QTest::addColumn<int>("expected");

    QTest::newRow("stable_gt_prerelease") << QStringLiteral("1.2.3") << QStringLiteral("1.2.3-beta.1") << 1;
    QTest::newRow("stable_lt_stable") << QStringLiteral("1.2.3") << QStringLiteral("1.2.4") << -1;
    QTest::newRow("same") << QStringLiteral("v2.0.0") << QStringLiteral("2.0.0") << 0;
}

void BackendTests::compareVersions()
{
    QFETCH(QString, lhs);
    QFETCH(QString, rhs);
    QFETCH(int, expected);
    QCOMPARE(utils::compareVersions(lhs, rhs), expected);
}

void BackendTests::detectChecksumAlgo()
{
    QCOMPARE(utils::detectChecksumAlgo(QStringLiteral("d41d8cd98f00b204e9800998ecf8427e")), QStringLiteral("MD5"));
    QCOMPARE(utils::detectChecksumAlgo(QStringLiteral("a9993e364706816aba3e25717850c26c9cd0d89d")), QStringLiteral("SHA1"));
    QCOMPARE(utils::detectChecksumAlgo(QStringLiteral("e3b0c44298fc1c149afbf4c8996fb924"
                                                      "27ae41e4649b934ca495991b7852b855")),
             QStringLiteral("SHA256"));
}

void BackendTests::normalizeChecksum()
{
    QCOMPARE(utils::normalizeChecksum(QStringLiteral("sha256:e3b0c44298fc1c149afbf4c8996fb924"
                                                     "27ae41e4649b934ca495991b7852b855")),
             QStringLiteral("e3b0c44298fc1c149afbf4c8996fb924"
                            "27ae41e4649b934ca495991b7852b855"));
    QCOMPARE(utils::normalizeChecksum(QStringLiteral("SHA256(example.zip)= e3b0c44298fc1c149afbf4c8996fb924"
                                                     "27ae41e4649b934ca495991b7852b855")),
             QStringLiteral("e3b0c44298fc1c149afbf4c8996fb924"
                            "27ae41e4649b934ca495991b7852b855"));
    QCOMPARE(utils::normalizeChecksum(QStringLiteral("e3b0c44298fc1c149afbf4c8996fb924"
                                                     "27ae41e4649b934ca495991b7852b855  example.zip")),
             QStringLiteral("e3b0c44298fc1c149afbf4c8996fb924"
                            "27ae41e4649b934ca495991b7852b855"));
}

void BackendTests::extractChecksumFromText()
{
    const QString checksum = QStringLiteral("e3b0c44298fc1c149afbf4c8996fb924"
                                            "27ae41e4649b934ca495991b7852b855");
    const QString text = QStringLiteral(
        "cafebabecafebabecafebabecafebabecafebabecafebabecafebabecafebabe  other.pkg\n"
        "%1  genydl-1.0.1-macos.dmg\n"
        "SHA256(genydl-1.0.1-windows.exe)= 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\n")
                             .arg(checksum);

    QCOMPARE(utils::extractChecksumFromText(text,
                                            QStringLiteral("genydl-1.0.1-macos.dmg"),
                                            QStringLiteral("SHA256")),
             checksum);
    QCOMPARE(utils::extractChecksumFromText(QStringLiteral("sha256:%1").arg(checksum),
                                            QString(),
                                            QStringLiteral("SHA256")),
             checksum);
}

void BackendTests::normalizeHost()
{
    QCOMPARE(utils::normalizeHost(QStringLiteral("https://Example.com/path?q=1")), QStringLiteral("example.com"));
    QCOMPARE(utils::normalizeHost(QStringLiteral("CDN.EXAMPLE.COM:443")), QStringLiteral("cdn.example.com:443"));
}

void BackendTests::detectCategory()
{
    QCOMPARE(utils::toString(utils::detectCategory(QStringLiteral("movie.mkv"))), QStringLiteral("Video"));
    QCOMPARE(utils::toString(utils::detectCategory(QStringLiteral("archive.tar.gz"))), QStringLiteral("Archives"));
    QCOMPARE(utils::toString(utils::detectCategory(QStringLiteral("unknown.customext"))), QStringLiteral("Other"));
}

void BackendTests::parseGitHubReleaseTagUrl()
{
    const auto parsed = github::parseReleaseUrl(QStringLiteral("https://github.com/genyleap/GenyConnect/releases/tag/v1.4.768"));
    QVERIFY(parsed.has_value());
    QCOMPARE(parsed->owner, QStringLiteral("genyleap"));
    QCOMPARE(parsed->repo, QStringLiteral("GenyConnect"));
    QCOMPARE(parsed->tag, QStringLiteral("v1.4.768"));
    QCOMPARE(static_cast<int>(parsed->kind), static_cast<int>(github::ReleaseRequestKind::Tag));
    QCOMPARE(github::apiUrlForRequest(*parsed).toString(),
             QStringLiteral("https://api.github.com/repos/genyleap/GenyConnect/releases/tags/v1.4.768"));
}

void BackendTests::parseGitHubReleaseLatestUrl()
{
    const auto parsed = github::parseReleaseUrl(QStringLiteral("https://github.com/owner/repo/releases/latest"));
    QVERIFY(parsed.has_value());
    QCOMPARE(parsed->owner, QStringLiteral("owner"));
    QCOMPARE(parsed->repo, QStringLiteral("repo"));
    QCOMPARE(parsed->tag, QString());
    QCOMPARE(static_cast<int>(parsed->kind), static_cast<int>(github::ReleaseRequestKind::Latest));
    QCOMPARE(github::apiUrlForRequest(*parsed).toString(),
             QStringLiteral("https://api.github.com/repos/owner/repo/releases/latest"));
}

void BackendTests::rejectNonGitHubReleaseUrl()
{
    QVERIFY(!github::parseReleaseUrl(QStringLiteral("https://example.com/file.zip")).has_value());
    QVERIFY(!github::parseReleaseUrl(QStringLiteral("https://github.com/owner/repo/archive/refs/tags/v1.zip")).has_value());
    QVERIFY(!github::parseReleaseUrl(QStringLiteral("https://github.com/owner/repo/releases")).has_value());
}

void BackendTests::parseGitHubReleaseJsonWithAssets()
{
    const QByteArray json = R"JSON(
{
  "name": "Version 1.4.768",
  "tag_name": "v1.4.768",
  "published_at": "2026-06-01T12:34:56Z",
  "body": "Release notes",
  "repository": {
    "name": "GenyConnect",
    "owner": { "login": "genyleap" }
  },
  "assets": [
    {
      "name": "GenyConnect-10.dmg",
      "size": 2048,
      "browser_download_url": "https://github.com/genyleap/GenyConnect/releases/download/v1.4.768/GenyConnect-10.dmg",
      "content_type": "application/octet-stream",
      "download_count": 3,
      "created_at": "2026-06-01T12:35:00Z",
      "updated_at": "2026-06-01T12:36:00Z"
    },
    {
      "name": "GenyConnect-2.dmg",
      "size": 1024,
      "browser_download_url": "https://github.com/genyleap/GenyConnect/releases/download/v1.4.768/GenyConnect-2.dmg",
      "content_type": "application/x-apple-diskimage",
      "download_count": 7
    }
  ]
}
)JSON";

    QString error;
    const auto release = github::parseReleaseJson(json, &error);
    QVERIFY2(release.has_value(), qPrintable(error));
    QCOMPARE(release->name, QStringLiteral("Version 1.4.768"));
    QCOMPARE(release->tagName, QStringLiteral("v1.4.768"));
    QCOMPARE(release->repositoryName(), QStringLiteral("genyleap/GenyConnect"));
    QCOMPARE(release->assets.size(), 2);
    QCOMPARE(release->assets.at(0).name, QStringLiteral("GenyConnect-2.dmg"));
    QCOMPARE(release->assets.at(1).name, QStringLiteral("GenyConnect-10.dmg"));
    QCOMPARE(release->assets.at(0).size, 1024);
    QCOMPARE(release->assets.at(0).downloadCount, 7);
}

void BackendTests::parseGitHubReleaseJsonWithEmptyAssets()
{
    const QByteArray json = R"JSON(
{
  "name": "No assets",
  "tag_name": "v2.0.0",
  "published_at": "2026-06-01T12:34:56Z",
  "assets": []
}
)JSON";

    QString error;
    const auto release = github::parseReleaseJson(json, &error);
    QVERIFY2(release.has_value(), qPrintable(error));
    QCOMPARE(release->tagName, QStringLiteral("v2.0.0"));
    QCOMPARE(release->assets.size(), 0);
}

void BackendTests::mapGitHubApiErrors()
{
    QCOMPARE(github::userFriendlyApiError(404, QByteArray(), false),
             QStringLiteral("GitHub repository or release was not found."));
    QCOMPARE(github::userFriendlyApiError(403, QByteArray(), true),
             QStringLiteral("GitHub API rate limit reached. Try again later or configure a GitHub token when token support is enabled."));
    QCOMPARE(github::userFriendlyApiError(500, QByteArray(R"JSON({"message":"server side problem"})JSON"), false),
             QStringLiteral("GitHub API error: server side problem"));
}

void BackendTests::parseGitHubRepositoryUrlsForReleaseCenter()
{
    const auto releases = github::parseRepositoryUrl(QStringLiteral("https://github.com/genyleap/GenyConnect/releases"));
    QVERIFY(releases.has_value());
    QCOMPARE(releases->owner, QStringLiteral("genyleap"));
    QCOMPARE(releases->repo, QStringLiteral("GenyConnect"));
    QCOMPARE(github::latestReleaseApiUrlForRepository(*releases).toString(),
             QStringLiteral("https://api.github.com/repos/genyleap/GenyConnect/releases/latest"));

    const auto repo = github::parseRepositoryUrl(QStringLiteral("https://github.com/owner/repo"));
    QVERIFY(repo.has_value());
    QCOMPARE(repo->repositoryName(), QStringLiteral("owner/repo"));

    const auto latest = github::parseRepositoryUrl(QStringLiteral("https://github.com/owner/repo/releases/latest"));
    QVERIFY(latest.has_value());
    QCOMPARE(latest->repositoryName(), QStringLiteral("owner/repo"));
}

void BackendTests::rejectInvalidReleaseCenterUrls()
{
    QVERIFY(!github::parseRepositoryUrl(QStringLiteral("https://example.com/owner/repo/releases")).has_value());
    QVERIFY(!github::parseRepositoryUrl(QStringLiteral("https://github.com/owner")).has_value());
    QVERIFY(!github::parseRepositoryUrl(QStringLiteral("https://github.com/owner/repo/issues")).has_value());
    QVERIFY(!github::parseRepositoryUrl(QStringLiteral("https://github.com/owner/repo/releases/tag/v1.0.0")).has_value());
}

void BackendTests::parseGitHubRepositoryMetadata()
{
    const QByteArray json = R"JSON({
  "name": "bitcoin",
  "full_name": "bitcoin/bitcoin",
  "description": "Bitcoin Core integration/staging tree",
  "html_url": "https://github.com/bitcoin/bitcoin",
  "homepage": "https://bitcoincore.org",
  "language": "C++",
  "stargazers_count": 84000,
  "forks_count": 36000,
  "watchers_count": 84000,
  "owner": {
    "login": "bitcoin",
    "avatar_url": "https://avatars.githubusercontent.com/u/528860"
  },
  "license": {
    "name": "MIT License",
    "spdx_id": "MIT"
  }
})JSON";

    QString error;
    const auto repo = github::parseRepositoryJson(json, &error);
    QVERIFY2(repo.has_value(), qPrintable(error));
    QCOMPARE(repo->repositoryName(), QStringLiteral("bitcoin/bitcoin"));
    QCOMPARE(repo->description, QStringLiteral("Bitcoin Core integration/staging tree"));
    QCOMPARE(repo->language, QStringLiteral("C++"));
    QCOMPARE(repo->licenseSpdxId, QStringLiteral("MIT"));
    QCOMPARE(repo->stars, 84000);
    QCOMPARE(repo->forks, 36000);
}

void BackendTests::detectNewerReleaseByPublishedDate()
{
    releasecenter::TrackedGitHubApp app;
    app.knownTag = QStringLiteral("nightly-2026-06-05");
    app.knownReleaseId = 100;
    app.knownPublishedAt = QDateTime::fromString(QStringLiteral("2026-06-05T10:00:00Z"), Qt::ISODate);

    github::ReleaseInfo candidate;
    candidate.tagName = QStringLiteral("beta-3");
    candidate.id = 90;
    candidate.publishedAt = QDateTime::fromString(QStringLiteral("2026-06-06T10:00:00Z"), Qt::ISODate);
    QVERIFY(releasecenter::releaseIsNewerThanKnown(candidate, app));

    candidate.publishedAt = QDateTime::fromString(QStringLiteral("2026-06-04T10:00:00Z"), Qt::ISODate);
    QVERIFY(!releasecenter::releaseIsNewerThanKnown(candidate, app));
}

void BackendTests::filterPrereleasesFromReleaseList()
{
    const QByteArray json = R"JSON([
  { "id": 10, "tag_name": "beta-3", "name": "Beta", "published_at": "2026-06-06T10:00:00Z", "prerelease": true, "draft": false, "assets": [] },
  { "id": 9, "tag_name": "v1.0.0", "name": "Stable", "published_at": "2026-06-05T10:00:00Z", "prerelease": false, "draft": false, "assets": [] }
])JSON";
    QString error;
    const auto release = github::parseLatestReleaseFromListJson(json, false, &error);
    QVERIFY2(release.has_value(), qPrintable(error));
    QCOMPARE(release->tagName, QStringLiteral("v1.0.0"));
}

void BackendTests::includePrereleasesFromReleaseList()
{
    const QByteArray json = R"JSON([
  { "id": 10, "tag_name": "beta-3", "name": "Beta", "published_at": "2026-06-06T10:00:00Z", "prerelease": true, "draft": false, "assets": [] },
  { "id": 9, "tag_name": "v1.0.0", "name": "Stable", "published_at": "2026-06-05T10:00:00Z", "prerelease": false, "draft": false, "assets": [] }
])JSON";
    QString error;
    const auto release = github::parseLatestReleaseFromListJson(json, true, &error);
    QVERIFY2(release.has_value(), qPrintable(error));
    QCOMPARE(release->tagName, QStringLiteral("beta-3"));
}

void BackendTests::persistReleaseCenterApps()
{
    releasecenter::TrackedGitHubApp app;
    app.displayName = QStringLiteral("Example App");
    app.owner = QStringLiteral("owner");
    app.repo = QStringLiteral("repo");
    app.originalUrl = QStringLiteral("https://github.com/owner/repo/releases");
    app.description = QStringLiteral("Cached repository description");
    app.avatarUrl = QUrl(QStringLiteral("https://avatars.githubusercontent.com/u/1"));
    app.htmlUrl = QUrl(QStringLiteral("https://github.com/owner/repo"));
    app.homepageUrl = QUrl(QStringLiteral("https://example.com"));
    app.language = QStringLiteral("C++");
    app.licenseSpdxId = QStringLiteral("MIT");
    app.stars = 42;
    app.forks = 7;
    app.knownTag = QStringLiteral("v1");
    app.knownReleaseId = 1;
    app.knownPublishedAt = QDateTime::fromString(QStringLiteral("2026-06-01T10:00:00Z"), Qt::ISODate);
    app.latestTag = QStringLiteral("v2");
    app.latestReleaseId = 2;
    app.latestPublishedAt = QDateTime::fromString(QStringLiteral("2026-06-02T10:00:00Z"), Qt::ISODate);
    app.status = QStringLiteral("update_available");
    app.includePrereleases = true;

    QVector<releasecenter::TrackedGitHubApp> apps{app};
    const QVariantMap settings{
        {QStringLiteral("automaticChecksEnabled"), true},
        {QStringLiteral("checkIntervalHours"), 6},
        {QStringLiteral("showNotifications"), true},
        {QStringLiteral("defaultIncludePrereleases"), false},
        {QStringLiteral("userAgent"), QStringLiteral("ua")},
        {QStringLiteral("githubToken"), QStringLiteral("token")}
    };
    const QByteArray data = releasecenter::saveDocumentForApps(apps, settings);

    QVector<releasecenter::TrackedGitHubApp> loaded;
    QVariantMap loadedSettings;
    QString error;
    QVERIFY2(releasecenter::loadDocumentIntoApps(data, &loaded, &loadedSettings, &error), qPrintable(error));
    QCOMPARE(loaded.size(), 1);
    QCOMPARE(loaded.at(0).displayName, app.displayName);
    QCOMPARE(loaded.at(0).description, app.description);
    QCOMPARE(loaded.at(0).avatarUrl, app.avatarUrl);
    QCOMPARE(loaded.at(0).htmlUrl, app.htmlUrl);
    QCOMPARE(loaded.at(0).homepageUrl, app.homepageUrl);
    QCOMPARE(loaded.at(0).language, app.language);
    QCOMPARE(loaded.at(0).licenseSpdxId, app.licenseSpdxId);
    QCOMPARE(loaded.at(0).stars, app.stars);
    QCOMPARE(loaded.at(0).forks, app.forks);
    QCOMPARE(loaded.at(0).latestTag, app.latestTag);
    QCOMPARE(loaded.at(0).includePrereleases, true);
    QCOMPARE(loadedSettings.value(QStringLiteral("checkIntervalHours")).toInt(), 6);
    QCOMPARE(loadedSettings.value(QStringLiteral("userAgent")).toString(), QStringLiteral("ua"));
    QCOMPARE(loadedSettings.value(QStringLiteral("githubToken")).toString(), QStringLiteral("token"));
}

void BackendTests::exposeReleaseAssetsForPickerIntegration()
{
    releasecenter::TrackedGitHubApp app;
    app.displayName = QStringLiteral("Assets App");
    app.owner = QStringLiteral("owner");
    app.repo = QStringLiteral("repo");
    QVariantMap asset;
    asset.insert(QStringLiteral("name"), QStringLiteral("app.zip"));
    asset.insert(QStringLiteral("downloadUrl"), QStringLiteral("https://github.com/owner/repo/releases/download/v1/app.zip"));
    asset.insert(QStringLiteral("sizeText"), QStringLiteral("1.00 KB"));
    app.latestAssets = QVariantList{asset};

    const QVariantMap map = app.toVariantMap();
    const QVariantList assets = map.value(QStringLiteral("latestAssets")).toList();
    QCOMPARE(assets.size(), 1);
    QCOMPARE(assets.at(0).toMap().value(QStringLiteral("downloadUrl")).toString(),
             QStringLiteral("https://github.com/owner/repo/releases/download/v1/app.zip"));
}

void BackendTests::torrentSessionAvailabilityContract()
{
    TorrentSession session;
#ifdef GENYDL_USE_LIBTORRENT
    // When libtorrent is compiled in, the session must be live.
    QVERIFY(session.isAvailable());
#else
    // Stub build: every operation is a safe no-op and adds report failure (-1).
    QVERIFY(!session.isAvailable());
    QCOMPARE(session.addMagnet(QStringLiteral("magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567"),
                               QStringLiteral("/tmp")),
             qint64(-1));
    QCOMPARE(session.addTorrentFile(QStringLiteral("/tmp/does-not-exist.torrent"),
                                    QStringLiteral("/tmp")),
             qint64(-1));
    QCOMPARE(session.totalDownloadSpeed(), qint64(0));
    QCOMPARE(session.totalUploadSpeed(), qint64(0));
#endif
}

// ---- IPFS resolver ------------------------------------------------------
//
// Vectors cross-checked against a spec reference: the canonical empty-directory
// CIDv0 and CIDv1 decode to the same sha2-256 digest, and the raw CID is
// bafkrei...(sha256("hello world")).
namespace {
const QString kEmptyDirV0 = QStringLiteral("QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn");
const QString kEmptyDirV1 = QStringLiteral("bafybeiczsscdsbs7ffqz55asqdf3smv6klcw3gofszvwlyarci47bgf354");
const QString kEmptyDirDigestHex = QStringLiteral("59948439065f29619ef41280cbb932be52c56d99c5966b65e0111239f098bbef");
const QString kRawCid = QStringLiteral("bafkreifzjut3te2nhyekklss27nh3k72ysco7y32koao5eei66wof36n5e");
const QString kRawDigestHex = QStringLiteral("b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9");
}

void BackendTests::parseCidV0()
{
    const ipfs::Cid cid = ipfs::parseCid(kEmptyDirV0);
    QVERIFY(cid.valid);
    QCOMPARE(cid.version, 0);
    QCOMPARE(cid.codec, ipfs::CodecDagPb);
    QCOMPARE(cid.hashType, ipfs::HashSha2_256);
    QCOMPARE(QString::fromLatin1(cid.digest.toHex()), kEmptyDirDigestHex);
    // dag-pb (UnixFS) content cannot be byte-verified against the CID.
    QVERIFY(!ipfs::isSha256Verifiable(cid));
}

void BackendTests::parseCidV1DagPb()
{
    const ipfs::Cid cid = ipfs::parseCid(kEmptyDirV1);
    QVERIFY(cid.valid);
    QCOMPARE(cid.version, 1);
    QCOMPARE(cid.codec, ipfs::CodecDagPb);
    // CIDv0 and CIDv1 of the same content share a digest.
    QCOMPARE(QString::fromLatin1(cid.digest.toHex()), kEmptyDirDigestHex);
    QVERIFY(!ipfs::isSha256Verifiable(cid));
}

void BackendTests::parseRawCidIsVerifiable()
{
    const ipfs::Cid cid = ipfs::parseCid(kRawCid);
    QVERIFY(cid.valid);
    QCOMPARE(cid.version, 1);
    QCOMPARE(cid.codec, ipfs::CodecRaw);
    QVERIFY(ipfs::isSha256Verifiable(cid));
    QCOMPARE(ipfs::sha256Hex(cid), kRawDigestHex);
}

void BackendTests::rejectInvalidCid()
{
    QVERIFY(!ipfs::parseCid(QStringLiteral("not-a-cid")).valid);
    QVERIFY(!ipfs::parseCid(QString()).valid);
    QVERIFY(!ipfs::parseCid(QStringLiteral("Qmtooshort")).valid);
}

void BackendTests::detectIpfsInputs()
{
    QVERIFY(ipfs::looksLikeIpfs(QStringLiteral("ipfs://") + kEmptyDirV0));
    QVERIFY(ipfs::looksLikeIpfs(QStringLiteral("https://ipfs.io/ipfs/") + kRawCid));
    QVERIFY(ipfs::looksLikeIpfs(kRawCid));          // bare CID
    QVERIFY(ipfs::looksLikeIpfs(kEmptyDirV0));      // bare CIDv0
    QVERIFY(!ipfs::looksLikeIpfs(QStringLiteral("https://example.com/file.zip")));
    QVERIFY(!ipfs::looksLikeIpfs(QStringLiteral("magnet:?xt=urn:btih:abc")));
    QVERIFY(!ipfs::looksLikeIpfs(QStringLiteral("hello world")));
    QVERIFY(!ipfs::looksLikeIpfs(QString()));
}

void BackendTests::parseIpfsReferenceWithSubPath()
{
    const ipfs::Target t = ipfs::parse(
        QStringLiteral("ipfs://") + kRawCid + QStringLiteral("/docs/readme.txt?x=1#frag"));
    QVERIFY(t.valid);
    QCOMPARE(t.cidText, kRawCid);
    QCOMPARE(t.subPath, QStringLiteral("docs/readme.txt"));
    QCOMPARE(ipfs::suggestedFileName(t), QStringLiteral("readme.txt"));

    const ipfs::Target bare = ipfs::parse(kRawCid);
    QVERIFY(bare.valid);
    QVERIFY(bare.subPath.isEmpty());
    QCOMPARE(ipfs::suggestedFileName(bare), kRawCid);
}

void BackendTests::buildIpfsGatewayUrl()
{
    QCOMPARE(ipfs::buildGatewayUrl(QStringLiteral("https://ipfs.io/"), kRawCid, QString()),
             QStringLiteral("https://ipfs.io/ipfs/") + kRawCid);
    QCOMPARE(ipfs::buildGatewayUrl(QStringLiteral("https://ipfs.io"), kRawCid, QStringLiteral("a/b")),
             QStringLiteral("https://ipfs.io/ipfs/") + kRawCid + QStringLiteral("/a/b"));
    QVERIFY(!ipfs::defaultGateways().isEmpty());
}

void BackendTests::languageCatalogContract()
{
    LanguageManager manager;
    const QVariantList languages = manager.availableLanguages();
    QSet<QString> codes;
    QHash<QString, QString> locales;
    QHash<QString, QString> names;
    for (const QVariant& value : languages) {
        const QVariantMap entry = value.toMap();
        const QString code = entry.value(QStringLiteral("code")).toString();
        codes.insert(code);
        locales.insert(code, entry.value(QStringLiteral("locale")).toString());
        names.insert(code, entry.value(QStringLiteral("name")).toString());
        QVERIFY(!names.value(code).isEmpty());
    }

    const QSet<QString> expected{
        QStringLiteral("system"), QStringLiteral("en"), QStringLiteral("fa"),
        QStringLiteral("ar"), QStringLiteral("tr"), QStringLiteral("de"),
        QStringLiteral("fr"), QStringLiteral("es"), QStringLiteral("ru"),
        QStringLiteral("zh_CN")
    };
    QCOMPARE(codes, expected);
    QCOMPARE(QLocale(locales.value(QStringLiteral("fa"))).textDirection(), Qt::RightToLeft);
    QCOMPARE(QLocale(locales.value(QStringLiteral("ar"))).textDirection(), Qt::RightToLeft);
    QCOMPARE(QLocale(locales.value(QStringLiteral("en"))).textDirection(), Qt::LeftToRight);
    QCOMPARE(names.value(QStringLiteral("fa")), QString::fromUtf8("فارسی"));
    QCOMPARE(names.value(QStringLiteral("ar")), QString::fromUtf8("العربية"));
    QCOMPARE(names.value(QStringLiteral("tr")), QString::fromUtf8("Türkçe"));
    QCOMPARE(names.value(QStringLiteral("fr")), QString::fromUtf8("Français"));
    QCOMPARE(names.value(QStringLiteral("es")), QString::fromUtf8("Español"));
    QCOMPARE(names.value(QStringLiteral("ru")), QString::fromUtf8("Русский"));
    QCOMPARE(names.value(QStringLiteral("zh_CN")), QString::fromUtf8("简体中文"));
}

QTEST_MAIN(BackendTests)
#include "backend_tests.moc"
