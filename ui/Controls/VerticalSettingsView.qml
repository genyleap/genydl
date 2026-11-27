import QtQuick
import QtQuick.Controls

// A settings viewport must never pan horizontally, including with a touchpad.
Flickable {
    id: view

    clip: true
    contentWidth: width
    flickableDirection: Flickable.VerticalFlick
    boundsBehavior: Flickable.StopAtBounds
    boundsMovement: Flickable.StopAtBounds

    // Reserve the same gutter on both sides so the bar cannot cover controls
    // and the content remains centered in both LTR and RTL.
    readonly property real contentInset: verticalBar.implicitWidth
    readonly property real availableWidth: Math.max(0, width - 2 * contentInset)

    ScrollBar.vertical: ScrollBar {
        id: verticalBar
        policy: ScrollBar.AsNeeded
    }
}
