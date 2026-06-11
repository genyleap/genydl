/*!
 * @file        tray_icon_provider.cppm
 * @brief       Platform-aware system tray / status-bar icon provider.
 * @details     Supplies the QIcon used by QSystemTrayIcon. On macOS a template
 *              (mask) icon is returned so the menu bar renders correctly for
 *              both light and dark appearances; other platforms use the colored
 *              tray icon.
 *
 * @author      <a href='https://github.com/thecompez'>Kambiz Asadzadeh</a>
 * @since       10 Jun 2026
 * @copyright   Copyright (c) 2026 Genyleap. All rights reserved.
 * @license     https://github.com/genyleap/genydl/blob/main/LICENSE.md
 */

module;
#include <QIcon>

#ifndef Q_MOC_RUN
export module genydl.ui.tray_icon_provider;
#endif

#ifdef Q_MOC_RUN
#define GENYDL_MODULE_EXPORT
#else
#define GENYDL_MODULE_EXPORT export
#endif

GENYDL_MODULE_EXPORT namespace genydl::ui {

/**
 * @brief Create the platform-aware tray icon.
 *
 * On macOS this returns a template mask icon (setIsMask(true)) so the system
 * can render the status-bar icon correctly for light and dark appearances.
 * On other platforms the colored tray icon is returned.
 *
 * @return Icon suitable for QSystemTrayIcon::setIcon().
 */
[[nodiscard]] QIcon createTrayIcon();

} // namespace genydl::ui
