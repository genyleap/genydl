#include <QtTest/QTest>
#include <QJsonDocument>
#include <QJsonObject>
#include <QCoreApplication>
#include <QProcess>
#include <QSettings>
#include <QDateTime>
#include <QTimer>
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
        QCOMPARE(BrowserActivation::safeFilename(QStringLiteral("CON.zip")), QString());
        QCOMPARE(BrowserActivation::safeFilename(QStringLiteral("com1.txt")), QString());
        QCOMPARE(BrowserActivation::safeFilename(QStringLiteral("LPT9")), QString());
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
    void integrationHeartbeatRequiresPermission()
    {
        const QString enabledKey = QStringLiteral("browserIntegration/enabled/firefox");
        const QString seenKey = QStringLiteral("browserIntegration/lastSeen/firefox");
        QSettings settings;
        const bool hadEnabled = settings.contains(enabledKey);
        const QVariant previousEnabled = settings.value(enabledKey);
        const bool hadSeen = settings.contains(seenKey);
        const QVariant previousSeen = settings.value(seenKey);
        struct Restore {
            QString e, s;
            bool he, hs;
            QVariant pe, ps;
            ~Restore() {
                QSettings settings;
                if (he) settings.setValue(e, pe); else settings.remove(e);
                if (hs) settings.setValue(s, ps); else settings.remove(s);
                settings.sync();
            }
        } restore{enabledKey, seenKey, hadEnabled, hadSeen, previousEnabled, previousSeen};

        BrowserActivation activation([](const QUrl&, const QString&) { return false; });
        QVERIFY(activation.start({}));
        const QByteArray request = QJsonDocument(QJsonObject{
            {QStringLiteral("protocolVersion"), 2},
            {QStringLiteral("type"), QStringLiteral("integration.ping")},
            {QStringLiteral("requestId"), QStringLiteral("hello-firefox-test")},
            {QStringLiteral("browser"), QStringLiteral("firefox")}
        }).toJson(QJsonDocument::Compact) + '\n';

        auto ping = [&](bool expected) {
            QLocalSocket client;
            client.connectToServer(BrowserActivation::socketName());
            QVERIFY(client.waitForConnected(1500));
            QCOMPARE(client.write(request), request.size());
            QVERIFY(client.waitForBytesWritten(1500));
            QTRY_VERIFY_WITH_TIMEOUT(client.bytesAvailable() > 0, 2500);
            const QJsonObject reply = QJsonDocument::fromJson(client.readAll().trimmed()).object();
            QCOMPARE(reply.value(QStringLiteral("ok")).toBool(), expected);
            QCOMPARE(reply.value(QStringLiteral("requestId")).toString(),
                     QStringLiteral("hello-firefox-test"));
        };
        settings.setValue(enabledKey, true);
        settings.sync();
        ping(true);
        settings.sync();
        const QDateTime received = QDateTime::fromString(
            settings.value(seenKey).toString(), Qt::ISODateWithMs);
        QVERIFY(received.isValid());
        QVERIFY(qAbs(received.secsTo(QDateTime::currentDateTimeUtc())) < 10);
        settings.setValue(enabledKey, false);
        settings.sync();
        ping(false);
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
    void nativePromptRequiresApproval() {
        int automaticAdds = 0;
        bool prompted = false;
        BrowserActivation activation([&](const QUrl&, const QString&) {
            ++automaticAdds;
            return true;
        });
        QVERIFY(activation.start({}));
        connect(&activation, &BrowserActivation::promptRequested,
                &activation, [&](const QString& url, const QString& filename) {
            prompted = true;
            QCOMPARE(url, QStringLiteral("https://example.org/archive"));
            QCOMPARE(filename, QStringLiteral("example.zip"));
            QCOMPARE(automaticAdds, 0);
            QTimer::singleShot(50, &activation,
                               [&] { activation.finishPrompt(true); });
        });

        QLocalSocket socket;
        socket.connectToServer(BrowserActivation::socketName());
        QVERIFY(socket.waitForConnected(1500));
        const QByteArray message = QJsonDocument(QJsonObject{
            {QStringLiteral("type"), QStringLiteral("download.prompt")},
            {QStringLiteral("url"), QStringLiteral("https://example.org/archive")},
            {QStringLiteral("filename"), QStringLiteral("/tmp/example.zip")}
        }).toJson(QJsonDocument::Compact) + '\n';
        socket.write(message);
        QVERIFY(socket.waitForBytesWritten(1500));
        QTRY_VERIFY_WITH_TIMEOUT(prompted, 1000);
        QCOMPARE(automaticAdds, 0);
        QTRY_VERIFY_WITH_TIMEOUT(socket.bytesAvailable() > 0, 3000);
        const auto response = QJsonDocument::fromJson(socket.readAll().trimmed()).object();
        QVERIFY(response.value(QStringLiteral("ok")).toBool());
        QCOMPARE(automaticAdds, 0);
    }
    void nativePromptDeclineDoesNotAdd() {
        int automaticAdds = 0;
        BrowserActivation activation([&](const QUrl&, const QString&) {
            ++automaticAdds;
            return true;
        });
        QVERIFY(activation.start({}));
        connect(&activation, &BrowserActivation::promptRequested,
                &activation, [&] (const QString&, const QString&) {
            QTimer::singleShot(0, &activation,
                               [&] { activation.finishPrompt(false); });
        });
        QLocalSocket socket;
        socket.connectToServer(BrowserActivation::socketName());
        QVERIFY(socket.waitForConnected(1500));
        const QByteArray message = QJsonDocument(QJsonObject{
            {QStringLiteral("type"), QStringLiteral("download.prompt")},
            {QStringLiteral("url"), QStringLiteral("https://example.org/archive")}
        }).toJson(QJsonDocument::Compact) + '\n';
        socket.write(message);
        QVERIFY(socket.waitForBytesWritten(1500));
        QTRY_VERIFY_WITH_TIMEOUT(socket.bytesAvailable() > 0, 3000);
        const auto response = QJsonDocument::fromJson(socket.readAll().trimmed()).object();
        QVERIFY(!response.value(QStringLiteral("ok")).toBool());
        QCOMPARE(automaticAdds, 0);
    }
    void nativeHostPromptEndToEnd() {
        int autoAdds = 0;
        bool prompted = false;
        BrowserActivation activation([&](const QUrl&, const QString&) {
            ++autoAdds;
            return true;
        });
        QVERIFY(activation.start({}));
        connect(&activation, &BrowserActivation::promptRequested,
                &activation, [&](const QString& url, const QString& filename) {
            prompted = true;
            QCOMPARE(url, QStringLiteral("https://example.org/final-file"));
            QCOMPARE(filename, QStringLiteral("suggested.zip"));
        });

        const QString host = QCoreApplication::applicationDirPath()
            + QStringLiteral("/bin/GenyDLNativeHost");
        QVERIFY2(QFileInfo::exists(host), qPrintable(host));
        QProcess process;
        process.start(host);
        QVERIFY(process.waitForStarted(3000));

        const QByteArray payload = QJsonDocument(QJsonObject{
            {QStringLiteral("protocolVersion"), 2},
            {QStringLiteral("requestId"), QStringLiteral("native-prompt-e2e")},
            {QStringLiteral("type"), QStringLiteral("download.prompt")},
            {QStringLiteral("url"), QStringLiteral("https://example.org/final-file")},
            {QStringLiteral("filename"), QStringLiteral("suggested.zip")}
        }).toJson(QJsonDocument::Compact);
        const quint32 size = static_cast<quint32>(payload.size());
        QByteArray framed;
        framed.append(static_cast<char>(size & 255));
        framed.append(static_cast<char>((size >> 8) & 255));
        framed.append(static_cast<char>((size >> 16) & 255));
        framed.append(static_cast<char>((size >> 24) & 255));
        framed += payload;
        QCOMPARE(process.write(framed), framed.size());
        process.closeWriteChannel();

        QTRY_VERIFY_WITH_TIMEOUT(prompted, 3000);
        QCOMPARE(autoAdds, 0);
        QCOMPARE(process.state(), QProcess::Running);
        QCOMPARE(process.bytesAvailable(), qint64(0));
        // Only a simulated GUI Add may complete the native host request.
        activation.finishPrompt(true);
        QTRY_VERIFY_WITH_TIMEOUT(process.state() == QProcess::NotRunning, 3000);
        const QByteArray output = process.readAllStandardOutput();
        QVERIFY(output.size() >= 4);
        const quint32 length =
            static_cast<quint8>(output[0])
            | (static_cast<quint32>(static_cast<quint8>(output[1])) << 8)
            | (static_cast<quint32>(static_cast<quint8>(output[2])) << 16)
            | (static_cast<quint32>(static_cast<quint8>(output[3])) << 24);
        QCOMPARE(static_cast<quint32>(output.size() - 4), length);
        const QJsonObject result = QJsonDocument::fromJson(output.mid(4)).object();
        QVERIFY(result.value(QStringLiteral("ok")).toBool());
        QCOMPARE(result.value(QStringLiteral("requestId")).toString(),
                 QStringLiteral("native-prompt-e2e"));
        QCOMPARE(result.value(QStringLiteral("protocolVersion")).toInt(), 2);
        QCOMPARE(autoAdds, 0);
    }

    void protocolStartupRequestsApproval()
    {
        int directAdds = 0;
        int prompts = 0;
        BrowserActivation activation([&](const QUrl&, const QString&) {
            ++directAdds;
            return true;
        });
        connect(&activation, &BrowserActivation::promptRequested,
                &activation, [&](const QString& url, const QString&) {
            QCOMPARE(url, QStringLiteral("https://example.org/protocol.zip"));
            ++prompts;
        });
        const QString protocol = QStringLiteral("genydl://download/?url=")
            + QString::fromUtf8(QUrl::toPercentEncoding(
                QStringLiteral("https://example.org/protocol.zip")));
        QVERIFY(activation.start({protocol}));
        QTRY_COMPARE_WITH_TIMEOUT(prompts, 1, 1000);
        QCOMPARE(directAdds, 0);
        activation.finishPrompt(false);
        QCOMPARE(directAdds, 0);
    }

    void manualServicesUsesReviewDialog()
    {
        int directAdds = 0;
        int prompts = 0;
        BrowserActivation activation([&](const QUrl&, const QString&) {
            ++directAdds;
            return true;
        });
        QVERIFY(activation.start({}));
        connect(&activation, &BrowserActivation::promptRequested,
                &activation, [&](const QString& url, const QString&) {
            QCOMPARE(url, QStringLiteral("https://example.org/manual.dmg"));
            ++prompts;
        });
        QVERIFY(activation.submitUrl(QStringLiteral("https://example.org/manual.dmg")));
        QTRY_COMPARE_WITH_TIMEOUT(prompts, 1, 1000);
        QCOMPARE(directAdds, 0);
        activation.finishPrompt(false);
        QCOMPARE(directAdds, 0);
        QVERIFY(!activation.submitUrl(QStringLiteral("file:///etc/passwd")));
    }

    void promptWaitsForFrontendReadiness()
    {
        int shown = 0;
        BrowserActivation activation([&](const QUrl&, const QString&) {
            return true;
        });
        activation.setFrontendReady(false);
        QVERIFY(activation.start({}));
        connect(&activation, &BrowserActivation::promptRequested,
                &activation, [&](const QString&, const QString&) { ++shown; });

        QLocalSocket socket;
        socket.connectToServer(BrowserActivation::socketName());
        QVERIFY(socket.waitForConnected(1500));
        const QByteArray message = QJsonDocument(QJsonObject{
            {QStringLiteral("protocolVersion"), 2},
            {QStringLiteral("requestId"), QStringLiteral("startup-before-qml")},
            {QStringLiteral("type"), QStringLiteral("download.prompt")},
            {QStringLiteral("url"), QStringLiteral("https://example.org/startup.zip")}
        }).toJson(QJsonDocument::Compact) + '\n';
        socket.write(message);
        QVERIFY(socket.waitForBytesWritten(1500));
        QCoreApplication::processEvents();
        QCOMPARE(shown, 0);
        QCOMPARE(socket.bytesAvailable(), qint64(0));

        activation.setFrontendReady(true);
        QTRY_COMPARE_WITH_TIMEOUT(shown, 1, 1500);
        activation.finishPrompt(false);
        QTRY_VERIFY_WITH_TIMEOUT(socket.bytesAvailable() > 0, 1500);
        const QJsonObject reply = QJsonDocument::fromJson(
            socket.readAll().trimmed()).object();
        QVERIFY(!reply.value(QStringLiteral("ok")).toBool());
        QCOMPARE(reply.value(QStringLiteral("requestId")).toString(),
                 QStringLiteral("startup-before-qml"));
    }

    void queuedPromptsUseIndependentIds()
    {
        QStringList shown;
        int directAdds = 0;
        BrowserActivation activation([&](const QUrl&, const QString&) {
            ++directAdds;
            return true;
        });
        QVERIFY(activation.start({}));
        connect(&activation, &BrowserActivation::promptRequested,
                &activation, [&](const QString& url, const QString&) { shown << url; });

        auto submit = [&](QLocalSocket& socket, const QString& id) {
            socket.connectToServer(BrowserActivation::socketName());
            QVERIFY(socket.waitForConnected(1500));
            const QByteArray message = QJsonDocument(QJsonObject{
                {QStringLiteral("protocolVersion"), 2},
                {QStringLiteral("requestId"), id},
                {QStringLiteral("type"), QStringLiteral("download.prompt")},
                {QStringLiteral("url"),
                 QStringLiteral("https://example.org/") + id + QStringLiteral(".zip")}
            }).toJson(QJsonDocument::Compact) + '\n';
            QCOMPARE(socket.write(message), message.size());
            QVERIFY(socket.waitForBytesWritten(1500));
        };

        QLocalSocket first;
        QLocalSocket second;
        QLocalSocket duplicate;
        submit(first, QStringLiteral("test-first"));
        QTRY_COMPARE_WITH_TIMEOUT(shown.size(), 1, 1000);
        submit(second, QStringLiteral("test-second"));
        QCoreApplication::processEvents();
        QCOMPARE(shown.size(), 1);
        QCOMPARE(directAdds, 0);

        // A duplicate ID must not open another dialog or steal a slot.
        submit(duplicate, QStringLiteral("test-first"));
        QTRY_VERIFY_WITH_TIMEOUT(duplicate.bytesAvailable() > 0, 1000);
        const QJsonObject repeated = QJsonDocument::fromJson(
            duplicate.readAll().trimmed()).object();
        QVERIFY(!repeated.value(QStringLiteral("ok")).toBool());
        QCOMPARE(shown.size(), 1);

        activation.finishPrompt(true);
        QTRY_VERIFY_WITH_TIMEOUT(first.bytesAvailable() > 0, 1000);
        const QJsonObject accepted = QJsonDocument::fromJson(
            first.readAll().trimmed()).object();
        QVERIFY(accepted.value(QStringLiteral("ok")).toBool());
        QCOMPARE(accepted.value(QStringLiteral("requestId")).toString(),
                 QStringLiteral("test-first"));
        QTRY_COMPARE_WITH_TIMEOUT(shown.size(), 2, 2500);
        QCOMPARE(shown.last(), QStringLiteral("https://example.org/test-second.zip"));
        activation.finishPrompt(false);
        QTRY_VERIFY_WITH_TIMEOUT(second.bytesAvailable() > 0, 1000);
        const QJsonObject declined = QJsonDocument::fromJson(
            second.readAll().trimmed()).object();
        QVERIFY(!declined.value(QStringLiteral("ok")).toBool());
        QCOMPARE(declined.value(QStringLiteral("requestId")).toString(),
                 QStringLiteral("test-second"));
        QCOMPARE(directAdds, 0);
    }

    void v2AutomaticRequestIsIdempotent()
    {
        int directAdds = 0;
        BrowserActivation activation([&](const QUrl&, const QString&) {
            ++directAdds;
            return true;
        });
        QVERIFY(activation.start({}));

        const QByteArray message = QJsonDocument(QJsonObject{
            {QStringLiteral("protocolVersion"), 2},
            {QStringLiteral("requestId"), QStringLiteral("automatic-example")},
            {QStringLiteral("type"), QStringLiteral("download.request")},
            {QStringLiteral("url"), QStringLiteral("https://example.org/auto.zip")}
        }).toJson(QJsonDocument::Compact) + '\n';
        auto submit = [&](QLocalSocket& socket) {
            socket.connectToServer(BrowserActivation::socketName());
            QVERIFY(socket.waitForConnected(1500));
            QCOMPARE(socket.write(message), message.size());
            QVERIFY(socket.waitForBytesWritten(1500));
            QTRY_VERIFY_WITH_TIMEOUT(socket.bytesAvailable() > 0, 1000);
        };
        QLocalSocket first, repeated;
        submit(first);
        QVERIFY(QJsonDocument::fromJson(first.readAll().trimmed()).object()
                .value(QStringLiteral("ok")).toBool());
        submit(repeated);
        QVERIFY(!QJsonDocument::fromJson(repeated.readAll().trimmed()).object()
                 .value(QStringLiteral("ok")).toBool());
        QCOMPARE(directAdds, 1);
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
