#include <QtTest/QtTest>

import tondar.utils.version_utils;
import tondar.utils.download_utils;
import tondar.utils.category_utils;
import tondar.services.github_release_service;

namespace utils = tondar::utils;
namespace github = tondar::github;

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
        "%1  tondar-1.0.1-macos.dmg\n"
        "SHA256(tondar-1.0.1-windows.exe)= 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\n")
                             .arg(checksum);

    QCOMPARE(utils::extractChecksumFromText(text,
                                            QStringLiteral("tondar-1.0.1-macos.dmg"),
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

QTEST_MAIN(BackendTests)
#include "backend_tests.moc"
