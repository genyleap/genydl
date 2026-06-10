/*!
    \file        ToolTip.qml
    \brief       Themed tooltip for GENYDL.
    \details     A polished replacement for the default Qt tooltip: rounded,
                 elevated surface with an arrow, a fade+scale animation and a
                 built-in show delay. Bind `active` to a hover state and set
                 `text`; it positions itself below (or above) the parent.

    \author      Kambiz Asadzadeh <https://github.com/thecompez>
    \copyright   Copyright (c) 2026 Genyleap. All rights reserved.
    \license     https://github.com/genyleap/genydl/blob/main/LICENSE.md
*/

import QtQuick
import QtQuick.Templates as T

import GenyDL

T.ToolTip {
    id: control

    // Bind this to a hover state (e.g. a HoverHandler's `hovered`). The tooltip
    // appears after `showDelay` ms and hides immediately when it goes false.
    property bool active: false
    property int showDelay: 350
    // Place the tooltip above the parent instead of below.
    property bool above: false

    // Horizontally centered on the parent, just outside one edge.
    x: parent ? Math.round((parent.width - width) / 2) : 0
    y: parent ? (above ? -height - 8 : parent.height + 8) : 0

    padding: 0
    leftPadding: 12
    rightPadding: 12
    topPadding: 7
    bottomPadding: 7

    // Cap the width so long hints wrap instead of stretching across the window.
    // Measure the unwrapped text with TextMetrics rather than implicitContentWidth
    // — the latter would form a binding loop with the wrapping content item and
    // collapse the popup to zero size.
    TextMetrics {
        id: textMetrics
        font.family: FontSystem.getContentFont.name
        font.pixelSize: Typography.t3
        font.weight: Font.Medium
        text: control.text
    }
    readonly property int _maxWidth: 300
    // +6 buffer absorbs sub-pixel / font-loading measurement differences so the
    // label never truncates.
    readonly property int _fullWidth: Math.ceil(textMetrics.width) + leftPadding + rightPadding + 6
    // Number of wrapped lines once capped at _maxWidth.
    readonly property int _lineCount: Math.max(1, Math.ceil(_fullWidth / _maxWidth))
    // Drive BOTH dimensions from the measurement so the panel never collapses to
    // a zero-size content item (which would leave only the arrow visible).
    implicitWidth: Math.min(_fullWidth, _maxWidth)
    implicitHeight: Math.ceil(textMetrics.height) * _lineCount + topPadding + bottomPadding
    closePolicy: T.Popup.NoAutoClose

    onActiveChanged: {
        if (active) showTimer.restart()
        else { showTimer.stop(); control.visible = false }
    }
    Timer {
        id: showTimer
        interval: control.showDelay
        onTriggered: if (control.active) control.visible = true
    }

    contentItem: Text {
        text: control.text
        font.family: FontSystem.getContentFont.name
        font.pixelSize: Typography.t3
        font.weight: Font.Medium
        color: Colors.textPrimary
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    // The panel is the background directly (so the control sizes it); the arrow
    // is a child poking out one edge. Colors match the app's menus/popups so the
    // tooltip stays in sync with the active theme.
    background: Rectangle {
        radius: Metrics.innerRadius
        color: Colors.backgroundItemActivated
        border.width: 1
        border.color: Colors.borderActivated

        Shadow {}

        Rectangle {
            width: 11
            height: 11
            rotation: 45
            radius: 2
            color: Colors.backgroundItemActivated
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: control.above ? undefined : parent.top
            anchors.bottom: control.above ? parent.bottom : undefined
            anchors.topMargin: -5
            anchors.bottomMargin: -5
        }
    }

    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: Animations.fast; easing.type: Easing.OutCubic }
            NumberAnimation { property: "scale"; from: 0.9; to: 1.0; duration: Animations.normal; easing.type: Easing.OutBack }
        }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: Animations.superfast; easing.type: Easing.InCubic }
    }
}
