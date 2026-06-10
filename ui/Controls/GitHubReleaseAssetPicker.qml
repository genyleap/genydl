/*!
    \file        GitHubReleaseAssetPicker.qml
    \brief       GitHub release asset picker dialog for GENYDL.
    \details     Presents assets returned by GitHubReleaseService and lets the
                 user choose which asset URLs should be added to the queue.

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

Controls.Dialog {
    id: picker

    property var releaseInfo: ({})
    property var assets: []
    // GitHub source-code archives (.zip / .tar.gz). Hidden behind an opt-in
    // toggle because they are large and most users only want release binaries.
    property var sourceAssets: []
    property bool includeSources: false
    property bool loading: false
    property string errorText: ""
    property var selectedByUrl: ({})

    signal addSelected(var assets)
    signal openUrl(string url)

    // The list the user actually sees: release binaries plus, optionally, the
    // source-code archives.
    function allAssets() {
        if (includeSources && sourceAssets && sourceAssets.length > 0)
            return assets.concat(sourceAssets)
        return assets
    }

    function formatCount(value) {
        var n = Number(value || 0)
        if (n >= 1000000) return (n / 1000000).toFixed(n >= 10000000 ? 0 : 1) + "M"
        if (n >= 1000) return (n / 1000).toFixed(n >= 10000 ? 0 : 1) + "K"
        return String(n)
    }

    // Icon + value chip reused in the header (stars / forks / language / license).
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

    title: "GitHub Release Assets"
    type: errorText.length > 0 ? "warning" : "info"
    standardButtons: Dialog.NoButton
    width: Math.min(appRoot.width - 40, 980)
    height: Math.min(appRoot.height - 40, implicitHeight)
    modal: true
    focus: true

    function releaseValue(key) {
        return releaseInfo && releaseInfo[key] !== undefined ? String(releaseInfo[key]) : ""
    }

    function assetUrl(asset) {
        return asset && asset.downloadUrl !== undefined ? String(asset.downloadUrl) : ""
    }

    function assetSelected(asset) {
        const url = assetUrl(asset)
        return url.length > 0 && selectedByUrl[url] === true
    }

    function setAssetSelected(asset, selected) {
        const url = assetUrl(asset)
        if (url.length === 0)
            return

        var next = {}
        for (var key in selectedByUrl)
            next[key] = selectedByUrl[key]
        next[url] = selected
        selectedByUrl = next
    }

    // True when an asset is already present (completed) in a GenyDL download
    // folder, so it should not be re-queued.
    function assetDownloaded(asset) {
        if (!asset)
            return false
        return releaseCenterService.isAssetDownloaded(String(asset.name || ""),
                                                       Number(asset.size || 0))
    }

    function setAllAssets(selected) {
        var next = {}
        var list = allAssets()
        for (var i = 0; i < list.length; ++i) {
            const url = assetUrl(list[i])
            // Never auto-select assets that are already downloaded.
            if (url.length > 0 && !(selected && assetDownloaded(list[i])))
                next[url] = selected
        }
        selectedByUrl = next
    }

    function selectedAssets() {
        var chosen = []
        var list = allAssets()
        for (var i = 0; i < list.length; ++i) {
            if (assetSelected(list[i]))
                chosen.push(list[i])
        }
        return chosen
    }

    function selectedCount() {
        return selectedAssets().length
    }

    onAssetsChanged: setAllAssets(assets.length > 0)
    onOpened: if (allAssets().length > 0 && selectedCount() === 0) setAllAssets(true)
    // Auto-select the source archives when the user opts in to them.
    onIncludeSourcesChanged: if (includeSources) setAllAssets(true)

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 10

        // Rich app header: avatar, name, developer, description and stats — gives
        // the user context about the project they are downloading from.
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: headerCol.implicitHeight + 28
            radius: Metrics.innerRadius
            color: Colors.backgroundItemActivated
            border.width: 1
            border.color: Colors.borderActivated

            RowLayout {
                id: headerCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: 14
                spacing: 14

                Item {
                    Layout.preferredWidth: 56
                    Layout.preferredHeight: 56
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
                            visible: headerLogo.status !== Image.Ready
                            text: {
                                const o = picker.releaseValue("owner")
                                return o.length > 0 ? o.charAt(0).toUpperCase() : "?"
                            }
                            font.pixelSize: 24
                            font.bold: true
                            color: Colors.textSecondary
                        }
                        Image {
                            id: headerLogo
                            anchors.fill: parent
                            source: picker.releaseValue("avatarUrl")
                            fillMode: Image.PreserveAspectCrop
                            smooth: true; mipmap: true; cache: true; asynchronous: true
                            sourceSize.width: 112; sourceSize.height: 112
                            visible: false
                        }
                        Rectangle { id: headerLogoMask; anchors.fill: parent; radius: avatarFrame.radius; visible: false; layer.enabled: true }
                        MultiEffect {
                            anchors.fill: parent
                            source: headerLogo
                            maskEnabled: true
                            maskSource: headerLogoMask
                            visible: headerLogo.status === Image.Ready
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Controls.Label {
                            Layout.fillWidth: true
                            text: picker.releaseValue("displayName").length > 0
                                  ? picker.releaseValue("displayName")
                                  : picker.releaseValue("repository")
                            font.bold: true
                            font.pixelSize: Typography.h4
                            elide: Text.ElideRight
                        }
                        Rectangle {
                            Layout.preferredWidth: tagRow.implicitWidth + 20
                            Layout.preferredHeight: 26
                            radius: Metrics.innerRadius
                            color: Colors.secondryBack
                            border.width: 1
                            border.color: Colors.secondry
                            RowLayout {
                                id: tagRow
                                anchors.centerIn: parent
                                spacing: 6
                                Text {
                                    text: String.fromCharCode(0xf02b)   // tag
                                    font.family: FontSystem.getAwesomeSolid.name
                                    font.weight: Font.Black
                                    font.pixelSize: 11
                                    color: Colors.secondry
                                }
                                Controls.Label {
                                    text: picker.releaseValue("tagName")
                                    color: Colors.textPrimary
                                    font.pixelSize: Typography.t3
                                    font.bold: true
                                }
                            }
                        }
                    }

                    Controls.Label {
                        Layout.fillWidth: true
                        text: picker.releaseValue("repository")
                              + (picker.releaseValue("publishedText").length > 0
                                 ? "  •  Released " + picker.releaseValue("publishedText") : "")
                        color: Colors.textSecondary
                        font.pixelSize: Typography.t3
                        elide: Text.ElideRight
                    }

                    Controls.Label {
                        Layout.fillWidth: true
                        visible: picker.releaseValue("description").length > 0
                        text: picker.releaseValue("description")
                        color: Colors.textSecondary
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }

                    Flow {
                        Layout.fillWidth: true
                        Layout.topMargin: 2
                        spacing: 8
                        StatChip { glyph: String.fromCharCode(0xf005); glyphColor: Colors.star; label: picker.formatCount(picker.releaseValue("stars")) }
                        StatChip { glyph: String.fromCharCode(0xf126); glyphColor: Colors.secondry; label: picker.formatCount(picker.releaseValue("forks")) }
                        StatChip { visible: picker.releaseValue("language").length > 0; glyph: String.fromCharCode(0xf121); label: picker.releaseValue("language") }
                        StatChip { visible: picker.releaseValue("licenseSpdxId").length > 0; glyph: String.fromCharCode(0xf24e); label: picker.releaseValue("licenseSpdxId") }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 46
            radius: Metrics.innerRadius
            color: Colors.backgroundItemActivated
            visible: picker.loading

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 10

                BusyIndicator {
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    running: picker.loading
                }

                Controls.Label {
                    Layout.fillWidth: true
                    text: "Fetching release assets from GitHub..."
                    color: Colors.textSecondary
                }
            }
        }

        Controls.Label {
            Layout.fillWidth: true
            visible: picker.errorText.length > 0
            color: Colors.textError
            wrapMode: Text.WordWrap
            text: picker.errorText
        }

        RowLayout {
            Layout.fillWidth: true
            visible: !picker.loading && picker.errorText.length === 0
                     && (picker.assets.length > 0
                         || (picker.sourceAssets && picker.sourceAssets.length > 0))
            spacing: 8

            Controls.Button {
                text: "Select All"
                onClicked: picker.setAllAssets(true)
            }

            Controls.Button {
                text: "Clear"
                onClicked: picker.setAllAssets(false)
            }

            Controls.CheckBox {
                visible: picker.sourceAssets && picker.sourceAssets.length > 0
                text: "Include source code (.zip / .tar.gz)"
                checked: picker.includeSources
                onToggled: picker.includeSources = checked
            }

            Item { Layout.fillWidth: true }

            Controls.Label {
                text: picker.selectedCount() + " selected"
                color: Colors.textSecondary
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 54
            radius: Metrics.innerRadius
            color: Colors.backgroundItemActivated
            visible: !picker.loading && picker.errorText.length === 0
                     && picker.assets.length === 0
                     && !(picker.sourceAssets && picker.sourceAssets.length > 0)

            Controls.Label {
                anchors.centerIn: parent
                text: "This release does not publish downloadable assets."
                color: Colors.textMuted
            }
        }

        Rectangle {
            Layout.fillWidth: true
            // Bounded height: the sticky header plus a capped, internally-scrolling
            // list. This keeps the dialog itself from growing unbounded and gives
            // the asset list its own correct scrollbar instead of clipping.
            Layout.preferredHeight: 34 + Math.min(picker.allAssets().length * 56, 360)
            visible: !picker.loading && picker.errorText.length === 0 && picker.allAssets().length > 0
            radius: Metrics.innerRadius
            color: Colors.backgroundItemActivated
            border.width: 1
            border.color: Colors.borderActivated
            clip: true

            // Sticky column header.
            Rectangle {
                id: assetHeader
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 34
                color: "transparent"
                z: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 52
                    anchors.rightMargin: 24
                    spacing: 12

                    Controls.Label { Layout.fillWidth: true; text: "Filename"; color: Colors.textMuted }
                    Controls.Label { Layout.preferredWidth: 110; text: "Size"; color: Colors.textMuted }
                    Controls.Label { Layout.preferredWidth: 180; text: "Content type"; color: Colors.textMuted }
                    Controls.Label {
                        Layout.preferredWidth: 90
                        text: "Downloads"
                        horizontalAlignment: Text.AlignRight
                        color: Colors.textMuted
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 1
                    color: Colors.lineBorderActivated
                }
            }

            ListView {
                id: assetListView
                anchors.top: assetHeader.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                clip: true
                model: picker.allAssets()
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {
                    policy: assetListView.contentHeight > assetListView.height
                            ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                }

                delegate: Rectangle {
                    id: assetRow
                    required property var modelData
                    required property int index

                    // Assets already on disk are shown but disabled so the
                    // user does not re-download the same file.
                    readonly property bool isDownloaded: picker.assetDownloaded(modelData)

                    width: assetListView.width
                    height: 56
                    color: assetHover.hovered && !isDownloaded
                           ? Colors.backgroundItemHovered : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 24
                        spacing: 10
                        opacity: assetRow.isDownloaded ? 0.55 : 1.0

                        Controls.CheckBox {
                            Layout.preferredWidth: 24
                            enabled: !assetRow.isDownloaded
                            checked: !assetRow.isDownloaded && picker.assetSelected(modelData)
                            onToggled: picker.setAssetSelected(modelData, checked)
                        }

                        Text {
                            Layout.fillWidth: true
                            text: modelData.name || ""
                            color: Colors.textPrimary
                            font.family: FontSystem.getContentFontRegular.name
                            font.pixelSize: Typography.t2
                            elide: Text.ElideMiddle
                            verticalAlignment: Text.AlignVCenter
                        }

                        // "Downloaded" badge replaces the size column when the
                        // asset is already present locally.
                        Rectangle {
                            Layout.preferredWidth: 110
                            Layout.preferredHeight: 24
                            visible: assetRow.isDownloaded
                            radius: Metrics.innerRadius
                            color: Colors.successBack
                            border.width: 1
                            border.color: Colors.success
                            Controls.Label {
                                anchors.centerIn: parent
                                text: "Downloaded"
                                color: Colors.success
                                font.pixelSize: Typography.t3
                            }
                        }
                        Controls.Label {
                            Layout.preferredWidth: 110
                            visible: !assetRow.isDownloaded
                            // Source archives have no size reported by GitHub.
                            text: modelData.isSource === true
                                  ? "Source"
                                  : (modelData.sizeText || "0 B")
                            color: modelData.isSource === true ? Colors.textAccent : Colors.textPrimary
                            elide: Text.ElideRight
                        }

                        RowLayout {
                            Layout.preferredWidth: 180
                            spacing: 6
                            // Shield shown when GitHub provides an integrity digest;
                            // the download will be checksum-verified on completion.
                            Text {
                                visible: String(modelData.digest || "").length > 0
                                text: String.fromCharCode(0xf3ed)   // shield-halved
                                font.family: FontSystem.getAwesomeSolid.name
                                font.weight: Font.Black
                                font.pixelSize: 11
                                color: Colors.success
                                HoverHandler { id: shieldHover }
                                Controls.ToolTip {
                                    above: true
                                    active: shieldHover.hovered
                                    text: "Integrity verified after download (" +
                                          String(modelData.digest || "").split(":")[0] + ")"
                                }
                            }
                            Controls.Label {
                                Layout.fillWidth: true
                                text: modelData.contentType || "application/octet-stream"
                                elide: Text.ElideRight
                            }
                        }

                        Controls.Label {
                            Layout.preferredWidth: 90
                            text: String(modelData.downloadCount || 0)
                            horizontalAlignment: Text.AlignRight
                        }
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 1
                        visible: assetRow.index < picker.allAssets().length - 1
                        color: Colors.lineBorderActivated
                    }

                    HoverHandler {
                        id: assetHover
                        enabled: !assetRow.isDownloaded
                    }

                    TapHandler {
                        enabled: !assetRow.isDownloaded
                        acceptedButtons: Qt.LeftButton
                        onTapped: picker.setAssetSelected(modelData, !picker.assetSelected(modelData))
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Item { Layout.fillWidth: true }

            Controls.Button {
                text: "Cancel"
                onClicked: picker.close()
            }

            Controls.Button {
                text: "Add Selected to Queue"
                style: "success"
                isDefault: true
                enabled: !picker.loading && picker.errorText.length === 0 && picker.selectedCount() > 0
                Layout.preferredWidth: 190
                onClicked: {
                    const chosen = picker.selectedAssets()
                    if (chosen.length === 0)
                        return
                    picker.addSelected(chosen)
                    picker.close()
                }
            }
        }
    }
}
