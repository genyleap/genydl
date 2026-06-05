/*!
    \file        Elevation.qml
    \brief       Provides the Elevation core QML definition for TONDAR.
    \details     This file contains shared Elevation values and behavior used across the TONDAR QML user interface.

    \author      Kambiz Asadzadeh <https://github.com/thecompez>
    \copyright   Copyright (c) 2026 Genyleap. All rights reserved.
    \license     https://github.com/genyleap/tondar/blob/main/LICENSE.md
*/

pragma Singleton
import QtQuick

QtObject {
    property int low: 4
    property int medium: 8
    property int high: 16

    property color shadowColor: "#40000000"
}
