/*!
    \file        MiniIconButton.qml
    \brief       Compact icon-only action button for dense control rows.
    \details     A lightweight alternative to the full Button component for small,
                 square actions (toggle, reorder, remove) where the pill-shaped
                 Button would be visually too heavy. Renders a single glyph in a
                 subtle rounded hit-area with hover and active states.

    \author      Kambiz Asadzadeh <https://github.com/thecompez>
    \copyright   Copyright (c) 2026 Genyleap. All rights reserved.
    \license     https://github.com/genyleap/genydl/blob/main/LICENSE.md
*/

import QtQuick
import GenyDL

Item {
    id: control

    property string glyph: ""
    property color glyphColor: Colors.textSecondary
    property color activeColor: Colors.textAccent
    property bool active: false
    property bool interactive: true
    property real glyphSize: 14

    signal activated()

    implicitWidth: 28
    implicitHeight: 28
    opacity: interactive ? 1.0 : 0.3

    Rectangle {
        anchors.fill: parent
        radius: 7
        color: hover.hovered && control.interactive
               ? Colors.backgroundItemHovered
               : (control.active ? Colors.backgroundItemActivated : "transparent")
        border.width: control.active ? 1 : 0
        border.color: Colors.borderActivated

        Behavior on color { ColorAnimation { duration: 90 } }
    }

    Text {
        anchors.centerIn: parent
        text: control.glyph
        font.pixelSize: control.glyphSize
        color: control.active ? control.activeColor : control.glyphColor
    }

    HoverHandler {
        id: hover
        enabled: control.interactive
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        enabled: control.interactive
        onTapped: control.activated()
    }
}
