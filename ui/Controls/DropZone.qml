/*!
    \file        DropZone.qml
    \brief       Reusable drag-and-drop target for adding downloads.
    \details     A dashed drop card that accepts dropped links/files and also
                 works as a click target. Used both as the Home empty-state and
                 as the persistent zone pinned at the bottom of the sidebar.

    \author      Kambiz Asadzadeh <https://github.com/thecompez>
    \copyright   Copyright (c) 2026 Genyleap. All rights reserved.
    \license     https://github.com/genyleap/genydl/blob/main/LICENSE.md
*/

import QtQuick
import QtQuick.Layouts

import GenyDL // Colors, Metrics, Typography, FontSystem

Item {
    id: root

    // Compact = sidebar variant; otherwise the larger empty-state variant.
    property bool compact: false
    property string title: "Drop link or file"
    property string subtitle: "or click to add manually"
    property string iconGlyph: "" // link
    property string activeTitle: "Drop to add"

    signal clicked()
    signal dropped(string text)

    // Internal interaction states.
    property bool _hover: false
    property bool _drag: false

    implicitWidth: 200
    implicitHeight: compact ? 92 : 188

    Rectangle {
        id: surface
        anchors.fill: parent
        radius: Metrics.innerRadius
        color: root._drag ? Colors.backgroundItemFocused
             : root._hover ? Colors.backgroundItemHovered
             : Colors.backgroundItemDeactivated

        Behavior on color { ColorAnimation { duration: 160; easing.type: Easing.OutCubic } }

        // Dashed rounded border (QML Rectangle has no native dashed stroke).
        Canvas {
            id: dashed
            anchors.fill: parent
            property color stroke: root._drag ? Colors.secondry : Colors.lineBorderActivated
            property real lw: root._drag ? 2 : 1.5
            onStrokeChanged: requestPaint()
            onLwChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                ctx.strokeStyle = dashed.stroke
                ctx.lineWidth = dashed.lw
                ctx.setLineDash([6, 5])
                const r = Metrics.innerRadius
                const x = dashed.lw, y = dashed.lw
                const w = width - dashed.lw * 2, h = height - dashed.lw * 2
                ctx.beginPath()
                ctx.moveTo(x + r, y)
                ctx.arcTo(x + w, y, x + w, y + h, r)
                ctx.arcTo(x + w, y + h, x, y + h, r)
                ctx.arcTo(x, y + h, x, y, r)
                ctx.arcTo(x, y, x + w, y, r)
                ctx.closePath()
                ctx.stroke()
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - 28
            spacing: root.compact ? 4 : 10

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.iconGlyph
                font.family: FontSystem.getAwesomeSolid.name
                font.weight: Font.Black
                font.pixelSize: root.compact ? 20 : 30
                color: root._drag ? Colors.secondry : Colors.textSecondary
                Behavior on color { ColorAnimation { duration: 160 } }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root._drag ? root.activeTitle : root.title
                font.family: FontSystem.getContentFontSemiBold.name
                font.pixelSize: root.compact ? Typography.t2 : Typography.t1
                color: Colors.textPrimary
                elide: Text.ElideRight
            }

            Text {
                visible: root.subtitle.length > 0 && !root._drag
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.subtitle
                font.family: FontSystem.getContentFontRegular.name
                font.pixelSize: Typography.t3
                color: Colors.textMuted
                wrapMode: Text.WordWrap
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: root._hover = true
            onExited: root._hover = false
            onClicked: root.clicked()
        }

        DropArea {
            anchors.fill: parent
            onEntered: root._drag = true
            onExited: root._drag = false
            onDropped: (drop) => {
                root._drag = false
                let t = ""
                if (drop.hasUrls && drop.urls.length > 0)
                    t = drop.urls[0].toString()
                else if (drop.hasText)
                    t = drop.text
                root.dropped((t || "").trim())
            }
        }
    }
}
