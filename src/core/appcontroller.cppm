/*!
 * @file        appcontroller.cppm
 * @brief       Application window, tray, and background-mode controller.
 * @details     Exposes a small UI-facing controller for close interception,
 *              system tray actions, and explicit quit semantics.
 *
 * @author      <a href='https://github.com/thecompez'>Kambiz Asadzadeh</a>
 * @since       05 Jun 2026
 * @copyright   Copyright (c) 2026 Genyleap. All rights reserved.
 * @license     https://github.com/genyleap/genydl/blob/main/LICENSE.md
 */

module;
#include <QAction>
#include <QObject>
#include <QMenu>
#include <QPointer>
#include <QSystemTrayIcon>
#include <QWindow>

#ifndef Q_MOC_RUN
export module genydl.core.appcontroller;
#endif

#ifdef Q_MOC_RUN
#define GENYDL_MODULE_EXPORT
#else
#define GENYDL_MODULE_EXPORT export
#endif

/**
 * @brief Coordinates GENYDL background mode and system tray behavior.
 *
 * AppController owns the tray icon/menu, tracks whether a close request should
 * hide the main window instead of quitting, and keeps explicit Exit/Quit
 * separate from ordinary window close events.
 */
GENYDL_MODULE_EXPORT class AppController : public QObject {
    Q_OBJECT

    //!< @brief Whether closing the main window keeps the process running.
    Q_PROPERTY(bool keepRunningInBackground READ keepRunningInBackground WRITE setKeepRunningInBackground NOTIFY keepRunningInBackgroundChanged)

    //!< @brief Whether the current platform exposes a usable system tray.
    Q_PROPERTY(bool trayAvailable READ trayAvailable NOTIFY trayAvailabilityChanged)

    //!< @brief Whether the main window is currently visible.
    Q_PROPERTY(bool mainWindowVisible READ mainWindowVisible NOTIFY mainWindowVisibilityChanged)

public:
    /**
     * @brief Construct the application controller.
     * @param downloadManager Download manager QObject used by tray actions.
     * @param parent Optional parent QObject.
     */
    explicit AppController(QObject* downloadManager, QObject* parent = nullptr);
    ~AppController() override;

    //!< @brief Return the background close policy.
    bool keepRunningInBackground() const { return m_keepRunningInBackground; }

    /**
     * @brief Set the background close policy.
     * @param enabled Whether close should hide the app.
     */
    void setKeepRunningInBackground(bool enabled);

    //!< @brief Return whether a tray icon is available.
    bool trayAvailable() const;

    //!< @brief Return whether the tracked main window is visible.
    bool mainWindowVisible() const;

    /**
     * @brief Attach the main QML window.
     * @param windowObject QML ApplicationWindow object.
     */
    Q_INVOKABLE void setMainWindow(QObject* windowObject);

    /**
     * @brief Handle a user-initiated main window close.
     * @param hasActiveDownloads Whether downloads are active or queued.
     * @return True when the caller should accept the close event.
     */
    Q_INVOKABLE bool requestWindowClose(bool hasActiveDownloads);

    //!< @brief Show and activate the main window.
    Q_INVOKABLE void showMainWindow();

    //!< @brief Hide the main window without quitting.
    Q_INVOKABLE void hideMainWindow();

    //!< @brief Toggle the main window visibility.
    Q_INVOKABLE void toggleMainWindow();

    //!< @brief Explicitly quit the application.
    Q_INVOKABLE void quitApplication();

    /**
     * @brief Show a desktop/tray notification when the platform supports it.
     * @param title Notification title.
     * @param message Notification body.
     * @return True if a tray notification was requested.
     */
    Q_INVOKABLE bool showNotification(const QString& title, const QString& message);

signals:
    //!< @brief Emitted when the background close policy changes.
    void keepRunningInBackgroundChanged();

    //!< @brief Emitted when tray availability changes.
    void trayAvailabilityChanged();

    //!< @brief Emitted when main window visibility changes.
    void mainWindowVisibilityChanged();

    /**
     * @brief Request that QML ask the user before closing active downloads.
     * @param hasActiveDownloads Whether active downloads triggered the block.
     */
    void closeBlocked(bool hasActiveDownloads);

    //!< @brief Emitted when the user clicks a platform notification.
    void notificationClicked();

private:
    //!< @brief Create tray actions and menu.
    void setupTray();

    //!< @brief Refresh tray action labels.
    void updateTrayActions();

    //!< @brief Invoke a no-argument method on DownloadManager.
    void invokeDownloadManager(const char* method);

    QPointer<QObject> m_downloadManager;              //!< Download manager context object.
    QPointer<QWindow> m_mainWindow;                   //!< Main QML window.
    QSystemTrayIcon* m_trayIcon = nullptr;            //!< Owned tray icon.
    QMenu* m_trayMenu = nullptr;                      //!< Owned tray context menu.
    QAction* m_showHideAction = nullptr;              //!< Show/hide action.
    QAction* m_startAllAction = nullptr;              //!< Resume all action.
    QAction* m_pauseAllAction = nullptr;              //!< Pause all action.
    QAction* m_exitAction = nullptr;                  //!< Explicit exit action.
    bool m_keepRunningInBackground = true;            //!< Close-to-background policy.
    bool m_explicitQuitRequested = false;             //!< Explicit quit guard.
};

#include "appcontroller.moc"
