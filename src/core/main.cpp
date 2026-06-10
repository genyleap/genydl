#include <QApplication>
#include <QCoreApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QOperatingSystemVersion>
#include <QQuickWindow>
#include <QSGRendererInterface>
#include <QQuickStyle>
#include <QStandardPaths>
#include <QDir>
#include <QFile>
#include <QIcon>
#include <QUrl>

import genydl.core.downloadmanager;
import genydl.core.appcontroller;
import genydl.services.github_release_service;
import genydl.services.release_center_service;
import genydl.services.update_client;
import genydl.services.torrent_session;
import genydl.services.gateway_service;

#ifndef APP_VERSION
#define APP_VERSION "0.1.0"
#endif


[[nodiscard]] constexpr auto preferredGraphicsApi() noexcept
    -> QSGRendererInterface::GraphicsApi
{
#if defined(Q_OS_WIN)
    /*
        Windows policy:

        - Qt Quick on Windows still uses Direct3D 11 as the default backend.
        - Direct3D 12 is supported too, but only since Qt 6.6.
        - We intentionally enable D3D12 only on Windows 11+ as a conservative
          project policy, not because Windows 10 cannot support it.
        - This keeps Windows 10 on the broader, safer default path, while
          allowing newer Windows systems to use the newer backend.

        If you want a more aggressive policy later, you can switch this branch
        to always prefer Direct3D12 on Qt 6.6+.
    */

#  if QT_VERSION >= QT_VERSION_CHECK(6, 6, 0)
    return QOperatingSystemVersion::current() >= QOperatingSystemVersion::Windows11
               ? QSGRendererInterface::Direct3D12
               : QSGRendererInterface::Direct3D11;
#  else
    return QSGRendererInterface::Direct3D11;
#  endif

#elif defined(Q_OS_MACOS)
    /*
        macOS policy:

        - Use Metal on both Intel Macs and Apple Silicon Macs.
        - This is the native modern graphics backend on macOS.
    */
    return QSGRendererInterface::Metal;

#elif defined(Q_OS_LINUX)
    /*
        Linux policy:

        - Prefer OpenGL for the widest desktop compatibility across drivers,
          distributions, X11/Wayland environments, and packaged deployments.
        - Vulkan can be excellent too, but it is better as an explicit opt-in
          when the target environment is known and controlled.
    */
    return QSGRendererInterface::OpenGL;

#else
    /*
        Fallback policy:

        - Let Qt choose its platform default on unsupported or unhandled targets.
    */
    return QSGRendererInterface::Unknown;
#endif
}

inline void configureGraphicsBackend()
{
    QQuickWindow::setGraphicsApi(preferredGraphicsApi());
}

auto main(int argc, char *argv[]) -> int
{
    QApplication app(argc, argv);
    QCoreApplication::setOrganizationName(QStringLiteral("Genyleap"));
    QCoreApplication::setApplicationName(QStringLiteral("GenyDL"));
    QCoreApplication::setApplicationVersion(QStringLiteral(APP_VERSION));
    app.setWindowIcon(QIcon(QStringLiteral(":/GenyDL.png")));
    QQuickStyle::setStyle("Basic");

    ::configureGraphicsBackend();

    // Create TorrentSession (no-op when libtorrent is not compiled in)
    TorrentSession torrentSession;

    // Smart Gateway System: IPFS gateway pool, health monitoring, priority.
    GatewayService gatewayService;

    // Create DownloadManager instance
    DownloadManager manager(&torrentSession, &gatewayService);
    UpdateClient updateClient;
    GitHubReleaseService githubReleaseService;
    GitHubReleaseTrackerService releaseCenterService;
    AppController appController(&manager);

    const QString appDir = QCoreApplication::applicationDirPath();
    const QString fontFileName = QStringLiteral("fa-solid-900.ttf");
    QString fontPath;
    const QStringList fontBases = {
        QDir::currentPath() + "/fonts",
        appDir + "/fonts",
        QDir(appDir).filePath("../Resources/fonts"),
        QDir(appDir).filePath("../fonts"),
        QDir(appDir).filePath("../../fonts")
    };
    for (const QString& base : fontBases) {
        const QString candidate = QDir(base).filePath(fontFileName);
        if (QFile::exists(candidate)) {
            fontPath = QUrl::fromLocalFile(candidate).toString();
            break;
        }
    }

    // Set up QML engine
    QQmlApplicationEngine engine;

    // Expose the manager to QML
    engine.rootContext()->setContextProperty("downloadManager", &manager);
    engine.rootContext()->setContextProperty("torrentSession", &torrentSession);
    engine.rootContext()->setContextProperty("gatewayService", &gatewayService);
    engine.rootContext()->setContextProperty("updateClient", &updateClient);
    engine.rootContext()->setContextProperty("githubReleaseService", &githubReleaseService);
    engine.rootContext()->setContextProperty("releaseCenterService", &releaseCenterService);
    engine.rootContext()->setContextProperty("appController", &appController);
    QString downloadsRoot = QDir(QStandardPaths::writableLocation(QStandardPaths::DownloadLocation)).filePath(QStringLiteral("GenyDL"));
    if (downloadsRoot.isEmpty()) {
        downloadsRoot = QStandardPaths::writableLocation(QStandardPaths::DownloadLocation);
    }
    if (!downloadsRoot.isEmpty()) {
        QDir().mkpath(downloadsRoot);
    }
    engine.rootContext()->setContextProperty("documentsFolder", downloadsRoot);
    engine.rootContext()->setContextProperty("faFontPath", fontPath);

    // Tell the Release Center where to look for completed downloads so it can
    // detect which tracked apps are already downloaded/installed.
    {
        QStringList downloadRoots;
        if (!downloadsRoot.isEmpty()) downloadRoots << downloadsRoot;
        const QString plainDownloads = QStandardPaths::writableLocation(QStandardPaths::DownloadLocation);
        if (!plainDownloads.isEmpty()) downloadRoots << plainDownloads;
        releaseCenterService.setDownloadRoots(downloadRoots);
    }


    // Handle QML loading errors
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.loadFromModule("GenyDL", "Main");

    if (engine.rootObjects().isEmpty())
        return -1;

    appController.setMainWindow(engine.rootObjects().first());

    return app.exec();
}
