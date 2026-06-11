module;
#include <QAction>
#include <QApplication>
#include <QCoreApplication>
#include <QGuiApplication>
#include <QIcon>
#include <QMenu>
#include <QMetaObject>
#include <QSystemTrayIcon>
#include <QWindow>

module genydl.core.appcontroller;

import genydl.ui.tray_icon_provider;

AppController::AppController(QObject* downloadManager, QObject* parent)
    : QObject(parent)
    , m_downloadManager(downloadManager)
{
    QApplication::setQuitOnLastWindowClosed(false);
    setupTray();

#ifdef Q_OS_MACOS
    // On macOS, hide-to-tray leaves the app windowless. Clicking the Dock icon
    // reactivates the application but cannot reopen a window on its own, so
    // restore the hidden main window when the app is brought to the front.
    connect(qApp, &QGuiApplication::applicationStateChanged, this,
            [this](Qt::ApplicationState state) {
        if (state == Qt::ApplicationActive && !m_explicitQuitRequested
            && m_mainWindow && !m_mainWindow->isVisible()) {
            showMainWindow();
        }
    });
#endif
}

AppController::~AppController()
{
    if (m_trayIcon) {
        m_trayIcon->hide();
    }
    delete m_trayMenu;
}

void AppController::setKeepRunningInBackground(bool enabled)
{
    if (m_keepRunningInBackground == enabled) return;
    m_keepRunningInBackground = enabled;
    emit keepRunningInBackgroundChanged();
}

bool AppController::trayAvailable() const
{
    return QSystemTrayIcon::isSystemTrayAvailable();
}

bool AppController::mainWindowVisible() const
{
    return m_mainWindow && m_mainWindow->isVisible();
}

void AppController::setMainWindow(QObject* windowObject)
{
    QWindow* window = qobject_cast<QWindow*>(windowObject);
    if (m_mainWindow == window) return;

    if (m_mainWindow) {
        disconnect(m_mainWindow, nullptr, this, nullptr);
    }

    m_mainWindow = window;
    if (m_mainWindow) {
        connect(m_mainWindow, &QWindow::visibleChanged, this, [this]() {
            updateTrayActions();
            emit mainWindowVisibilityChanged();
        });
        connect(m_mainWindow, &QObject::destroyed, this, [this]() {
            m_mainWindow.clear();
            updateTrayActions();
            emit mainWindowVisibilityChanged();
        });
    }

    updateTrayActions();
    emit mainWindowVisibilityChanged();
}

bool AppController::requestWindowClose(bool hasActiveDownloads)
{
    if (m_explicitQuitRequested) {
        return true;
    }

    // IMPORTANT: this runs while the window is still delivering its own close
    // event. Mutating the window (hide()) or reaching into the platform tray
    // synchronously here re-enters the native window code mid-close and crashes
    // (EXC_BAD_ACCESS on macOS/Cocoa). Decide synchronously, but always defer
    // the actual window/tray/quit work to the next event-loop tick.

    if (m_keepRunningInBackground || hasActiveDownloads) {
        if (trayAvailable()) {
            QMetaObject::invokeMethod(this, [this, hasActiveDownloads]() {
                hideMainWindow();
                postTrayMessage(QStringLiteral("GenyDL is still running"),
                                hasActiveDownloads
                                    ? QStringLiteral("Downloads continue in the background.")
                                    : QStringLiteral("Use the tray icon to restore or exit."),
                                3000);
            }, Qt::QueuedConnection);
        } else {
            emit closeBlocked(hasActiveDownloads);
        }
        return false;
    }

    // Background mode is disabled and nothing is active: closing the window
    // means "quit". Because setQuitOnLastWindowClosed(false) keeps the process
    // alive once the last window accepts its close event, simply accepting here
    // would strand a headless, windowless process. Drive an explicit,
    // deterministic shutdown (deferred, for the same re-entrancy reason) and
    // veto the raw close so teardown always flows through a single path.
    QMetaObject::invokeMethod(this, &AppController::quitApplication, Qt::QueuedConnection);
    return false;
}

