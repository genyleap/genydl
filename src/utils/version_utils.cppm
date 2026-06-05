/*!
 * @file        version_utils.cppm
 * @brief       Version parsing and comparison helpers.
 * @details     Provides lightweight comparison for semantic-like version strings.
 *
 * @author      <a href='https://github.com/thecompez'>Kambiz Asadzadeh</a>
 * @since       09 Feb 2026
 * @copyright   Copyright (c) 2026 Genyleap. All rights reserved.
 * @license     https://github.com/genyleap/tondar/blob/main/LICENSE.md
 */

module;
#include <QString>

#ifndef Q_MOC_RUN
export module tondar.utils.version_utils;
#endif

#ifdef Q_MOC_RUN
#define TONDAR_MODULE_EXPORT
#else
#define TONDAR_MODULE_EXPORT export
#endif

TONDAR_MODULE_EXPORT namespace tondar::utils {

/**
 * @brief Compare two version strings.
 * @param a Left-hand version.
 * @param b Right-hand version.
 * @return -1 if a<b, 0 if equal, 1 if a>b.
 */
int compareVersions(const QString& a, const QString& b);

} // namespace tondar::utils
