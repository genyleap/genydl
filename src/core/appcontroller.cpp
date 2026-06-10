module;
#include <QAction>
#include <QApplication>
#include <QCoreApplication>
#include <QIcon>
#include <QMenu>
#include <QMetaObject>
#include <QSystemTrayIcon>
#include <QWindow>

module genydl.core.appcontroller;

AppController::AppController(QObject* downloadManager, QObject* parent)
    : QObject(parent)
    , m_downloadManager(downloadManager)
{
    QApplication::setQuitOnLastWindowClosed(false);
    setupTray();
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

    if (m_keepRunningInBackground || hasActiveDownloads) {
        if (trayAvailable()) {
            hideMainWindow();
            if (m_trayIcon) {
                m_trayIcon->showMessage(QStringLiteral("GenyDL is still running"),
                                        hasActiveDownloads
                                            ? QStringLiteral("Downloads continue in the background.")
                                            : QStringLiteral("Use the tray icon to restore or exit."),
                                        QSystemTrayIcon::Information,
                                        3000);
            }
        } else {
            emit closeBlocked(hasActiveDownloads);
        }
        return false;
    }

    return true;
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
    m_trayIcon->showMessage(title,
                            message,
                            QSystemTrayIcon::Information,
                            6000);
    return true;
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

    m_trayIcon = new QSystemTrayIcon(QIcon(QStringLiteral(":/GenyDL.png")), this);
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
