#include <QtTest/QTest>
#include <QJsonDocument>
#include <QJsonObject>
#include <QCoreApplication>
#include <QProcess>
#include <QFileInfo>
#include <QLocalSocket>
#include <QUrl>
#include "browser_activation.h"

class BrowserBridgeTests final : public QObject {
    Q_OBJECT
private slots:
    void initTestCase() {
        QCoreApplication::setOrganizationName(QStringLiteral("Genyleap"));
        QCoreApplication::setApplicationName(QStringLiteral("GenyDL"));
    }
    void parseProtocol() {
        const QString download = QStringLiteral("https://example.org/dl/file.zip?token=abc");
        const QString encoded = QStringLiteral("genydl://download/?url=")
            + QString::fromUtf8(QUrl::toPercentEncoding(download));
        QCOMPARE(BrowserActivation::parseDownloadUrl(encoded).toString(), download);
        QVERIFY(!BrowserActivation::parseDownloadUrl(
            QStringLiteral("genydl://other/?url=https%3A%2F%2Fexample.org")).isValid());
    }
    void rejectUnsafeUrls() {
        const QStringList unsafe = {
            QStringLiteral("file:///tmp/test"), QStringLiteral("javascript:alert(1)"),
            QStringLiteral("https://user:password@example.org/x"),
            QStringLiteral("http://localhost/x"), QStringLiteral("http://127.0.0.1/x"),
            QStringLiteral("http://[::1]/x")
        };
        for (const auto& input : unsafe) {
            QVERIFY2(!BrowserActivation::isSafeHttpUrl(
                BrowserActivation::parseDownloadUrl(input)), qPrintable(input));
        }
        QVERIFY(BrowserActivation::isSafeHttpUrl(
            QUrl(QStringLiteral("https://example.org/file.dmg"))));
    }
    void filenameHintsAreBasenamesOnly() {
        QCOMPARE(BrowserActivation::safeFilename(
            QStringLiteral("/Users/example/Downloads/genydl-main.zip")),
            QStringLiteral("genydl-main.zip"));
        QCOMPARE(BrowserActivation::safeFilename(
            QStringLiteral("C:\\Users\\example\\Downloads\\app.dmg")),
            QStringLiteral("app.dmg"));
        QCOMPARE(BrowserActivation::safeFilename(QStringLiteral("../../escape.zip")),
            QStringLiteral("escape.zip"));
        QCOMPARE(BrowserActivation::safeFilename(QStringLiteral("..")), QString());
        QCOMPARE(BrowserActivation::safeFilename(QStringLiteral("bad\nname.zip")), QString());
        QCOMPARE(BrowserActivation::safeFilename(QStringLiteral("bad:name.zip")), QString());
    }
    void rejectedRequestNeverAcknowledged() {
        int accepted = 0;
        BrowserActivation activation([&](const QUrl&, const QString&) { ++accepted; return true; });
        QVERIFY(activation.start({}));
        QLocalSocket socket;
        socket.connectToServer(BrowserActivation::socketName());
        QVERIFY(socket.waitForConnected(1500));
        const QByteArray invalid = QJsonDocument(QJsonObject{
            {QStringLiteral("type"), QStringLiteral("download.request")},
            {QStringLiteral("url"), QStringLiteral("file:///tmp/private")}
        }).toJson(QJsonDocument::Compact) + '\n';
        socket.write(invalid);
        QVERIFY(socket.waitForBytesWritten(1500));
        QTRY_VERIFY_WITH_TIMEOUT(socket.bytesAvailable() > 0, 3000);
        const auto response = QJsonDocument::fromJson(socket.readAll().trimmed()).object();
        QVERIFY(!response.value(QStringLiteral("ok")).toBool());
        QCOMPARE(accepted, 0);
    }
    void nativeHostEndToEnd() {
        QString received;
        QString receivedFilename;
        BrowserActivation activation([&](const QUrl& url, const QString& filename) {
            received = url.toString();
            receivedFilename = filename;
            return true;
        });
        QVERIFY(activation.start({}));

        const QString host = QCoreApplication::applicationDirPath()
            + QStringLiteral("/bin/GenyDLNativeHost");
        QVERIFY2(QFileInfo::exists(host), qPrintable(host));
        QProcess process;
        process.start(host);
        QVERIFY(process.waitForStarted(3000));
        const QByteArray payload = QJsonDocument(QJsonObject{
            {QStringLiteral("type"), QStringLiteral("download.request")},
            {QStringLiteral("url"), QStringLiteral("https://example.org/from-native.dmg")},
            {QStringLiteral("filename"), QStringLiteral("/Users/example/Downloads/final.dmg")}
        }).toJson(QJsonDocument::Compact);
        const quint32 size = static_cast<quint32>(payload.size());
        QByteArray frame;
        frame.append(static_cast<char>(size & 255));
        frame.append(static_cast<char>((size >> 8) & 255));
        frame.append(static_cast<char>((size >> 16) & 255));
        frame.append(static_cast<char>((size >> 24) & 255));
        frame += payload;
        QCOMPARE(process.write(frame), frame.size());
        process.closeWriteChannel();
        QTRY_VERIFY_WITH_TIMEOUT(process.state() == QProcess::NotRunning, 6000);
        const QByteArray output = process.readAllStandardOutput();
        QVERIFY(output.size() > 4);
        const quint32 responseSize =
            static_cast<quint8>(output[0])
            | (static_cast<quint32>(static_cast<quint8>(output[1])) << 8)
            | (static_cast<quint32>(static_cast<quint8>(output[2])) << 16)
            | (static_cast<quint32>(static_cast<quint8>(output[3])) << 24);
        QCOMPARE(static_cast<quint32>(output.size() - 4), responseSize);
        const QJsonObject response = QJsonDocument::fromJson(output.mid(4)).object();
        QVERIFY(response.value(QStringLiteral("ok")).toBool());
        QCOMPARE(received, QStringLiteral("https://example.org/from-native.dmg"));
        QCOMPARE(receivedFilename, QStringLiteral("final.dmg"));
    }
    void nativeHandoffAndAck() {
        QString received;
        BrowserActivation activation([&](const QUrl& url, const QString&) {
            received = url.toString();
            return true;
        });
        QVERIFY(activation.start({}));
        QLocalSocket socket;
        socket.connectToServer(BrowserActivation::socketName());
        QVERIFY(socket.waitForConnected(1500));
        const QByteArray request = R"({"type":"download.request","url":"https://example.org/a.zip"})";
        socket.write(request + '\n');
        QVERIFY(socket.waitForBytesWritten(1500));
        QTRY_VERIFY_WITH_TIMEOUT(socket.bytesAvailable() > 0, 3000);
        const auto response = QJsonDocument::fromJson(socket.readAll().trimmed()).object();
        QVERIFY(response.value(QStringLiteral("ok")).toBool());
        QCOMPARE(received, QStringLiteral("https://example.org/a.zip"));
    }
};

QTEST_GUILESS_MAIN(BrowserBridgeTests)
#include "browser_bridge_tests.moc"
