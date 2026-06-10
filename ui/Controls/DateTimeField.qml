/*!
    \file        DateTimeField.qml
    \brief       Date + time input with a popup calendar for GENYDL.
    \details     A read-only display field with a calendar button that opens a
                 month grid and time spinners. Exposes the chosen value as an
                 ISO-8601 string via isoValue / edited(iso).

    \author      Kambiz Asadzadeh <https://github.com/thecompez>
    \copyright   Copyright (c) 2026 Genyleap. All rights reserved.
    \license     https://github.com/genyleap/genydl/blob/main/LICENSE.md
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import GenyDL
import "." as Controls

Item {
    id: root

    // ISO-8601 datetime (local), e.g. "2026-06-07T18:30:00". Empty == unset.
    property string isoValue: ""
    property string placeholder: "Not set"
    signal edited(string iso)

    // Internal working value + the month currently shown in the popup.
    property date _value: isoValue.length > 0 && !isNaN(Date.parse(isoValue))
                          ? new Date(isoValue) : new Date()
    property int _viewYear: _value.getFullYear()
    property int _viewMonth: _value.getMonth()   // 0-11

    implicitWidth: 230
    implicitHeight: 40

    function _emit(d) {
        root._value = d
        root.isoValue = Qt.formatDateTime(d, "yyyy-MM-ddThh:mm:ss")
        root.edited(root.isoValue)
    }
    function _displayText() {
        return isoValue.length > 0 ? Qt.formatDateTime(root._value, "yyyy-MM-dd  hh:mm")
                                   : placeholder
    }
    readonly property var _monthNames: ["January","February","March","April","May","June",
                                        "July","August","September","October","November","December"]

    RowLayout {
        anchors.fill: parent
        spacing: 6

        Controls.TextField {
            Layout.fillWidth: true
            readOnly: true
            text: root._displayText()
            color: root.isoValue.length > 0 ? Colors.textPrimary : Colors.textMuted
        }

        // Calendar trigger (Font Awesome Solid glyph rendered directly, since the
        // Button control uses the content font and would show tofu for FA glyphs).
        Rectangle {
            Layout.preferredWidth: 44
            Layout.fillHeight: true
            radius: Metrics.innerRadius
            color: triggerHover.hovered ? Colors.secondryBack : Colors.backgroundItemActivated
            border.width: 1
            border.color: triggerHover.hovered ? Colors.secondry : Colors.borderActivated
            Behavior on color { ColorAnimation { duration: Animations.fast } }
            Text {
                anchors.centerIn: parent
                text: String.fromCharCode(0xf133)   // calendar
                font.family: FontSystem.getAwesomeSolid.name
                font.weight: Font.Black
                font.pixelSize: 14
                color: Colors.textAccent
            }
            HoverHandler { id: triggerHover; cursorShape: Qt.PointingHandCursor }
            TapHandler {
                onTapped: {
                    root._viewYear = root._value.getFullYear()
                    root._viewMonth = root._value.getMonth()
                    calendarPopup.open()
                }
            }
        }
    }

    Popup {
        id: calendarPopup
        width: 360
        height: contentColumn.implicitHeight + 24
        padding: 12
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        parent: Overlay.overlay
        anchors.centerIn: Overlay.overlay

        background: Rectangle {
            color: Colors.backgroundActivated
            radius: Metrics.innerRadius
            border.width: 1
            border.color: Colors.borderActivated
        }

        ColumnLayout {
            id: contentColumn
            anchors.fill: parent
            spacing: 10

            // Month navigation.
            RowLayout {
                Layout.fillWidth: true
                Controls.Button {
                    sizeType: "small"
                    implicitWidth: 36
                    text: "‹"   // ‹
                    isBold: true
                    onClicked: {
                        if (root._viewMonth === 0) { root._viewMonth = 11; root._viewYear-- }
                        else root._viewMonth--
                    }
                }
                Controls.Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: root._monthNames[root._viewMonth] + " " + root._viewYear
                    font.bold: true
                }
                Controls.Button {
                    sizeType: "small"
                    implicitWidth: 36
                    text: "›"   // ›
                    isBold: true
                    onClicked: {
                        if (root._viewMonth === 11) { root._viewMonth = 0; root._viewYear++ }
                        else root._viewMonth++
                    }
                }
            }

            // Day-of-week header.
            GridLayout {
                Layout.fillWidth: true
                columns: 7
                columnSpacing: 2
                rowSpacing: 2
                Repeater {
                    model: ["S","M","T","W","T","F","S"]
                    delegate: Controls.Label {
                        required property var modelData
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        color: Colors.textMuted
                        font.pixelSize: Typography.t3
                    }
                }
            }

            // 6x7 day grid.
            GridLayout {
                Layout.fillWidth: true
                columns: 7
                columnSpacing: 2
                rowSpacing: 2

                Repeater {
                    // 42 cells; offset by the weekday of the 1st of the month.
                    model: 42
                    delegate: Rectangle {
                        required property int index
                        readonly property int firstDow: new Date(root._viewYear, root._viewMonth, 1).getDay()
                        readonly property int daysInMonth: new Date(root._viewYear, root._viewMonth + 1, 0).getDate()
                        readonly property int dayNum: index - firstDow + 1
                        readonly property bool inMonth: dayNum >= 1 && dayNum <= daysInMonth
                        readonly property bool isSelected: inMonth
                            && root.isoValue.length > 0
                            && root._value.getFullYear() === root._viewYear
                            && root._value.getMonth() === root._viewMonth
                            && root._value.getDate() === dayNum

                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        radius: Metrics.innerRadius
                        color: isSelected ? Colors.secondry
                                          : (cellHover.hovered && inMonth ? Colors.backgroundItemHovered
                                                                          : "transparent")

                        Controls.Label {
                            anchors.centerIn: parent
                            visible: parent.inMonth
                            text: parent.inMonth ? String(parent.dayNum) : ""
                            color: parent.isSelected ? Colors.staticPrimary : Colors.textPrimary
                            font.pixelSize: Typography.t3
                        }
                        HoverHandler { id: cellHover; enabled: parent.inMonth }
                        TapHandler {
                            enabled: parent.inMonth
                            onTapped: {
                                var d = new Date(root._value)
                                d.setFullYear(root._viewYear, root._viewMonth, dayNum)
                                root._emit(d)
                            }
                        }
                    }
                }
            }

            // Time row. Zero-padded hour:minute spinners with steppers.
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Controls.Label { text: "Time" }
                Item { Layout.fillWidth: true }
                Controls.SpinBox {
                    id: hourSpin
                    Layout.preferredWidth: 130
                    from: 0; to: 23
                    value: root._value.getHours()
                    textFromValue: function(v, locale) { return ("0" + v).slice(-2) }
                    valueFromText: function(text, locale) { return parseInt(text, 10) || 0 }
                    onValueModified: {
                        var d = new Date(root._value); d.setHours(value); root._emit(d)
                    }
                }
                Controls.Label { text: ":"; font.bold: true }
                Controls.SpinBox {
                    id: minuteSpin
                    Layout.preferredWidth: 130
                    from: 0; to: 59
                    value: root._value.getMinutes()
                    textFromValue: function(v, locale) { return ("0" + v).slice(-2) }
                    valueFromText: function(text, locale) { return parseInt(text, 10) || 0 }
                    onValueModified: {
                        var d = new Date(root._value); d.setMinutes(value); root._emit(d)
                    }
                }
            }

            // Footer actions.
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Controls.Button {
                    sizeType: "small"
                    text: "Now"
                    onClicked: { root._emit(new Date()); root._viewYear = root._value.getFullYear(); root._viewMonth = root._value.getMonth() }
                }
                Controls.Button {
                    sizeType: "small"
                    text: "Clear"
                    onClicked: { root.isoValue = ""; root.edited(""); calendarPopup.close() }
                }
                Item { Layout.fillWidth: true }
                Controls.Button {
                    sizeType: "small"
                    text: "Done"
                    isDefault: true
                    onClicked: calendarPopup.close()
                }
            }
        }
    }
}
