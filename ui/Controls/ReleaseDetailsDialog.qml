/*!
    \file        ReleaseDetailsDialog.qml
    \brief       App-detail dialog for a tracked GitHub release app.
    \details     Shows the repository identity, stats, version state and the
                 latest release notes (changelog), with quick actions — an
                 App-Store-style detail page for the Release Center.

    \author      Kambiz Asadzadeh <https://github.com/thecompez>
    \copyright   Copyright (c) 2026 Genyleap. All rights reserved.
    \license     https://github.com/genyleap/genydl/blob/main/LICENSE.md
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

import GenyDL
import "." as Controls
import "../utils.js" as Utils

Controls.Dialog {
    id: details

    property var app: ({})
    // Release date display format, bound from the app root.
    property string dateFormat: "datetime"

    signal checkNow(int rowIndex)
    signal downloadAssets(var app)
    signal updateApp(var app)
    signal openUrl(string url)

    title: "App Details"
    type: "info"
    standardButtons: Dialog.NoButton
    width: Math.min(appRoot.width - 40, 820)
    // Size to content (capped to the screen) so short detail pages don't leave a
    // large empty area at the bottom.
    height: Math.min(appRoot.height - 40, implicitHeight)
    modal: true
    focus: true

    function val(key) {
        return details.app && details.app[key] !== undefined ? details.app[key] : ""
    }
    function str(key) { return String(val(key) || "") }

    function releasesUrl() {
        const repo = str("repository").length > 1 ? str("repository")
                   : (str("owner") + "/" + str("repo"))
        return repo.length > 1 ? ("https://github.com/" + repo + "/releases") : ""
    }

    function formatCount(value) {
        var n = Number(value || 0)
        if (n >= 1000000) return (n / 1000000).toFixed(n >= 10000000 ? 0 : 1) + "M"
        if (n >= 1000) return (n / 1000).toFixed(n >= 10000 ? 0 : 1) + "K"
        return String(n)
    }

    function statusColor(s) {
        if (s === "update_available") return Colors.secondry
        if (s === "downloaded") return Colors.star
        if (s === "check_failed") return Colors.error
        if (s === "never_checked") return Colors.warning
        if (s === "up_to_date") return Colors.success
        if (s === "not_installed") return Colors.primary
        return Colors.textSecondary
    }
    function statusBack(s) {
        if (s === "update_available") return Colors.secondryBack
        if (s === "downloaded") return Colors.starBack
        if (s === "check_failed") return Colors.errorBack
        if (s === "never_checked") return Colors.warningBack
        if (s === "up_to_date") return Colors.successBack
        if (s === "not_installed") return Colors.primaryBack
        return Colors.backgroundItemHovered
    }

    component StatChip: Rectangle {
        property string glyph: ""
        property color glyphColor: Colors.textSecondary
        property string label: ""
        implicitWidth: chipRow.implicitWidth + 20
        implicitHeight: 28
        radius: Metrics.innerRadius
        color: Colors.pagespaceActivated
        border.width: 1
        border.color: Colors.borderActivated
        RowLayout {
            id: chipRow
            anchors.centerIn: parent
            spacing: 6
            Text {
                text: glyph
                visible: glyph.length > 0
                font.family: FontSystem.getAwesomeSolid.name
                font.weight: Font.Black
                font.pixelSize: 12
                color: glyphColor
            }
            Controls.Label { text: label; color: Colors.textPrimary; font.pixelSize: Typography.t3 }
        }
    }

    component InfoCell: ColumnLayout {
        property string label: ""
        property string value: ""
        spacing: 2
        Controls.Label { text: label; color: Colors.textMuted; font.pixelSize: Typography.t3 }
        Controls.Label {
            text: value && value.length > 0 ? value : "--"
            color: Colors.textPrimary
            font.pixelSize: Typography.t2
            font.bold: true
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 14

        // ---- Identity header ----
        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            Item {
                Layout.preferredWidth: 64
                Layout.preferredHeight: 64
                Layout.alignment: Qt.AlignTop

                Rectangle {
                    id: avatarFrame
                    anchors.fill: parent
                    radius: width * 0.26
                    border.width: 1
                    border.color: Colors.borderActivated
                    clip: true
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Colors.backgroundItemHovered }
                        GradientStop { position: 1.0; color: Colors.pagespaceActivated }
                    }
                    Controls.Label {
                        anchors.centerIn: parent
                        visible: logo.status !== Image.Ready
                        text: {
                            const o = details.str("owner")
                            return o.length > 0 ? o.charAt(0).toUpperCase() : "?"
                        }
                        font.pixelSize: 26
                        font.bold: true
                        color: Colors.textSecondary
                    }
                    Image {
                        id: logo
                        anchors.fill: parent
                        source: details.str("avatarUrl")
                        fillMode: Image.PreserveAspectFit
                        smooth: true; mipmap: true; cache: true; asynchronous: true
                        sourceSize.width: 128; sourceSize.height: 128
                        visible: false
                    }
                    Rectangle { id: logoMask; anchors.fill: parent; radius: avatarFrame.radius; visible: false; layer.enabled: true }
                    MultiEffect {
                        anchors.fill: parent
                        source: logo
                        maskEnabled: true
                        maskSource: logoMask
                        visible: logo.status === Image.Ready
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Controls.Label {
                        Layout.fillWidth: true
                        text: details.str("displayName").length > 0 ? details.str("displayName") : details.str("repo")
                        font.family: FontSystem.getContentFontBold.name
                        font.pixelSize: Typography.h3
                        font.weight: Font.Bold
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    Rectangle {
                        Layout.preferredWidth: badgeRow.implicitWidth + 22
                        Layout.preferredHeight: 28
                        radius: Metrics.innerRadius
                        color: details.statusBack(details.str("status"))
                        border.width: 1
                        border.color: details.statusColor(details.str("status"))
                        RowLayout {
                            id: badgeRow
                            anchors.centerIn: parent
                            spacing: 6
                            Controls.Label {
                                text: details.str("statusText")
                                color: details.statusColor(details.str("status"))
                                font.pixelSize: Typography.t3
                                font.bold: true
                            }
                        }
                    }
                }
                Controls.Label {
                    Layout.fillWidth: true
                    text: details.str("owner") + " / " + details.str("repo")
                    color: Colors.textSecondary
                    elide: Text.ElideRight
                }

                // Stat chips
                Flow {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    spacing: 8
                    StatChip { glyph: String.fromCharCode(0xf005); glyphColor: Colors.star; label: details.formatCount(details.val("stars")) }
                    StatChip { glyph: String.fromCharCode(0xf126); glyphColor: Colors.secondry; label: details.formatCount(details.val("forks")) }
                    StatChip { visible: details.str("language").length > 0; glyph: String.fromCharCode(0xf121); label: details.str("language") }
                    StatChip { visible: details.str("licenseSpdxId").length > 0; glyph: String.fromCharCode(0xf24e); label: details.str("licenseSpdxId") }
                }
            }
        }

        // ---- Description ----
        Controls.Label {
            Layout.fillWidth: true
            visible: details.str("description").length > 0
            text: details.str("description")
            color: Colors.textSecondary
            wrapMode: Text.WordWrap
        }

        // ---- Version info ----
        Controls.GroupBox {
            Layout.fillWidth: true
            Layout.preferredHeight: versionGrid.implicitHeight + topPadding + bottomPadding
            title: "Versions"
            GridLayout {
                id: versionGrid
                anchors.fill: parent
                columns: 4
                columnSpacing: 18
                rowSpacing: 8
                InfoCell {
                    Layout.fillWidth: true
                    label: details.str("installSource") === "os" ? "Installed" : "Local"
                    value: {
                        if (details.str("installedVersion").length > 0)
                            return details.str("installedVersion")
                                   + (details.str("installSource") === "download" ? " (downloaded)" : "")
                        if (details.str("status") === "downloaded") return "Downloaded — ready to install"
                        return "Not installed"
                    }
                }
                InfoCell { Layout.fillWidth: true; label: "Latest"; value: details.str("latestTag") }
                InfoCell { Layout.fillWidth: true; label: "Released"; value: Utils.formatReleaseDate(details.val("latestPublishedAt"), details.dateFormat) }
                InfoCell { Layout.fillWidth: true; label: "Checked"; value: details.str("lastCheckedText") }
            }
        }

        // ---- Release notes / changelog ----
        Controls.Label {
            text: "Release notes" + (details.str("latestTag").length > 0 ? " — " + details.str("latestTag") : "")
            font.bold: true
            font.pixelSize: Typography.t1
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(Math.max(notes.implicitHeight + 24, 80), 280)
            radius: Metrics.innerRadius
            color: Colors.backgroundItemActivated
            border.width: 1
            border.color: Colors.borderActivated
            clip: true

            ScrollView {
                id: notesScroll
                anchors.fill: parent
                anchors.margins: 12
                clip: true
                contentWidth: availableWidth
                Controls.Label {
                    id: notes
                    width: notesScroll.availableWidth
                    text: details.str("latestBody").length > 0 ? details.str("latestBody")
                          : "No release notes were published for this release."
                    color: details.str("latestBody").length > 0 ? Colors.textPrimary : Colors.textMuted
                    textFormat: Text.MarkdownText
                    wrapMode: Text.WordWrap
                    elide: Text.ElideNone
                    onLinkActivated: function(link) { details.openUrl(link) }
                }
            }
        }

        // ---- Actions ----
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 8

            Controls.Button {
                text: "Check now"
                enabled: !releaseCenterService.loading && details.val("rowIndex") !== undefined
                onClicked: details.checkNow(Number(details.val("rowIndex")))
            }
            Controls.Button {
                text: "View on GitHub"
                onClicked: details.openUrl(details.releasesUrl())
            }
            Controls.Button {
                visible: details.str("homepageUrl").length > 0
                text: "Official site"
                onClicked: details.openUrl(details.str("homepageUrl"))
            }

            Item { Layout.fillWidth: true }

            // One-click update (auto-pick the OS asset) when an update is available.
            Controls.Button {
                visible: details.str("status") === "update_available"
                text: "Update"
                style: "success"
                isDefault: true
                Layout.preferredWidth: 120
                enabled: details.val("latestAssets") && details.val("latestAssets").length > 0
                onClicked: { details.updateApp(details.app); details.close() }
            }
            Controls.Button {
                text: "Download assets"
                style: details.str("status") === "update_available" ? "default" : "success"
                isDefault: details.str("status") !== "update_available"
                Layout.preferredWidth: 170
                enabled: details.val("latestAssets") && details.val("latestAssets").length > 0
                onClicked: { details.downloadAssets(details.app); details.close() }
            }
            Controls.Button {
                text: "Close"
                onClicked: details.close()
            }
        }
    }
}
