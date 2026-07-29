/*!
    \file        AppMenuItem.qml
    \brief       Implements the AppMenuItem QML component for GENYDL.
    \details     This file contains the AppMenuItem user interface component used by the GENYDL desktop application.

    \author      Kambiz Asadzadeh <https://github.com/thecompez>
    \copyright   Copyright (c) 2026 Genyleap. All rights reserved.
    \license     https://github.com/genyleap/genydl/blob/main/LICENSE.md
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import GenyDL

MenuItem {
    id: control

    property string iconGlyph: ""

    implicitWidth: Math.max(220, rowContent.implicitWidth + leftPadding + rightPadding)
    implicitHeight: 42
    padding: Metrics.padding
    contentItem: RowLayout {
        id: rowContent
        spacing: Metrics.padding

        Text {
            Layout.preferredWidth: 22
            Layout.fillHeight: true
            visible: control.iconGlyph.length > 0
            text: control.iconGlyph
            font.family: FontSystem.getAwesomeSolid.name
            font.weight: Font.Black
            font.pixelSize: Typography.t2
            color: control.enabled ? Colors.textSecondary : Colors.textMuted
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            Layout.fillWidth: true
            Layout.fillHeight: true
            LayoutMirroring.enabled: false
            text: control.text
            font.pixelSize: Typography.t2
            color: control.enabled ? Colors.textPrimary : Colors.textMuted
            horizontalAlignment: AppGlobals.rtl ? Text.AlignRight : Text.AlignLeft
            verticalAlignment: Text.AlignVCenter
        }

        Item {
            Layout.preferredWidth: control.subMenu ? 24 : 0
            Layout.fillHeight: true
        }
    }

    arrow: Text {
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: AppGlobals.rtl ? undefined : parent.right
        anchors.left: AppGlobals.rtl ? parent.left : undefined
        anchors.margins: Metrics.padding
        width: 24
        height: parent.height
        visible: !!control.subMenu
        font.bold: false
        text: AppGlobals.rtl ? "\u2039" : "\u203A"
        font.pixelSize: Typography.h2
        color: control.enabled ? Colors.textSecondary : Colors.textMuted
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
    }

    background: Rectangle {
        radius: Metrics.innerRadius
        border.width: control.enabled ? 1 : 0
        border.color: Colors.borderHovered
        color: control.highlighted ? Colors.backgroundItemHovered : "transparent"
        opacity: (control.hovered || control.highlighted) ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    }
}