void AppController::showMainWindow()
{
    if (!m_mainWindow) return;
    m_mainWindow->show();
    m_mainWindow->raise();
    m_mainWindow->requestActivate();
    updateTrayActions();
    emit mainWindowVisibilityChanged();
}

void AppController::hideMainWindow()
{
    if (!m_mainWindow) return;
    m_mainWindow->hide();
    updateTrayActions();
    emit mainWindowVisibilityChanged();
}

void AppController::toggleMainWindow()
{
    if (mainWindowVisible()) {
        hideMainWindow();
    } else {
        showMainWindow();
    }
}

void AppController::quitApplication()
{
    m_explicitQuitRequested = true;
    if (m_trayIcon) {
        m_trayIcon->hide();
    }
    QCoreApplication::quit();
}

bool AppController::showNotification(const QString& title, const QString& message)
{
    if (!trayAvailable() || !m_trayIcon) {
        return false;
    }
#ifdef Q_OS_MACOS
    // See postTrayMessage(): the native notification path crashes on macOS.
    return false;
#else
    postTrayMessage(title, message, 6000);
    return true;
#endif
}

void AppController::postTrayMessage(const QString& title, const QString& message, int msecs)
{
    if (!m_trayIcon || !QSystemTrayIcon::supportsMessages()) {
        return;
    }
#ifdef Q_OS_MACOS
    // QSystemTrayIcon::showMessage() on macOS builds a native NSUserNotification
    // and re-encodes the tray icon as its content image. On this Qt/macOS
    // combination that path faults inside ImageIO (EXC_BAD_ACCESS in
    // PNGWritePlugin::writePrologue), taking the whole app down. Hide-to-tray
    // does not depend on the balloon, so suppress it here rather than crash.
    Q_UNUSED(title);
    Q_UNUSED(message);
    Q_UNUSED(msecs);
#else
    m_trayIcon->showMessage(title, message, QSystemTrayIcon::Information, msecs);
#endif
}

void AppController::setupTray()
{
    m_trayMenu = new QMenu();
    m_showHideAction = m_trayMenu->addAction(QStringLiteral("Show GenyDL"));
    connect(m_showHideAction, &QAction::triggered, this, &AppController::toggleMainWindow);

    m_trayMenu->addSeparator();
    m_startAllAction = m_trayMenu->addAction(QStringLiteral("Start All"));
    connect(m_startAllAction, &QAction::triggered, this, [this]() {
        invokeDownloadManager("resumeAll");
    });

    m_pauseAllAction = m_trayMenu->addAction(QStringLiteral("Pause All"));
    connect(m_pauseAllAction, &QAction::triggered, this, [this]() {
        invokeDownloadManager("pauseAll");
    });

    m_trayMenu->addSeparator();
    m_exitAction = m_trayMenu->addAction(QStringLiteral("Exit"));
    connect(m_exitAction, &QAction::triggered, this, &AppController::quitApplication);

    m_trayIcon = new QSystemTrayIcon(genydl::ui::createTrayIcon(), this);
    m_trayIcon->setToolTip(QStringLiteral("GenyDL Download Manager"));
    m_trayIcon->setContextMenu(m_trayMenu);
    connect(m_trayIcon, &QSystemTrayIcon::activated, this, [this](QSystemTrayIcon::ActivationReason reason) {
        if (reason == QSystemTrayIcon::Trigger || reason == QSystemTrayIcon::DoubleClick) {
            toggleMainWindow();
        }
    });
    connect(m_trayIcon, &QSystemTrayIcon::messageClicked, this, [this]() {
        showMainWindow();
        emit notificationClicked();
    });

    if (trayAvailable()) {
        m_trayIcon->show();
    }
    updateTrayActions();
}

void AppController::updateTrayActions()
{
    if (!m_showHideAction) return;
    m_showHideAction->setText(mainWindowVisible()
                                  ? QStringLiteral("Hide GenyDL")
                                  : QStringLiteral("Show GenyDL"));
}

void AppController::invokeDownloadManager(const char* method)
{
    if (!m_downloadManager) return;
    QMetaObject::invokeMethod(m_downloadManager, method, Qt::QueuedConnection);
}
