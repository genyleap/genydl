/*!
    \file        AppMenuTrigger.qml
    \brief       Implements the AppMenuTrigger QML component for GENYDL.
    \details     This file contains the AppMenuTrigger user interface component used by the GENYDL desktop application.

    \author      Kambiz Asadzadeh <https://github.com/thecompez>
    \copyright   Copyright (c) 2026 Genyleap. All rights reserved.
    \license     https://github.com/genyleap/genydl/blob/main/LICENSE.md
*/

import QtQuick

import GenyDL

Item {
    id: control

    property string text: ""
    property var menu: null
    property bool selected: false
    signal triggered()
    readonly property bool active: selected || mouseArea.containsMouse || (menu && menu.visible)

    readonly property bool hovering: mouseArea.containsMouse || (menu && menu.visible)

    implicitWidth: Math.max(54, titleLabel.implicitWidth + 22)
    implicitHeight: 34

    Rectangle {
        id: pill
        anchors.fill: parent
        radius: Metrics.innerRadius
        color: control.selected
               ? Colors.secondryBack
               : (control.hovering ? Colors.backgroundItemActivated : "transparent")
        border.width: 0

        Behavior on color { ColorAnimation { duration: Animations.normal; easing.type: Easing.OutCubic } }

        // Animated active indicator that slides in under the selected item.
        Rectangle {
            id: indicator
            height: 2.5
            radius: height
            color: Colors.secondry
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            anchors.horizontalCenter: parent.horizontalCenter
            width: control.selected ? Math.min(parent.width - 16, titleLabel.implicitWidth) : 0
            opacity: control.selected ? 1 : 0
            Behavior on width { NumberAnimation { duration: Animations.normal; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: Animations.fast } }
        }
    }

    Text {
        id: titleLabel
        anchors.centerIn: parent
        text: control.text
        font.family: FontSystem.getContentFont.name
        font.pixelSize: Typography.t2
        font.weight: control.selected ? Font.DemiBold : Font.Medium
        color: control.selected ? Colors.textPrimary
              : (control.active ? Colors.textPrimary : Colors.textSecondary)
        Behavior on color { ColorAnimation { duration: Animations.normal } }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (!control.menu) {
                control.triggered()
                return
            }
            control.menu.popup(control, 0, control.height + 6)
        }
    }
}
