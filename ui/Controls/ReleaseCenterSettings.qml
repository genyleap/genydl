/*!
    \file        ReleaseCenterSettings.qml
    \brief       Release Center update-behavior settings, as a reusable block.
    \details     Hosts the check-frequency, download policy, scope, date-format
                 and credentials controls. Used inside the Configuration drawer
                 (its own tab) so the Release Center page stays list-only.

    \author      Kambiz Asadzadeh <https://github.com/thecompez>
    \copyright   Copyright (c) 2026 Genyleap. All rights reserved.
    \license     https://github.com/genyleap/genydl/blob/main/LICENSE.md
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import GenyDL
import "." as Controls

Controls.GroupBox {
    id: root
    title: qsTr("Release Center")
    Layout.fillWidth: true
    implicitHeight: settingsCol.implicitHeight + topPadding + bottomPadding

    // Check-frequency presets. Index 0 ("Manual only") disables automatic checks.
    readonly property var intervalPresetLabels: [qsTr("Manual only"), qsTr("Every 6 hours"),
                                                 qsTr("Every 12 hours"), qsTr("Daily"), qsTr("Weekly")]
    readonly property var intervalPresetHours: [0, 6, 12, 24, 168]
    function currentIntervalPresetIndex() {
        if (!releaseCenterService.automaticChecksEnabled) return 0
        const idx = intervalPresetHours.indexOf(releaseCenterService.checkIntervalHours)
        return idx > 0 ? idx : 3
    }
    function applyIntervalPreset(i) {
        if (i <= 0) { releaseCenterService.automaticChecksEnabled = false; return }
        releaseCenterService.checkIntervalHours = intervalPresetHours[i]
        releaseCenterService.automaticChecksEnabled = true
    }
    readonly property bool frequentInterval: releaseCenterService.automaticChecksEnabled
                                             && releaseCenterService.checkIntervalHours <= 6

    readonly property var downloadPolicyModes: ["notify", "ask", "auto"]
    readonly property var downloadPolicyLabels: [qsTr("Notify only"),
                                                 qsTr("Ask before downloading"),
                                                 qsTr("Download automatically")]

    readonly property var dateFormatModes: ["relative", "datetime", "day", "month"]
    readonly property var dateFormatLabels: [qsTr("Relative (2 hours ago)"),
                                             qsTr("Full (2026-06-05 18:23)"),
                                             qsTr("Date (May 28, 2026)"),
                                             qsTr("Month (Jun 2025)")]

    ColumnLayout {
        id: settingsCol
        anchors.fill: parent
        spacing: 14

        // --- Update behaviour: drop-downs aligned in a label/control grid ---
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 16
            rowSpacing: 10

            Controls.Label {
                text: qsTr("Check for updates")
                Layout.alignment: Qt.AlignVCenter
            }
            Controls.ComboBox {
                Layout.preferredWidth: 230
                model: root.intervalPresetLabels
                currentIndex: root.currentIntervalPresetIndex()
                onActivated: root.applyIntervalPreset(currentIndex)
            }

            Controls.Label {
                text: qsTr("When found")
                Layout.alignment: Qt.AlignVCenter
            }
            Controls.ComboBox {
                Layout.preferredWidth: 230
                model: root.downloadPolicyLabels
                currentIndex: Math.max(0, root.downloadPolicyModes.indexOf(releaseCenterService.downloadPolicy))
                onActivated: releaseCenterService.downloadPolicy = root.downloadPolicyModes[currentIndex]
            }

            Controls.Label {
                text: qsTr("Date format")
                Layout.alignment: Qt.AlignVCenter
            }
            Controls.ComboBox {
                Layout.preferredWidth: 230
                model: root.dateFormatLabels
                currentIndex: Math.max(0, root.dateFormatModes.indexOf(releaseCenterService.dateFormat))
                onActivated: releaseCenterService.dateFormat = root.dateFormatModes[currentIndex]
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Colors.borderActivated
            opacity: 0.6
        }

        // --- Toggles: tidy two-column grid so rows line up ---
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 28
            rowSpacing: 12

            Controls.Switch {
                text: qsTr("Notifications")
                checked: releaseCenterService.showNotifications
                onToggled: releaseCenterService.showNotifications = checked
            }
            Controls.Switch {
                text: qsTr("Default prereleases")
                checked: releaseCenterService.defaultIncludePrereleases
                onToggled: releaseCenterService.defaultIncludePrereleases = checked
            }
            Controls.Switch {
                text: qsTr("Only when window is open")
                checked: releaseCenterService.onlyWhenOpen
                onToggled: releaseCenterService.onlyWhenOpen = checked
            }
            Controls.Switch {
                text: qsTr("Check in background (tray)")
                enabled: !releaseCenterService.onlyWhenOpen
                checked: releaseCenterService.backgroundChecks
                onToggled: releaseCenterService.backgroundChecks = checked
            }
            Controls.Switch {
                text: qsTr("Wi-Fi / non-metered only")
                checked: releaseCenterService.wifiOnly
                onToggled: releaseCenterService.wifiOnly = checked
            }
        }

        // Extra caution when the interval is aggressive.
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: root.frequentInterval
            Text {
                text: String.fromCharCode(0xf06a)   // circle-exclamation
                font.family: FontSystem.getAwesomeSolid.name
                font.weight: Font.Black
                font.pixelSize: 12
                color: Colors.warning
            }
            Controls.Label {
                Layout.fillWidth: true
                text: qsTr("Frequent checks contact GitHub often and can hit API rate limits. Consider adding a GitHub token below, or a longer interval.")
                color: Colors.warning
                wrapMode: Text.WordWrap
                font.pixelSize: Typography.t3
            }
        }

        // Network-traffic disclosure shown whenever automatic checks are on.
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: releaseCenterService.automaticChecksEnabled
            Text {
                text: String.fromCharCode(0xf071)   // triangle-exclamation
                font.family: FontSystem.getAwesomeSolid.name
                font.weight: Font.Black
                font.pixelSize: 12
                color: Colors.warning
            }
            Controls.Label {
                Layout.fillWidth: true
                text: qsTr("Automatic update checks periodically use network traffic to contact GitHub and check saved repositories for new releases. Frequent intervals increase traffic and may hit GitHub API limits.")
                color: Colors.textSecondary
                wrapMode: Text.WordWrap
                font.pixelSize: Typography.t3
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Colors.borderActivated
            opacity: 0.6
        }

        // --- Credentials: each field on its own full-width row ---
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 16
            rowSpacing: 10

            Controls.Label {
                text: qsTr("User-Agent")
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 96
            }
            Controls.TextField {
                Layout.fillWidth: true
                readOnly: true
                text: releaseCenterService.userAgent
                color: Colors.textMuted
            }

            Controls.Label {
                text: qsTr("GitHub token")
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 96
            }
            Controls.TextField {
                Layout.fillWidth: true
                placeholderText: qsTr("Optional — increases GitHub API rate limit")
                text: releaseCenterService.githubToken
                echoMode: TextInput.Password
                onEditingFinished: releaseCenterService.githubToken = text
            }
        }
    }
}
