/*!
    \file        Theme.qml
    \brief       Provides the Theme core QML definition for TONDAR.
    \details     This file contains shared Theme values and behavior used across the TONDAR QML user interface.

    \author      Kambiz Asadzadeh <https://github.com/thecompez>
    \copyright   Copyright (c) 2026 Genyleap. All rights reserved.
    \license     https://github.com/genyleap/tondar/blob/main/LICENSE.md
*/

pragma Singleton
import QtQuick

QtObject {
    enum Mode { Light, Dark }
    property int mode: Theme.Dark
}
