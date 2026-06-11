/*!
    \file        Colors.qml
    \brief       Provides the Colors core QML definition for GENYDL.
    \details     This file contains shared Colors values and behavior used across the GENYDL QML user interface.

    \author      Kambiz Asadzadeh <https://github.com/thecompez>
    \copyright   Copyright (c) 2026 Genyleap. All rights reserved.
    \license     https://github.com/genyleap/genydl/blob/main/LICENSE.md
*/

pragma Singleton

import QtQuick
import QtQuick.Controls

QtObject {
    id: styleObject

    readonly property int radius : 15
    readonly property int modeSystem: 0
    readonly property int modeDark: 1
    readonly property int modeLight: 2

    readonly property bool systemLightMode: {
        if (!AppGlobals.appWindow)
            return true
        return Qt.darker(AppGlobals.appWindow.palette.window, 1.2) !== AppGlobals.appWindow.palette.window
    }

    property int mode: modeSystem

    property bool lightMode: mode === modeLight ? true
                                             : (mode === modeDark ? false : systemLightMode)

    // Accent and page colors
    readonly property color accent: lightMode ? "#ffffff" : "#1e1e1e"
    readonly property color pageground: lightMode ? "#ecedf2" : "#131317"

    readonly property color accentPrimary: lightMode ? "#1b1b1b" : "#ffffff"
    readonly property color accentSecondry: lightMode ? "#ffffff" : "#1b1b1b"

    // ----------------------------------------------------------------------------
    // Surfaces / panels (rows, toolbars, cards)
    // ----------------------------------------------------------------------------
    readonly property color pagespaceActivated: lightMode ? "#f7f7fa" : "#161619"
    readonly property color pagespacePressed:   lightMode ? "#E9EEF6" : "#121215"
    readonly property color pagespaceHovered:   lightMode ? "#F1F2FA" : "#1a1a1f"

    readonly property color logoStyle: lightMode ? "#000000" : "#FFFFFF"
    readonly property color logoSideStyle: lightMode ? "#FFFFFF" : "#000000"

    // Text colors
    readonly property color textPrimary: lightMode ? "#272727" : "#ffffff"
    readonly property color textSecondary: lightMode ? "#555555" : "#cccccc"
    readonly property color textMuted: lightMode ? "#888888" : "#888888"
    readonly property color textAccent: lightMode ? "#6d4aee" : "#9b82ff"
    readonly property color textSuccess: lightMode ? "#0cce6b" : "#0c9944"
    readonly property color textWarning: lightMode ? "#ee7e0a" : "#cc6600"
    readonly property color textError: lightMode ? "#cc3333" : "#ff6666"

    // Static colors
    readonly property color staticPrimary: "#ffffff"
    readonly property color staticSecondry: "#000000"

    readonly property color sideBar: lightMode ? "#1b1b1b" : "#ffffff"
    readonly property color sideBarContainer: lightMode ? "#f6f6f9" : "#101014"
    readonly property color sideBarItem: lightMode ? "#6f6f6f" : "#e4e4e4"

    readonly property color gradientPrimary: lightMode ? "#ffffff" : "#1b1b1b"
    readonly property color gradientSecondry: lightMode ? "#e4e4e4" : "#555555"

    // Backgrounds
    readonly property color background: lightMode ? "#ffffff" : "#151519"
    readonly property color backgroundActivated: lightMode ? "#ffffff" : "#1e1e24"
    readonly property color backgroundDeactivated: lightMode ? "#E5E5E5" : "#2a2a31"
    readonly property color backgroundHovered: lightMode ? "#dcdcdc" : "#33333b"
    readonly property color backgroundFocused: lightMode ? "#fafafa" : "#222228"

    // Background items
    readonly property color backgroundItemActivated: lightMode ? "#F1F1F1" : "#1a1a1f"
    readonly property color backgroundItemDeactivated: lightMode ? "#F1F1F1" : "#2a2a31"
    readonly property color backgroundItemHovered: lightMode ? "#f7f7fa" : "#202025"
    readonly property color backgroundItemFocused: lightMode ? "#f2f2f2" : "#2c2c33"

    // Foregrounds
    readonly property color foregroundActivated: lightMode ? "#ffffff" : "#eeeeee"
    readonly property color foregroundDeactivated: lightMode ? "#9097a6" : "#888888"
    readonly property color foregroundHovered: lightMode ? "#767676" : "#bbbbbb"
    readonly property color foregroundFocused: lightMode ? "#ffffff" : "#ffffff"

    // Borders
    readonly property color borderActivated: lightMode ? "#dcdce3" : "#2e2e36"
    readonly property color borderDeactivated: lightMode ? "#D9D9DB" : "#3a3a43"
    readonly property color borderHovered: lightMode ? "#F1F1F1" : "#28282e"
    readonly property color borderFocused: lightMode ? "#50535a" : "#9b82ff"

    // Lines
    readonly property color lineBorderActivated: lightMode ? "#dcdce3" : "#2a2a32"
    readonly property color lineBorderDeactivated: lightMode ? "#f1f1f1" : "#242428"
    readonly property color lineBorderHovered: lightMode ? "#f1f1f1" : "#36363e"
    readonly property color lineBorderFocused: lightMode ? "#f1f1f1" : "#777777"

    readonly property color liquidGlassActivated: lightMode ? "#99ffffff" : "#991d1d1d"

    // Header and footer
    readonly property color header: lightMode ? "#e7e5f2" : "#18181e"
    readonly property color footer: lightMode ? "#0e121b" : "#0d0d11"

    // Status colors
    readonly property color primary: lightMode ? "#6e707b" : "#a0a0a0"
    readonly property color primaryBack: lightMode ? "#306e707b" : "#30a0a0a0"
    readonly property color secondry: lightMode ? "#6d4aee" : "#7c5cf0"
    readonly property color secondryBack: lightMode ? "#306d4aee" : "#307c5cf0"
    readonly property color success: lightMode ? "#50b761" : "#50b761"
    readonly property color successBack: lightMode ? "#3050b761" : "#3050b761"
    readonly property color warning: lightMode ? "#b89250" : "#b89250"
    readonly property color warningBack: lightMode ? "#30b89250" : "#30b89250"
    readonly property color error: lightMode ? "#b85050" : "#b85050"
    readonly property color errorBack: lightMode ? "#30b85050" : "#30b85050"
    readonly property color star: lightMode ? "#e3a008" : "#f5b50a"
    readonly property color starBack: lightMode ? "#30e3a008" : "#30f5b50a"

    // Shadows
    readonly property color lightShadow: lightMode ? "#28555555" : "#66000000"
    readonly property color darkShadow: lightMode ? "#66000000" : "#28555555"

    //55ffffff

    // Misc
    readonly property bool shadow: true
}
