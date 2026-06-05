/*!
    \file        GitHubReleaseAssetPicker.qml
    \brief       GitHub release asset picker dialog for TONDAR.
    \details     Presents assets returned by GitHubReleaseService and lets the
                 user choose which asset URLs should be added to the queue.

    \author      Kambiz Asadzadeh <https://github.com/thecompez>
    \copyright   Copyright (c) 2026 Genyleap. All rights reserved.
    \license     https://github.com/genyleap/tondar/blob/main/LICENSE.md
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Tondar
import "." as Controls

Controls.Dialog {
    id: picker

    property var releaseInfo: ({})
    property var assets: []
    property bool loading: false
    property string errorText: ""
    property var selectedByUrl: ({})

    signal addSelected(var assets)

    title: "GitHub Release Assets"
    type: errorText.length > 0 ? "warning" : "info"
    standardButtons: Dialog.NoButton
    width: Math.min(appRoot.width - 40, 980)
    height: Math.min(appRoot.height - 40, 720)
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

    function setAllAssets(selected) {
        var next = {}
        for (var i = 0; i < assets.length; ++i) {
            const url = assetUrl(assets[i])
            if (url.length > 0)
                next[url] = selected
        }
        selectedByUrl = next
    }

    function selectedAssets() {
        var chosen = []
        for (var i = 0; i < assets.length; ++i) {
            if (assetSelected(assets[i]))
                chosen.push(assets[i])
        }
        return chosen
    }

    function selectedCount() {
        return selectedAssets().length
    }

    onAssetsChanged: setAllAssets(assets.length > 0)
    onOpened: if (assets.length > 0 && selectedCount() === 0) setAllAssets(true)

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 10

        Controls.GroupBox {
            Layout.fillWidth: true
            Layout.preferredHeight: releaseSummary.implicitHeight + topPadding + bottomPadding
            title: "Release"

            GridLayout {
                id: releaseSummary
                anchors.fill: parent
                columns: 2
                columnSpacing: 14
                rowSpacing: 6

                Controls.Label { text: "Repository" }
                Controls.Label {
                    Layout.fillWidth: true
                    text: picker.releaseValue("repository")
                    font.bold: true
                    elide: Text.ElideRight
                }

                Controls.Label { text: "Tag" }
                Controls.Label {
                    Layout.fillWidth: true
                    text: picker.releaseValue("tagName")
                    elide: Text.ElideRight
                }

                Controls.Label { text: "Title" }
                Controls.Label {
                    Layout.fillWidth: true
                    text: picker.releaseValue("name").length > 0 ? picker.releaseValue("name") : picker.releaseValue("tagName")
                    elide: Text.ElideRight
                }

                Controls.Label { text: "Published" }
                Controls.Label {
                    Layout.fillWidth: true
                    text: picker.releaseValue("publishedText")
                    elide: Text.ElideRight
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
            visible: !picker.loading && picker.errorText.length === 0 && picker.assets.length > 0
            spacing: 8

            Controls.Button {
                text: "Select All"
                onClicked: picker.setAllAssets(true)
            }

            Controls.Button {
                text: "Clear"
                onClicked: picker.setAllAssets(false)
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
            visible: !picker.loading && picker.errorText.length === 0 && picker.assets.length === 0

            Controls.Label {
                anchors.centerIn: parent
                text: "This release does not publish downloadable assets."
                color: Colors.textMuted
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: !picker.loading && picker.errorText.length === 0 && picker.assets.length > 0
            spacing: 6

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                color: "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 42
                    anchors.rightMargin: 12
                    spacing: 12

                    Controls.Label {
                        Layout.fillWidth: true
                        text: "Filename"
                        color: Colors.textMuted
                    }
                    Controls.Label {
                        Layout.preferredWidth: 110
                        text: "Size"
                        color: Colors.textMuted
                    }
                    Controls.Label {
                        Layout.preferredWidth: 180
                        text: "Content type"
                        color: Colors.textMuted
                    }
                    Controls.Label {
                        Layout.preferredWidth: 90
                        text: "Downloads"
                        horizontalAlignment: Text.AlignRight
                        color: Colors.textMuted
                    }
                }
            }

            Repeater {
                model: picker.assets

                delegate: Rectangle {
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: 56
                    radius: Metrics.innerRadius
                    color: assetHover.hovered ? Colors.backgroundItemHovered : Colors.backgroundItemActivated
                    border.width: picker.assetSelected(modelData) ? 1 : 0
                    border.color: Colors.borderFocused

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 12
                        spacing: 10

                        Controls.CheckBox {
                            Layout.preferredWidth: 24
                            checked: picker.assetSelected(modelData)
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

                        Controls.Label {
                            Layout.preferredWidth: 110
                            text: modelData.sizeText || "0 B"
                            elide: Text.ElideRight
                        }

                        Controls.Label {
                            Layout.preferredWidth: 180
                            text: modelData.contentType || "application/octet-stream"
                            elide: Text.ElideRight
                        }

                        Controls.Label {
                            Layout.preferredWidth: 90
                            text: String(modelData.downloadCount || 0)
                            horizontalAlignment: Text.AlignRight
                        }
                    }

                    HoverHandler {
                        id: assetHover
                    }

                    TapHandler {
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
