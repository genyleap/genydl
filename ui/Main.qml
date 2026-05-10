/*!
    \file        Main.qml
    \brief       Implements the main application window for RAAD.
    \details     This file defines the primary QML application shell, window structure, and top-level UI workflow for RAAD.

    \author      Kambiz Asadzadeh <https://github.com/thecompez>
    \copyright   Copyright (c) 2026 Genyleap. All rights reserved.
    \license     https://github.com/genyleap/raad/blob/main/LICENSE.md
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes
import QtQuick.Particles
import QtQml.Models

import QtQuick.Dialogs as QQD
import QtCore
import Qt.labs.qmlmodels

import "./Controls" as Controls

import "utils.js" as Utils

import Raad 1.0

ApplicationWindow {
    id: appRoot
    visible: true

    QtObject {
        id: appAttributes
        property string name: "Raad - Internet Download Manager"
        property int width: 1280
        property int height: 800
        property int interiorWidth : appRoot.width
        property int interiorHeight : appRoot.height / 2
    }

    width: appAttributes.width
    height: appAttributes.height
    minimumWidth: appAttributes.width
    minimumHeight: appAttributes.height

    // flags: Qt.ApplicationModal | Qt.MaximizeUsingFullscreenGeometryHint

    title: qsTr(appAttributes.name)

    Overlay.modal: Rectangle {
        id: dimLayer
        color: "#000000"
        opacity: 0.0

        Behavior on opacity {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }

        visible: opacity > 0

        Component.onCompleted: opacity = 0.6
    }

    background: Rectangle{
        id: rootBackground
        anchors.fill: parent
        color: Colors.pageground
    }

    QtObject {
        id: appRootObjects
        property bool isOnline               : false
        property bool isLogin                : true
        property bool isLeftToRight          : true
        property bool isDarkMode             : false
    }

    property int pageIndex: 0

    property string queueFilter: "All Queues"
    property string statusFilter: "All"
    property string categoryFilter: "All"
    property string searchText: ""

    property int sortIndex: 0
    property bool sortAscending: true
    property int themeMode: Colors.modeSystem
    property int downloadsViewMode: 0
    property int configurationTabIndex: 0
    property string lastUpdateNotificationVersion: ""

    property int selectedTaskIndex: -1
    property var selectedTask: null
    property string selectedQueue: ""
    property string selectedCategory: ""
    property var checkedTaskRows: []

    property int detailsRow: -1
    property var detailsTask: null
    property string detailsQueue: ""
    property string detailsCategory: ""
    property real detailsBytesReceived: 0
    property real detailsBytesTotal: 0
    property int detailsRevision: 0
    property var detailsSpeedSamples: []
    property real detailsPeakSpeed: 1

    property string queueEditorName: ""
    property string addDefaultOutputPath: ""
    property string addDefaultQueue: "General"
    property string addDefaultCategory: "Auto"
    property int addDefaultSegments: 8
    property bool addDefaultAdaptive: false
    property bool addDefaultStartPaused: false
    property bool sidebarAllExpanded: true
    property bool sidebarUnfinishedExpanded: false
    property bool sidebarFinishedExpanded: false
    property bool sidebarQueuesExpanded: true
    property var pendingRemoveRows: []
    property var tableRows: []

    readonly property bool hasSelection: selectedTask !== null
                                         && selectedTask !== undefined
                                         && selectedTaskIndex >= 0
                                         && selectedTaskIndex < downloadManager.taskCount()
    readonly property bool detailsIsDone: detailsTask && detailsTask.stateString === "Done"
    readonly property real detailsProgress: detailsIsDone
                                            ? 1.0
                                            : (detailsBytesTotal > 0 ? Math.min(1.0, detailsBytesReceived / detailsBytesTotal) : 0.0)
    readonly property var statusOptions: ["All", "Unfinished", "History", "Active", "Queued", "Paused", "Done", "Error", "Canceled"]
    readonly property var sortOptions: ["Name", "Status", "Received", "Total", "Queue", "Category"]
    readonly property var themeOptions: ["System", "Dark", "Light"]
    readonly property string donationAddress: "0x6E99f7564d060AA141dcC47ede34379Bad0cDCCC"
    readonly property string donationBaseExplorerUrl: "https://basescan.org/address/0x6E99f7564d060AA141dcC47ede34379Bad0cDCCC"
    readonly property string donationMainnetExplorerUrl: "https://etherscan.io/address/0x6E99f7564d060AA141dcC47ede34379Bad0cDCCC"
    readonly property string developerFarcasterUrl: "https://farcaster.xyz/compez.eth"
    readonly property string developerXUrl: "https://x.com/thecompez"
    readonly property string developerGithubUrl: "https://github.com/thecompez"
    readonly property string projectRepositoryUrl: "https://github.com/genyleap/raad"
    readonly property string projectLicenseUrl: "https://github.com/genyleap/raad?tab=MIT-1-ov-file#readme"
    readonly property string qtOpenSourceUrl: "https://doc.qt.io/qt-6/licensing.html"
    readonly property string genyleapWebsiteUrl: "https://genyleap.com"
    readonly property string genyleapSupportUrl: "https://genyleap.com/support"
    readonly property string genyleapSupportEmail: "support@genyleap.com"
    readonly property string creatorName: "Kambiz Asadzadeh"
    readonly property string copyrightOwner: "Genyleap Labs"
    readonly property string genyTokenName: "Genyleap"
    readonly property string genyTokenSymbol: "GENY"
    readonly property string genyTokenDescription: "An ERC20 token with a fixed supply of 256 million, designed to empower creators and drive innovation in the Genyleap ecosystem."
    readonly property string genyTokenImageUrl: "https://genyleap.com/assets/token/images/geny-logo.svg"
    readonly property string genyTokenContractAddress: "0x2a3d6f8c1fc4AcDcf3A75d19b445bae02F03676B"
    readonly property string genyTokenBaseExplorerUrl: "https://basescan.org/address/0x2a3d6f8c1fc4AcDcf3A75d19b445bae02F03676B"
    readonly property string genyTokenXUrl: "https://x.com/genyleap"
    readonly property string genyTokenTelegramUrl: "https://t.me/genyleap"
    readonly property string mitLicenseText: "MIT License\n\n"
                                              + "Copyright (c) 2026 Genyleap Labs\n\n"
                                              + "Permission is hereby granted, free of charge, to any person obtaining a copy\n"
                                              + "of this software and associated documentation files (the \"Software\"), to deal\n"
                                              + "in the Software without restriction, including without limitation the rights\n"
                                              + "to use, copy, modify, merge, publish, distribute, sublicense, and/or sell\n"
                                              + "copies of the Software, and to permit persons to whom the Software is\n"
                                              + "furnished to do so, subject to the following conditions:\n\n"
                                              + "The above copyright notice and this permission notice shall be included in all\n"
                                              + "copies or substantial portions of the Software.\n\n"
                                              + "THE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR\n"
                                              + "IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,\n"
                                              + "FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE\n"
                                              + "AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER\n"
                                              + "LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,\n"
                                              + "OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE\n"
                                              + "SOFTWARE."
    readonly property int fileNameRole: Qt.UserRole + 1
    readonly property int progressRole: Qt.UserRole + 2
    readonly property int finishedRole: Qt.UserRole + 3
    readonly property int taskRole: Qt.UserRole + 4
    readonly property int statusRole: Qt.UserRole + 5
    readonly property int bytesReceivedRole: Qt.UserRole + 6
    readonly property int bytesTotalRole: Qt.UserRole + 7
    readonly property int queueRole: Qt.UserRole + 8
    readonly property int categoryRole: Qt.UserRole + 9

    function formatBytes() { return Utils.formatBytes.apply(this, arguments) }
    function formatSpeed() { return Utils.formatSpeed.apply(this, arguments) }
    function formatEta() { return Utils.formatEta.apply(this, arguments) }
    function baseName() { return Utils.baseName.apply(this, arguments) }
    function applySort() { return Utils.applySort.apply(this, arguments) }
    function statusPasses() { return Utils.statusPasses.apply(this, arguments) }
    function rowAccepted() { return Utils.rowAccepted.apply(this, arguments) }
    function setStatusScope() { return Utils.setStatusScope.apply(this, arguments) }
    function setCategoryScope() { return Utils.setCategoryScope.apply(this, arguments) }
    function setQueueScope() { return Utils.setQueueScope.apply(this, arguments) }
    function visibleTaskRows() { return Utils.visibleTaskRows.apply(this, arguments) }
    function visibleTaskCount() { return Utils.visibleTaskCount.apply(this, arguments) }
    function areAllVisibleChecked() { return Utils.areAllVisibleChecked.apply(this, arguments) }
    function syncSelectAllCheckBox() { return Utils.syncSelectAllCheckBox.apply(this, arguments) }
    function clearSelection() { return Utils.clearSelection.apply(this, arguments) }
    function selectTask() { return Utils.selectTask.apply(this, arguments) }
    function selectedState() { return Utils.selectedState.apply(this, arguments) }
    function sanitizedCheckedTaskRows() { return Utils.sanitizedCheckedTaskRows.apply(this, arguments) }
    function sanitizeCheckedTaskRows() { return Utils.sanitizeCheckedTaskRows.apply(this, arguments) }
    function isRowChecked() { return Utils.isRowChecked.apply(this, arguments) }
    function isTaskChecked() { return Utils.isTaskChecked.apply(this, arguments) }
    function setRowChecked() { return Utils.setRowChecked.apply(this, arguments) }
    function setTaskChecked() { return Utils.setTaskChecked.apply(this, arguments) }
    function clearCheckedTasks() { return Utils.clearCheckedTasks.apply(this, arguments) }
    function checkedTaskCount() { return Utils.checkedTaskCount.apply(this, arguments) }
    function actionTargetRows() { return Utils.actionTargetRows.apply(this, arguments) }
    function actionTargets() { return Utils.actionTargets.apply(this, arguments) }
    function canResumeAction() { return Utils.canResumeAction.apply(this, arguments) }
    function canStopAction() { return Utils.canStopAction.apply(this, arguments) }
    function canStopAllAction() { return Utils.canStopAllAction.apply(this, arguments) }
    function applyActionToCheckedOrSelected() { return Utils.applyActionToCheckedOrSelected.apply(this, arguments) }
    function openToolbarItemMenu() { return Utils.openToolbarItemMenu.apply(this, arguments) }
    function openPropertiesForSelection() { return Utils.openPropertiesForSelection.apply(this, arguments) }
    function shareSelectedTargets() { return Utils.shareSelectedTargets.apply(this, arguments) }
    function resolveTaskRow() { return Utils.resolveTaskRow.apply(this, arguments) }
    function taskStatusText() { return Utils.taskStatusText.apply(this, arguments) }
    function taskFileNameValue() { return Utils.taskFileNameValue.apply(this, arguments) }
    function setCategoryPreset() { return Utils.setCategoryPreset.apply(this, arguments) }
    function openDetailsFor() { return Utils.openDetailsFor.apply(this, arguments) }
    function openConfigurationDialog() { return Utils.openConfigurationDialog.apply(this, arguments) }
    function promptRemoveRows() { return Utils.promptRemoveRows.apply(this, arguments) }
    function confirmRemovePending() { return Utils.confirmRemovePending.apply(this, arguments) }
    function executeRowAction() { return Utils.executeRowAction.apply(this, arguments) }
    function submitDownload() { return Utils.submitDownload.apply(this, arguments) }
    function rebuildDownloadTableRows() { return Utils.rebuildDownloadTableRows.apply(this, arguments) }
    function scheduleRebuildDownloadTableRows() { return Utils.scheduleRebuildDownloadTableRows.apply(this, arguments) }
    function addDownloadFromInputs() { return Utils.addDownloadFromInputs.apply(this, arguments) }
    function openAddUrlDialog() { return Utils.openAddUrlDialog.apply(this, arguments) }
    function isTorrentLikeInput() { return Utils.isTorrentLikeInput.apply(this, arguments) }
    function loadQueueEditor() { return Utils.loadQueueEditor.apply(this, arguments) }
    function applyQueueEditor() { return Utils.applyQueueEditor.apply(this, arguments) }
    function createQueueFromEditor() { return Utils.createQueueFromEditor.apply(this, arguments) }
    function renameCurrentQueueTo() { return Utils.renameCurrentQueueTo.apply(this, arguments) }
    function removeCurrentQueue() { return Utils.removeCurrentQueue.apply(this, arguments) }
    function refreshDetailsSnapshot() { return Utils.refreshDetailsSnapshot.apply(this, arguments) }
    function resetDetailsSamples() { return Utils.resetDetailsSamples.apply(this, arguments) }
    function pushDetailsSpeedSample() { return Utils.pushDetailsSpeedSample.apply(this, arguments) }
    function notificationTimestamp() { return Qt.formatDateTime(new Date(), "yyyy-MM-dd hh:mm") }
    function appendNotification(title, message, type) {
        notificationModel.insert(0, {
            title: title && title.length > 0 ? title : "Notification",
            message: message && message.length > 0 ? message : "",
            time: notificationTimestamp(),
            type: type && type.length > 0 ? type : "default"
        })
        while (notificationModel.count > 25) {
            notificationModel.remove(notificationModel.count - 1)
        }
    }
    function openExternalLink(url, label) {
        if (!url || url.length === 0)
            return
        Qt.openUrlExternally(url)
        appRoot.appendNotification(label && label.length > 0 ? label : "Opened link", url, "info")
    }
    function copyToClipboard(value, label) {
        if (!value || value.length === 0)
            return
        downloadManager.copyText(value)
        appRoot.appendNotification(label && label.length > 0 ? label : "Copied to clipboard", value, "success")
    }
    function restoreUiDefaults() {
        uiSettings.savedPageIndex = 0
        uiSettings.savedQueueFilter = "All Queues"
        uiSettings.savedStatusFilter = "All"
        uiSettings.savedCategoryFilter = "All"
        uiSettings.savedSortIndex = 0
        uiSettings.savedSortAscending = true
        uiSettings.savedThemeMode = Colors.modeSystem
        uiSettings.savedDownloadsViewMode = 0

        pageIndex = 0
        queueFilter = "All Queues"
        statusFilter = "All"
        categoryFilter = "All"
        searchText = ""
        sortIndex = 0
        sortAscending = true
        themeMode = Colors.modeSystem
        downloadsViewMode = 0
        configurationTabIndex = 0
        lastUpdateNotificationVersion = ""

        selectedTaskIndex = -1
        selectedTask = null
        selectedQueue = ""
        selectedCategory = ""
        checkedTaskRows = []

        detailsRow = -1
        detailsTask = null
        detailsQueue = ""
        detailsCategory = ""
        detailsBytesReceived = 0
        detailsBytesTotal = 0
        detailsRevision = 0
        detailsSpeedSamples = []
        detailsPeakSpeed = 1

        queueEditorName = downloadManager.defaultQueueName()
        addDefaultOutputPath = documentsFolder
        addDefaultQueue = downloadManager.defaultQueueName()
        addDefaultCategory = downloadManager.categoryNames().length > 0 ? downloadManager.categoryNames()[0] : "Auto"
        addDefaultSegments = 8
        addDefaultAdaptive = false
        addDefaultStartPaused = false
        sidebarAllExpanded = true
        sidebarUnfinishedExpanded = false
        sidebarFinishedExpanded = false
        sidebarQueuesExpanded = true
        pendingRemoveRows = []
        tableRows = []

        notificationModel.clear()
        appRoot.clearSelection()
        appRoot.loadQueueEditor()
        appRoot.applySort()
        appRoot.rebuildDownloadTableRows()
    }
    function resetAllSettingsToDefaults() {
        downloadManager.resetPersistentState()
        updateClient.resetSettingsToDefaults()
        appRoot.restoreUiDefaults()
        notificationDrawer.close()
        updateDialog.close()
        updateAvailableDialog.close()
        resetSettingsDialog.close()
    }

    Settings {
        id: uiSettings
        category: "ui"
        property int savedPageIndex: 0
        property string savedQueueFilter: "All Queues"
        property string savedStatusFilter: "All"
        property string savedCategoryFilter: "All"
        property int savedSortIndex: 0
        property bool savedSortAscending: true
        property int savedThemeMode: 0
        property int savedDownloadsViewMode: 0
    }

    QQD.FileDialog {
        id: importDialog
        title: "Import Download List"
        fileMode: QQD.FileDialog.OpenFile
        nameFilters: ["Download Lists (*.json *.txt)", "All files (*)"]
        onAccepted: {
            const p = selectedFile.toString().replace("file://", "")
            downloadManager.importList(p)
        }
    }

    QQD.FileDialog {
        id: exportDialog
        title: "Export Download List"
        fileMode: QQD.FileDialog.SaveFile
        nameFilters: ["JSON (*.json)", "Text (*.txt)"]
        onAccepted: {
            const p = selectedFile.toString().replace("file://", "")
            downloadManager.exportList(p)
        }
    }

    Controls.Dialog {
        id: aboutDialog
        width: Math.min(appRoot.width - 60, 620)
        height: 520

        title: "About Raad"
        type: "info"
        desc: "Raad Download Manager"
        message: "Raad provides segmented downloading, queue control, adaptive segment scheduling, runtime policies, and update delivery in a desktop workflow."

        standardButtons: Dialog.Close

        ColumnLayout {
            id: contentItemId
            Layout.fillWidth: true
            spacing: 20

            Rectangle {
                Layout.fillWidth: true
                radius: Metrics.cornerRadius
                color: Colors.backgroundItemActivated
                border.width: 1
                border.color: Colors.borderActivated
                implicitHeight: aboutHeroLayout.implicitHeight + 28

                RowLayout {
                    id: aboutHeroLayout
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 14

                    Rectangle {
                        Layout.preferredWidth: 96
                        Layout.preferredHeight: 96
                        radius: 26
                        color: Colors.backgroundActivated
                        border.width: 1
                        border.color: Colors.borderActivated

                        Image {
                            id: raadAboutImage
                            anchors.fill: parent
                            anchors.margins: 8
                            source: "qrc:/Raad.png"
                            // fillMode: Image.PreserveAspectFit
                            smooth: true
                            asynchronous: true
                            cache: true
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: raadAboutImage.status !== Image.Ready
                            text: "RAAD"
                            color: Colors.textPrimary
                            font.family: FontSystem.getTitleBoldFont.font.family
                            font.pixelSize: Typography.t2
                            font.bold: true
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: 4

                        Text {
                            Layout.fillWidth: true
                            text: "Raad Download Manager"
                            color: Colors.textPrimary
                            font.family: FontSystem.getTitleBoldFont.font.family
                            font.pixelSize: Typography.h4
                            font.bold: true
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Modern segmented downloading with queue control, runtime policies, and update delivery."
                            color: Colors.textSecondary
                            font.family: FontSystem.getContentFontRegular.name
                            font.pixelSize: Typography.t2
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }

            GridLayout {
                columns: 2
                columnSpacing: 24
                rowSpacing: 8

                Controls.Label { text: "Name" }
                Controls.Label { text: "Raad Download Manager" }
                Controls.Label { text: "Version" }
                Controls.Label { text: Qt.application.version }
                Controls.Label { text: "Framework" }
                Controls.Label { text: "Qt 6.10.2" }
                Controls.Label { text: "Creator" }
                Controls.Label { text: appRoot.creatorName }
                Controls.Label { text: "Copyright" }
                Controls.Label { text: "2026 " + appRoot.copyrightOwner }
                Controls.Label { text: "Engine written with" }
                Controls.Label { text: "C++23 (ISO/IEC 14882:2024)" }
            }

            Controls.HorizontalLine {}

            ColumnLayout {
                spacing: 6

                Controls.Label { text: "• Segmented downloads with optional adaptive segment control" }
                Controls.Label { text: "• Queue routing, quota, schedule, and bandwidth policies" }
                Controls.Label { text: "• Proxy, SSL, user-agent, retry, and resume support" }
                Controls.Label { text: "• Update discovery and package delivery workflow" }
            }
        }
    }

    Controls.Dialog {
        id: updateDialog
        width: Math.min(appRoot.width - 48, 760)
        height: Math.min(appRoot.height - 32, 900)
        title: "Updates"
        type: "info"
        message: ""

        standardButtons: Dialog.Close

        ScrollView {
            id: updateDialogScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            ColumnLayout {
                width: Math.max(320, updateDialogScroll.availableWidth)
                spacing: 12

                Controls.GroupBox {
                    title: "Current State"
                    Layout.fillWidth: true
                    implicitHeight: updateCurrentStateLayout.implicitHeight + topPadding + bottomPadding

                    GridLayout {
                        id: updateCurrentStateLayout
                        width: parent.width
                        columns: 2
                        columnSpacing: 12
                        rowSpacing: 8

                        Controls.Label { text: "Current version" }
                        Controls.Label { text: updateClient.currentVersion }
                        Controls.Label { text: "Latest version" }
                        Controls.Label { text: updateClient.latestVersion.length > 0 ? updateClient.latestVersion : "--" }
                        Controls.Label { text: "Status" }
                        Controls.Label { text: updateClient.status }
                        Controls.Label { text: "Source" }
                        Controls.Label { text: updateClient.sourcePreference }
                    }
                }

                Controls.GroupBox {
                    title: "Actions"
                    Layout.fillWidth: true
                    implicitHeight: updateActionsLayout.implicitHeight + topPadding + bottomPadding

                    RowLayout {
                        id: updateActionsLayout
                        width: parent.width
                        spacing: 10

                        Controls.Button { text: "Check Now"; onClicked: updateClient.checkNow() }
                        Controls.Button { text: "Download"; enabled: updateClient.updateAvailable; onClicked: updateClient.downloadUpdate() }
                        Controls.Button { text: "Install"; enabled: updateClient.downloadReady; onClicked: updateClient.installUpdate() }
                        Controls.Button {
                            text: "Settings"
                            onClicked: appRoot.openConfigurationDialog(3)
                        }
                        Item { Layout.fillWidth: true }
                    }
                }

                Controls.GroupBox {
                    title: "Preferences"
                    Layout.fillWidth: true
                    implicitHeight: updatePreferencesLayout.implicitHeight + topPadding + bottomPadding

                    GridLayout {
                        id: updatePreferencesLayout
                        width: parent.width
                        columns: 2
                        columnSpacing: 12
                        rowSpacing: 8

                        Controls.Label { text: "Check on startup" }
                        Controls.Label { text: "Always" }

                        Controls.Label { text: "Update mode" }
                        Controls.ComboBox {
                            Layout.preferredWidth: 220
                            model: ["custom", "automatic"]
                            currentIndex: Math.max(0, ["custom", "automatic"].indexOf(updateClient.updateMode))
                            onActivated: updateClient.updateMode = currentText
                        }

                        Controls.Label { text: "Channel" }
                        Controls.ComboBox {
                            Layout.preferredWidth: 220
                            model: ["stable", "beta"]
                            currentIndex: Math.max(0, ["stable", "beta"].indexOf(updateClient.channel))
                            onActivated: updateClient.channel = currentText
                        }

                        Controls.Label { text: "Source" }
                        Controls.ComboBox {
                            Layout.preferredWidth: 220
                            model: ["auto", "website", "github"]
                            currentIndex: Math.max(0, ["auto", "website", "github"].indexOf(updateClient.sourcePreference))
                            onActivated: updateClient.sourcePreference = currentText
                        }

                        Controls.Label { text: "Require signature" }
                        Controls.Switch {
                            checked: updateClient.requireSignature
                            onToggled: updateClient.requireSignature = checked
                        }

                        Controls.Label { text: "GitHub repo" }
                        Controls.TextField {
                            Layout.fillWidth: true
                            text: updateClient.githubRepo
                            onEditingFinished: updateClient.githubRepo = text
                        }

                        Controls.Label { text: "Manifest URL" }
                        Controls.TextField {
                            Layout.fillWidth: true
                            text: updateClient.manifestUrl
                            onEditingFinished: updateClient.manifestUrl = text
                        }

                        Controls.Label { text: "Public key" }
                        Controls.TextField {
                            Layout.fillWidth: true
                            text: updateClient.publicKeyPath
                            onEditingFinished: updateClient.publicKeyPath = text
                        }
                    }
                }

                Controls.GroupBox {
                    title: "Progress"
                    Layout.fillWidth: true
                    implicitHeight: updateProgressLayout.implicitHeight + topPadding + bottomPadding

                    ColumnLayout {
                        id: updateProgressLayout
                        width: parent.width
                        spacing: 10

                        Controls.ProgressBar {
                            Layout.fillWidth: true
                            value: Math.max(0.0, Math.min(1.0, updateClient.downloadProgress))
                            indeterminate: updateClient.status.toLowerCase().indexOf("downloading") >= 0
                                           && updateClient.downloadProgress <= 0
                            statusLevel: updateClient.lastError.length > 0 ? "Error" : (updateClient.updateAvailable ? "Paused" : "Done")
                        }
                        Controls.Label {
                            Layout.fillWidth: true
                            text: updateClient.status.length > 0 ? updateClient.status : "Idle"
                        }
                        Controls.Label {
                            Layout.fillWidth: true
                            visible: updateClient.lastError.length > 0
                            color: Colors.error
                            text: updateClient.lastError.length > 0 ? ("Error: " + updateClient.lastError) : ""
                            wrapMode: Text.Wrap
                        }
                    }
                }

                Controls.GroupBox {
                    title: "Release Notes"
                    Layout.fillWidth: true
                    implicitHeight: updateNotesLayout.implicitHeight + topPadding + bottomPadding

                    ColumnLayout {
                        id: updateNotesLayout
                        width: parent.width
                        spacing: 0

                        TextArea {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 128
                            readOnly: true
                            text: updateClient.releaseNotes
                            placeholderText: "Release notes"
                        }
                    }
                }

            }
        }
    }

    Controls.Dialog {
        id: supportDialog
        width: Math.min(appRoot.width - 60, 820)
        height: 620
        title: "Support & Community"
        type: "info"
        desc: "Official Genyleap resources"
        message: "Production links for RAAD, Genyleap, and the developer profile."

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 14

            Rectangle {
                Layout.fillWidth: true
                radius: Metrics.cornerRadius
                color: Colors.backgroundItemActivated
                border.width: 1
                border.color: Colors.borderActivated
                implicitHeight: supportHeroLayout.implicitHeight + 28

                RowLayout {
                    id: supportHeroLayout
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 14

                    Rectangle {
                        Layout.preferredWidth: 68
                        Layout.preferredHeight: 68
                        radius: 22
                        color: Colors.secondryBack
                        border.width: 1
                        border.color: Colors.secondry

                        Text {
                            anchors.centerIn: parent
                            text: "RAAD"
                            color: Colors.textPrimary
                            font.family: FontSystem.getTitleBoldFont.font.family
                            font.pixelSize: Typography.t2
                            font.bold: true
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            Layout.fillWidth: true
                            text: "Official support and developer channels"
                            color: Colors.textPrimary
                            font.family: FontSystem.getTitleBoldFont.font.family
                            font.pixelSize: Typography.h4
                            font.bold: true
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Use the direct links below for website, repository, Farcaster, X, GitHub, and support."
                            color: Colors.textSecondary
                            font.family: FontSystem.getContentFontRegular.name
                            font.pixelSize: Typography.t2
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }

            Controls.GroupBox {
                title: "Project Links"
                Layout.fillWidth: true
                implicitHeight: supportProjectLayout.implicitHeight + topPadding + bottomPadding

                ColumnLayout {
                    id: supportProjectLayout
                    width: parent.width
                    spacing: 10

                    Rectangle {
                        Layout.fillWidth: true
                        radius: Metrics.innerRadius
                        color: Colors.backgroundItemActivated
                        border.width: 1
                        border.color: Colors.borderActivated
                        implicitHeight: supportWebsiteCard.implicitHeight + 24

                        RowLayout {
                            id: supportWebsiteCard
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                spacing: 4

                                Text {
                                    text: "Official Website"
                                    color: Colors.textPrimary
                                    font.family: FontSystem.getTitleBoldFont.font.family
                                    font.pixelSize: Typography.t2
                                    font.bold: true
                                }

                                Text {
                                    text: "Genyleap Labs home for RAAD and ecosystem updates."
                                    color: Colors.textSecondary
                                    font.family: FontSystem.getContentFontRegular.name
                                    font.pixelSize: Typography.t3
                                    wrapMode: Text.WordWrap
                                }

                                Text {
                                    Layout.fillWidth: true
                                    textFormat: Text.RichText
                                    text: "<a href=\"" + appRoot.genyleapWebsiteUrl + "\"><span style=\"color:#3a86ff;text-decoration:underline;\">"
                                          + appRoot.genyleapWebsiteUrl + "</span></a>"
                                    onLinkActivated: appRoot.openExternalLink(link, "Opened Genyleap website")
                                    color: Colors.textAccent
                                    font.family: FontSystem.getContentFontRegular.name
                                    font.pixelSize: Typography.t2
                                    wrapMode: Text.WrapAnywhere
                                }
                            }

                            Controls.Button {
                                Layout.alignment: Qt.AlignTop | Qt.AlignRight
                                text: "Copy"
                                onClicked: appRoot.copyToClipboard(appRoot.genyleapWebsiteUrl, "Website link copied")
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        radius: Metrics.innerRadius
                        color: Colors.backgroundItemActivated
                        border.width: 1
                        border.color: Colors.borderActivated
                        implicitHeight: supportRepoCard.implicitHeight + 24

                        RowLayout {
                            id: supportRepoCard
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                spacing: 4

                                Text {
                                    text: "Source Repository"
                                    color: Colors.textPrimary
                                    font.family: FontSystem.getTitleBoldFont.font.family
                                    font.pixelSize: Typography.t2
                                    font.bold: true
                                }

                                Text {
                                    text: "Main open source repository for RAAD."
                                    color: Colors.textSecondary
                                    font.family: FontSystem.getContentFontRegular.name
                                    font.pixelSize: Typography.t3
                                }

                                Text {
                                    Layout.fillWidth: true
                                    textFormat: Text.RichText
                                    text: "<a href=\"" + appRoot.projectRepositoryUrl + "\"><span style=\"color:#3a86ff;text-decoration:underline;\">"
                                          + appRoot.projectRepositoryUrl + "</span></a>"
                                    onLinkActivated: appRoot.openExternalLink(link, "Opened RAAD repository")
                                    color: Colors.textAccent
                                    font.family: FontSystem.getContentFontRegular.name
                                    font.pixelSize: Typography.t2
                                    wrapMode: Text.WrapAnywhere
                                }
                            }

                            Controls.Button {
                                Layout.alignment: Qt.AlignTop | Qt.AlignRight
                                text: "Copy"
                                onClicked: appRoot.copyToClipboard(appRoot.projectRepositoryUrl, "Repository link copied")
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        radius: Metrics.innerRadius
                        color: Colors.backgroundItemActivated
                        border.width: 1
                        border.color: Colors.borderActivated
                        implicitHeight: supportEmailCard.implicitHeight + 24

                        RowLayout {
                            id: supportEmailCard
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                spacing: 4

                                Text {
                                    text: "Support Email"
                                    color: Colors.textPrimary
                                    font.family: FontSystem.getTitleBoldFont.font.family
                                    font.pixelSize: Typography.t2
                                    font.bold: true
                                }

                                Text {
                                    text: "Direct support channel for project and token questions."
                                    color: Colors.textSecondary
                                    font.family: FontSystem.getContentFontRegular.name
                                    font.pixelSize: Typography.t3
                                    wrapMode: Text.WordWrap
                                }

                                Text {
                                    Layout.fillWidth: true
                                    textFormat: Text.RichText
                                    text: "<a href=\"mailto:" + appRoot.genyleapSupportEmail + "\"><span style=\"color:#3a86ff;text-decoration:underline;\">"
                                          + appRoot.genyleapSupportEmail + "</span></a>"
                                    onLinkActivated: appRoot.openExternalLink(link, "Opened support email")
                                    color: Colors.textAccent
                                    font.family: FontSystem.getContentFontRegular.name
                                    font.pixelSize: Typography.t2
                                    wrapMode: Text.WrapAnywhere
                                }
                            }

                            Controls.Button {
                                Layout.alignment: Qt.AlignTop | Qt.AlignRight
                                text: "Copy"
                                onClicked: appRoot.copyToClipboard(appRoot.genyleapSupportEmail, "Support email copied")
                            }
                        }
                    }
                }
            }

            Controls.GroupBox {
                title: "Developer Links"
                Layout.fillWidth: true
                implicitHeight: supportDeveloperLayout.implicitHeight + topPadding + bottomPadding

                ColumnLayout {
                    id: supportDeveloperLayout
                    width: parent.width
                    spacing: 10

                    Rectangle {
                        Layout.fillWidth: true
                        radius: Metrics.innerRadius
                        color: Colors.backgroundItemActivated
                        border.width: 1
                        border.color: Colors.borderActivated
                        implicitHeight: developerFarcasterCard.implicitHeight + 24

                        RowLayout {
                            id: developerFarcasterCard
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                spacing: 4

                                Text {
                                    text: "Farcaster"
                                    color: Colors.textPrimary
                                    font.family: FontSystem.getTitleBoldFont.font.family
                                    font.pixelSize: Typography.t2
                                    font.bold: true
                                }

                                Text {
                                    text: "Developer profile on Farcaster."
                                    color: Colors.textSecondary
                                    font.family: FontSystem.getContentFontRegular.name
                                    font.pixelSize: Typography.t3
                                }

                                Text {
                                    Layout.fillWidth: true
                                    textFormat: Text.RichText
                                    text: "<a href=\"" + appRoot.developerFarcasterUrl + "\"><span style=\"color:#3a86ff;text-decoration:underline;\">"
                                          + appRoot.developerFarcasterUrl + "</span></a>"
                                    onLinkActivated: appRoot.openExternalLink(link, "Opened Farcaster profile")
                                    color: Colors.textAccent
                                    font.family: FontSystem.getContentFontRegular.name
                                    font.pixelSize: Typography.t2
                                    wrapMode: Text.WrapAnywhere
                                }
                            }

                            Controls.Button {
                                Layout.alignment: Qt.AlignTop | Qt.AlignRight
                                text: "Copy"
                                onClicked: appRoot.copyToClipboard(appRoot.developerFarcasterUrl, "Farcaster link copied")
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        radius: Metrics.innerRadius
                        color: Colors.backgroundItemActivated
                        border.width: 1
                        border.color: Colors.borderActivated
                        implicitHeight: developerXCard.implicitHeight + 24

                        RowLayout {
                            id: developerXCard
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                spacing: 4

                                Text {
                                    text: "X"
                                    color: Colors.textPrimary
                                    font.family: FontSystem.getTitleBoldFont.font.family
                                    font.pixelSize: Typography.t2
                                    font.bold: true
                                }

                                Text {
                                    text: "@thecompez"
                                    color: Colors.textSecondary
                                    font.family: FontSystem.getContentFontRegular.name
                                    font.pixelSize: Typography.t3
                                }

                                Text {
                                    Layout.fillWidth: true
                                    textFormat: Text.RichText
                                    text: "<a href=\"" + appRoot.developerXUrl + "\"><span style=\"color:#3a86ff;text-decoration:underline;\">"
                                          + appRoot.developerXUrl + "</span></a>"
                                    onLinkActivated: appRoot.openExternalLink(link, "Opened X profile")
                                    color: Colors.textAccent
                                    font.family: FontSystem.getContentFontRegular.name
                                    font.pixelSize: Typography.t2
                                    wrapMode: Text.WrapAnywhere
                                }
                            }

                            Controls.Button {
                                Layout.alignment: Qt.AlignTop | Qt.AlignRight
                                text: "Copy"
                                onClicked: appRoot.copyToClipboard(appRoot.developerXUrl, "X link copied")
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        radius: Metrics.innerRadius
                        color: Colors.backgroundItemActivated
                        border.width: 1
                        border.color: Colors.borderActivated
                        implicitHeight: developerGithubCard.implicitHeight + 24

                        RowLayout {
                            id: developerGithubCard
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                spacing: 4

                                Text {
                                    text: "GitHub"
                                    color: Colors.textPrimary
                                    font.family: FontSystem.getTitleBoldFont.font.family
                                    font.pixelSize: Typography.t2
                                    font.bold: true
                                }

                                Text {
                                    text: "Developer account"
                                    color: Colors.textSecondary
                                    font.family: FontSystem.getContentFontRegular.name
                                    font.pixelSize: Typography.t3
                                }

                                Text {
                                    Layout.fillWidth: true
                                    textFormat: Text.RichText
                                    text: "<a href=\"" + appRoot.developerGithubUrl + "\"><span style=\"color:#3a86ff;text-decoration:underline;\">"
                                          + appRoot.developerGithubUrl + "</span></a>"
                                    onLinkActivated: appRoot.openExternalLink(link, "Opened GitHub profile")
                                    color: Colors.textAccent
                                    font.family: FontSystem.getContentFontRegular.name
                                    font.pixelSize: Typography.t2
                                    wrapMode: Text.WrapAnywhere
                                }
                            }

                            Controls.Button {
                                Layout.alignment: Qt.AlignTop | Qt.AlignRight
                                text: "Copy"
                                onClicked: appRoot.copyToClipboard(appRoot.developerGithubUrl, "GitHub link copied")
                            }
                        }
                    }
                }
            }
        }

        standardButtons: Dialog.Close
    }

    Controls.Dialog {
        id: licenseDialog
        width: Math.min(appRoot.width - 60, 860)
        height: 680
        title: "License & Open Source"
        type: "info"
        desc: "MIT License and source access"
        message: "RAAD is distributed under the MIT License. Review the repository and full license text below."

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 14

            Controls.GroupBox {
                title: "Open Source Links"
                Layout.fillWidth: true
                implicitHeight: licenseLinksLayout.implicitHeight + topPadding + bottomPadding

                ColumnLayout {
                    id: licenseLinksLayout
                    width: parent.width
                    spacing: 10

                    Rectangle {
                        Layout.fillWidth: true
                        radius: Metrics.innerRadius
                        color: Colors.backgroundItemActivated
                        border.width: 1
                        border.color: Colors.borderActivated
                        implicitHeight: licenseRepoCard.implicitHeight + 24

                        RowLayout {
                            id: licenseRepoCard
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                spacing: 4

                                Text {
                                    text: "Repository"
                                    color: Colors.textPrimary
                                    font.family: FontSystem.getTitleBoldFont.font.family
                                    font.pixelSize: Typography.t2
                                    font.bold: true
                                }

                                Text {
                                    text: "Main source repository for RAAD."
                                    color: Colors.textSecondary
                                    font.family: FontSystem.getContentFontRegular.name
                                    font.pixelSize: Typography.t3
                                }

                                Text {
                                    Layout.fillWidth: true
                                    textFormat: Text.RichText
                                    text: "<a href=\"" + appRoot.projectRepositoryUrl + "\"><span style=\"color:#3a86ff;text-decoration:underline;\">"
                                          + appRoot.projectRepositoryUrl + "</span></a>"
                                    onLinkActivated: appRoot.openExternalLink(link, "Opened RAAD repository")
                                    color: Colors.textAccent
                                    font.family: FontSystem.getContentFontRegular.name
                                    font.pixelSize: Typography.t2
                                    wrapMode: Text.WrapAnywhere
                                }
                            }

                            Controls.Button {
                                Layout.alignment: Qt.AlignTop | Qt.AlignRight
                                text: "Copy"
                                onClicked: appRoot.copyToClipboard(appRoot.projectRepositoryUrl, "Repository link copied")
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        radius: Metrics.innerRadius
                        color: Colors.backgroundItemActivated
                        border.width: 1
                        border.color: Colors.borderActivated
                        implicitHeight: licenseFileCard.implicitHeight + 24

                        RowLayout {
                            id: licenseFileCard
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                spacing: 4

                                Text {
                                    text: "License"
                                    color: Colors.textPrimary
                                    font.family: FontSystem.getTitleBoldFont.font.family
                                    font.pixelSize: Typography.t2
                                    font.bold: true
                                }

                                Text {
                                    text: "Published MIT license page in the repository."
                                    color: Colors.textSecondary
                                    font.family: FontSystem.getContentFontRegular.name
                                    font.pixelSize: Typography.t3
                                }

                                Text {
                                    Layout.fillWidth: true
                                    textFormat: Text.RichText
                                    text: "<a href=\"" + appRoot.projectLicenseUrl + "\"><span style=\"color:#3a86ff;text-decoration:underline;\">"
                                          + appRoot.projectLicenseUrl + "</span></a>"
                                    onLinkActivated: appRoot.openExternalLink(link, "Opened project license")
                                    color: Colors.textAccent
                                    font.family: FontSystem.getContentFontRegular.name
                                    font.pixelSize: Typography.t2
                                    wrapMode: Text.WrapAnywhere
                                }
                            }

                            Controls.Button {
                                Layout.alignment: Qt.AlignTop | Qt.AlignRight
                                text: "Copy"
                                onClicked: appRoot.copyToClipboard(appRoot.projectLicenseUrl, "License link copied")
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        radius: Metrics.innerRadius
                        color: Colors.backgroundItemActivated
                        border.width: 1
                        border.color: Colors.borderActivated
                        implicitHeight: licenseQtCard.implicitHeight + 24

                        RowLayout {
                            id: licenseQtCard
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                spacing: 4

                                Text {
                                    text: "Qt Open Source Framework"
                                    color: Colors.textPrimary
                                    font.family: FontSystem.getTitleBoldFont.font.family
                                    font.pixelSize: Typography.t2
                                    font.bold: true
                                }

                                Text {
                                    text: "RAAD is built with Qt " + Qt.version + ". Review the official Qt open source licensing page."
                                    color: Colors.textSecondary
                                    font.family: FontSystem.getContentFontRegular.name
                                    font.pixelSize: Typography.t3
                                    wrapMode: Text.WordWrap
                                }

                                Text {
                                    Layout.fillWidth: true
                                    textFormat: Text.RichText
                                    text: "<a href=\"" + appRoot.qtOpenSourceUrl + "\"><span style=\"color:#3a86ff;text-decoration:underline;\">"
                                          + appRoot.qtOpenSourceUrl + "</span></a>"
                                    onLinkActivated: appRoot.openExternalLink(link, "Opened Qt licensing page")
                                    color: Colors.textAccent
                                    font.family: FontSystem.getContentFontRegular.name
                                    font.pixelSize: Typography.t2
                                    wrapMode: Text.WrapAnywhere
                                }
                            }

                            Controls.Button {
                                Layout.alignment: Qt.AlignTop | Qt.AlignRight
                                text: "Copy"
                                onClicked: appRoot.copyToClipboard(appRoot.qtOpenSourceUrl, "Qt licensing link copied")
                            }
                        }
                    }
                }
            }

            Controls.GroupBox {
                title: "MIT License"
                Layout.fillWidth: true
                implicitHeight: licenseTextLayout.implicitHeight + topPadding + bottomPadding

                ColumnLayout {
                    id: licenseTextLayout
                    width: parent.width
                    spacing: 10

                    ScrollView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 320
                        clip: true
                        ScrollBar.vertical.policy: ScrollBar.AsNeeded

                        TextArea {
                            width: parent.width
                            readOnly: true
                            wrapMode: TextEdit.Wrap
                            text: appRoot.mitLicenseText
                            font.family: FontSystem.getContentFont.font.family
                            selectByMouse: true
                            background: null
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        Controls.Button {
                            text: "Copy License"
                            style: "success"
                            onClicked: appRoot.copyToClipboard(appRoot.mitLicenseText, "MIT license copied")
                        }
                        Item { Layout.fillWidth: true }
                    }
                }
            }
        }
        standardButtons: Dialog.Close

    }

    Controls.Dialog {
        id: donateDialog
        width: Math.min(appRoot.width - 60, 820)
        height: 520
        title: "Donate"
        type: "info"
        desc: "Support RAAD on Base and Ethereum MainNet"
        message: "Use the ERC20 donation address below on both supported networks."

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 14

            Rectangle {
                Layout.fillWidth: true
                radius: Metrics.cornerRadius
                color: Colors.backgroundItemActivated
                border.width: 1
                border.color: Colors.borderActivated
                implicitHeight: donateHeroLayout.implicitHeight + 28

                ColumnLayout {
                    id: donateHeroLayout
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    Text {
                        Layout.fillWidth: true
                        text: "Donation address"
                        color: Colors.textPrimary
                        font.family: FontSystem.getTitleBoldFont.font.family
                        font.pixelSize: Typography.h4
                        font.bold: true
                    }

                    Controls.TextField {
                        Layout.fillWidth: true
                        readOnly: true
                        text: appRoot.donationAddress
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            Layout.preferredWidth: 92
                            Layout.preferredHeight: 30
                            radius: 15
                            color: Colors.secondryBack
                            border.width: 1
                            border.color: Colors.secondry

                            Text {
                                anchors.centerIn: parent
                                text: "Base"
                                color: Colors.textPrimary
                                font.family: FontSystem.getTitleBoldFont.font.family
                                font.pixelSize: Typography.t3
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 156
                            Layout.preferredHeight: 30
                            radius: 15
                            color: Colors.warningBack
                            border.width: 1
                            border.color: Colors.warning

                            Text {
                                anchors.centerIn: parent
                                text: "Ethereum MainNet"
                                color: Colors.textPrimary
                                font.family: FontSystem.getTitleBoldFont.font.family
                                font.pixelSize: Typography.t3
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Controls.Button {
                            text: "Copy Address"
                            style: "success"
                            onClicked: appRoot.copyToClipboard(appRoot.donationAddress, "Donation address copied")
                        }
                    }
                }
            }

            Controls.GroupBox {
                title: "Explorer Links"
                Layout.fillWidth: true
                implicitHeight: donateAddressLayout.implicitHeight + topPadding + bottomPadding

                ColumnLayout {
                    id: donateAddressLayout
                    width: parent.width
                    spacing: 10

                    Rectangle {
                        Layout.fillWidth: true
                        radius: Metrics.innerRadius
                        color: Colors.backgroundItemActivated
                        border.width: 1
                        border.color: Colors.borderActivated
                        implicitHeight: donateBaseCard.implicitHeight + 24

                        RowLayout {
                            id: donateBaseCard
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                spacing: 4

                                Text {
                                    text: "Base"
                                    color: Colors.textPrimary
                                    font.family: FontSystem.getTitleBoldFont.font.family
                                    font.pixelSize: Typography.t2
                                    font.bold: true
                                }

                                Text {
                                    text: "Donation address on Base explorer."
                                    color: Colors.textSecondary
                                    font.family: FontSystem.getContentFontRegular.name
                                    font.pixelSize: Typography.t3
                                }

                                Text {
                                    Layout.fillWidth: true
                                    textFormat: Text.RichText
                                    text: "<a href=\"" + appRoot.donationBaseExplorerUrl + "\"><span style=\"color:#3a86ff;text-decoration:underline;\">"
                                          + appRoot.donationBaseExplorerUrl + "</span></a>"
                                    onLinkActivated: appRoot.openExternalLink(link, "Opened Base donation address")
                                    color: Colors.textAccent
                                    font.family: FontSystem.getContentFontRegular.name
                                    font.pixelSize: Typography.t2
                                    wrapMode: Text.WrapAnywhere
                                }
                            }

                            Controls.Button {
                                Layout.alignment: Qt.AlignTop | Qt.AlignRight
                                text: "Copy Link"
                                onClicked: appRoot.copyToClipboard(appRoot.donationBaseExplorerUrl, "Base explorer link copied")
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        radius: Metrics.innerRadius
                        color: Colors.backgroundItemActivated
                        border.width: 1
                        border.color: Colors.borderActivated
                        implicitHeight: donateMainCard.implicitHeight + 24

                        RowLayout {
                            id: donateMainCard
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                spacing: 4

                                Text {
                                    text: "Ethereum MainNet"
                                    color: Colors.textPrimary
                                    font.family: FontSystem.getTitleBoldFont.font.family
                                    font.pixelSize: Typography.t2
                                    font.bold: true
                                }

                                Text {
                                    text: "Same donation address on Ethereum mainnet."
                                    color: Colors.textSecondary
                                    font.family: FontSystem.getContentFontRegular.name
                                    font.pixelSize: Typography.t3
                                }

                                Text {
                                    Layout.fillWidth: true
                                    textFormat: Text.RichText
                                    text: "<a href=\"" + appRoot.donationMainnetExplorerUrl + "\"><span style=\"color:#3a86ff;text-decoration:underline;\">"
                                          + appRoot.donationMainnetExplorerUrl + "</span></a>"
                                    onLinkActivated: appRoot.openExternalLink(link, "Opened MainNet donation address")
                                    color: Colors.textAccent
                                    font.family: FontSystem.getContentFontRegular.name
                                    font.pixelSize: Typography.t2
                                    wrapMode: Text.WrapAnywhere
                                }
                            }

                            Controls.Button {
                                Layout.alignment: Qt.AlignTop | Qt.AlignRight
                                text: "Copy Link"
                                onClicked: appRoot.copyToClipboard(appRoot.donationMainnetExplorerUrl, "MainNet explorer link copied")
                            }
                        }
                    }
                }
            }
        }
        standardButtons: Dialog.Close

    }

    Controls.Dialog {
        id: tokenDialog
        width: Math.min(appRoot.width - 60, 880)
        height: 700
        title: "GenyToken"
        type: "info"
        desc: "Token " + appRoot.genyTokenSymbol
        message: appRoot.genyTokenDescription

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 14

            Rectangle {
                Layout.fillWidth: true
                radius: Metrics.cornerRadius
                gradient: LinearGradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Colors.secondryBack }
                    GradientStop { position: 1.0; color: Colors.successBack }
                }
                border.width: 1
                border.color: Colors.borderActivated
                implicitHeight: tokenHeroLayout.implicitHeight + 30

                RowLayout {
                    id: tokenHeroLayout
                    anchors.fill: parent
                    anchors.margins: 15
                    spacing: 16

                    Rectangle {
                        Layout.preferredWidth: 108
                        Layout.preferredHeight: 108
                        radius: 30
                        color: "#001309" //Colors.backgroundActivated
                        border.width: 1
                        border.color: Colors.borderActivated

                        Image {
                            id: genyTokenHeroImage
                            anchors.fill: parent
                            anchors.margins: 14
                            source: appRoot.genyTokenImageUrl
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            asynchronous: true
                            cache: true
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: genyTokenHeroImage.status !== Image.Ready
                            text: "$GENY"
                            color: Colors.textPrimary
                            font.family: FontSystem.getTitleBoldFont.font.family
                            font.pixelSize: Typography.t2
                            font.bold: true
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: 5

                        Text {
                            Layout.fillWidth: true
                            text: appRoot.genyTokenName + " (" + appRoot.genyTokenSymbol + ")"
                            color: Colors.textPrimary
                            font.family: FontSystem.getTitleBoldFont.font.family
                            font.pixelSize: Typography.h3
                            font.bold: true
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            Layout.fillWidth: true
                            text: appRoot.genyTokenDescription
                            color: Colors.textSecondary
                            font.family: FontSystem.getContentFontRegular.name
                            font.pixelSize: Typography.t2
                            wrapMode: Text.WordWrap
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Rectangle {
                                Layout.preferredWidth: 90
                                Layout.preferredHeight: 30
                                radius: 15
                                color: Colors.warningBack
                                border.width: 1
                                border.color: Colors.warning

                                Text {
                                    anchors.centerIn: parent
                                    text: "ERC20"
                                    color: Colors.textPrimary
                                    font.family: FontSystem.getTitleBoldFont.font.family
                                    font.pixelSize: Typography.t3
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 110
                                Layout.preferredHeight: 30
                                radius: 15
                                color: Colors.secondryBack
                                border.width: 1
                                border.color: Colors.secondry

                                Text {
                                    anchors.centerIn: parent
                                    text: "256M Supply"
                                    color: Colors.textPrimary
                                    font.family: FontSystem.getTitleBoldFont.font.family
                                    font.pixelSize: Typography.t3
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 100
                                Layout.preferredHeight: 30
                                radius: 15
                                color: Colors.successBack
                                border.width: 1
                                border.color: Colors.success

                                Text {
                                    anchors.centerIn: parent
                                    text: "18 Decimals"
                                    color: Colors.textPrimary
                                    font.family: FontSystem.getTitleBoldFont.font.family
                                    font.pixelSize: Typography.t3
                                }
                            }

                            Item { Layout.fillWidth: true }
                        }
                    }
                }
            }

            Controls.GroupBox {
                title: "Contract"
                Layout.fillWidth: true
                implicitHeight: tokenContractLayout.implicitHeight + topPadding + bottomPadding

                ColumnLayout {
                    id: tokenContractLayout
                    width: parent.width
                    spacing: 10

                    Controls.TextField {
                        Layout.fillWidth: true
                        readOnly: true
                        text: appRoot.genyTokenContractAddress
                    }

                    Text {
                        Layout.fillWidth: true
                        textFormat: Text.RichText
                        text: "<a href=\"" + appRoot.genyTokenBaseExplorerUrl + "\"><span style=\"color:#3a86ff;text-decoration:underline;\">"
                              + appRoot.genyTokenBaseExplorerUrl + "</span></a>"
                        onLinkActivated: appRoot.openExternalLink(link, "Opened GENY explorer")
                        color: Colors.textAccent
                        font.family: FontSystem.getContentFontRegular.name
                        font.pixelSize: Typography.t2
                        wrapMode: Text.WrapAnywhere
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        Controls.Button {
                            text: "Copy Contract"
                            style: "success"
                            onClicked: appRoot.copyToClipboard(appRoot.genyTokenContractAddress, "GENY contract copied")
                        }
                        Controls.Button {
                            text: "Copy Explorer"
                            onClicked: appRoot.copyToClipboard(appRoot.genyTokenBaseExplorerUrl, "GENY explorer link copied")
                        }
                        Item { Layout.fillWidth: true }
                    }
                }
            }

            Controls.GroupBox {
                title: "Community & Support"
                Layout.fillWidth: true
                implicitHeight: tokenCommunityLayout.implicitHeight + topPadding + bottomPadding

                ColumnLayout {
                    id: tokenCommunityLayout
                    width: parent.width
                    spacing: 10

                    Rectangle {
                        Layout.fillWidth: true
                        radius: Metrics.innerRadius
                        color: Colors.backgroundItemActivated
                        border.width: 1
                        border.color: Colors.borderActivated
                        implicitHeight: tokenWebsiteCard.implicitHeight + 24

                        RowLayout {
                            id: tokenWebsiteCard
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                spacing: 4

                                Text {
                                    text: "Website"
                                    color: Colors.textPrimary
                                    font.family: FontSystem.getTitleBoldFont.font.family
                                    font.pixelSize: Typography.t2
                                    font.bold: true
                                }

                                Text {
                                    Layout.fillWidth: true
                                    textFormat: Text.RichText
                                    text: "<a href=\"" + appRoot.genyleapWebsiteUrl + "\"><span style=\"color:#3a86ff;text-decoration:underline;\">"
                                          + appRoot.genyleapWebsiteUrl + "</span></a>"
                                    onLinkActivated: appRoot.openExternalLink(link, "Opened Genyleap website")
                                    color: Colors.textAccent
                                    font.family: FontSystem.getContentFontRegular.name
                                    font.pixelSize: Typography.t2
                                    wrapMode: Text.WrapAnywhere
                                }
                            }

                            Controls.Button {
                                Layout.alignment: Qt.AlignTop | Qt.AlignRight
                                text: "Copy"
                                onClicked: appRoot.copyToClipboard(appRoot.genyleapWebsiteUrl, "Website link copied")
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        radius: Metrics.innerRadius
                        color: Colors.backgroundItemActivated
                        border.width: 1
                        border.color: Colors.borderActivated
                        implicitHeight: tokenSocialsCard.implicitHeight + 24

                        ColumnLayout {
                            id: tokenSocialsCard
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8

                            Text {
                                text: "Socials"
                                color: Colors.textPrimary
                                font.family: FontSystem.getTitleBoldFont.font.family
                                font.pixelSize: Typography.t2
                                font.bold: true
                            }

                            RowLayout {
                                Layout.fillWidth: true

                                Controls.Button {
                                    text: "Copy X"
                                    onClicked: appRoot.copyToClipboard(appRoot.genyTokenXUrl, "GENY X link copied")
                                }
                                Controls.Button {
                                    text: "Telegram"
                                    onClicked: appRoot.copyToClipboard(appRoot.genyTokenTelegramUrl, "GENY Telegram link copied")
                                }
                                Item { Layout.fillWidth: true }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        radius: Metrics.innerRadius
                        color: Colors.backgroundItemActivated
                        border.width: 1
                        border.color: Colors.borderActivated
                        implicitHeight: tokenSupportCard.implicitHeight + 24

                        RowLayout {
                            id: tokenSupportCard
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                spacing: 4

                                Text {
                                    text: "Support"
                                    color: Colors.textPrimary
                                    font.family: FontSystem.getTitleBoldFont.font.family
                                    font.pixelSize: Typography.t2
                                    font.bold: true
                                }

                                Text {
                                    Layout.fillWidth: true
                                    textFormat: Text.RichText
                                    text: "<a href=\"" + appRoot.genyleapSupportUrl + "\"><span style=\"color:#3a86ff;text-decoration:underline;\">"
                                          + appRoot.genyleapSupportUrl + "</span></a>"
                                    onLinkActivated: appRoot.openExternalLink(link, "Opened GENY support")
                                    color: Colors.textAccent
                                    font.family: FontSystem.getContentFontRegular.name
                                    font.pixelSize: Typography.t2
                                    wrapMode: Text.WrapAnywhere
                                }
                            }

                            Controls.Button {
                                Layout.alignment: Qt.AlignTop | Qt.AlignRight
                                text: "Copy"
                                onClicked: appRoot.copyToClipboard(appRoot.genyleapSupportUrl, "GENY support link copied")
                            }
                        }
                    }
                }
            }
        }
        standardButtons: Dialog.Close

    }

    QQD.FileDialog {
        id: addDialogFileDialog
        title: "Choose URL or torrent file"
        fileMode: QQD.FileDialog.OpenFile
        nameFilters: ["Torrent files (*.torrent)", "All files (*)"]
        onAccepted: {
            const raw = selectedFile.toString()
            addDialogUrlField.text = raw
        }
    }

    QQD.FolderDialog {
        id: addDialogFolderDialog
        title: "Choose destination folder"
        onAccepted: {
            const raw = selectedFolder.toString()
            addDialogPathField.text = raw.startsWith("file://") ? decodeURIComponent(raw.slice(7)) : raw
        }
    }

    QQD.FolderDialog {
        id: categoryFolderDialog
        title: "Choose category folder"
        onAccepted: {
            const raw = selectedFolder.toString()
            queueDialogCategoryFolderField.text = raw.startsWith("file://") ? decodeURIComponent(raw.slice(7)) : raw
        }
    }

    Controls.Dialog {
        id: addUrlPopup
        title: "Add download"
        type: "add"


        standardButtons: Dialog.Cancel | Dialog.Ok

        parent: Overlay.overlay
        width: Math.min(appRoot.width - 40, 920)
        implicitHeight: addDialogLayout.implicitHeight * 2.1
        height: Math.min(appRoot.height, implicitHeight)
        x: Math.round((parent ? parent.width - width : appRoot.width - width) / 2)
        y: Math.round((parent ? parent.height - height : appRoot.height - height) / 2)

        okTextOverride: "Add"

        GroupBox {
            title: "Add new file"
            Layout.fillWidth: true
            Layout.preferredHeight: addDialogLayout.implicitHeight + 64

            ColumnLayout {
                id: addDialogLayout
                anchors.fill: parent
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Controls.TextField {
                        id: addDialogUrlField
                        Layout.fillWidth: true
                        placeholderText: "https://example.com/file.zip"
                        onTextChanged: if (addDialogErrorLabel.text.length > 0) addDialogErrorLabel.text = ""
                    }

                    Controls.Button {
                        text: "Browse..."
                        Layout.preferredWidth: 130
                        Layout.minimumWidth: 130
                        isDefault: false
                        onClicked: addDialogFileDialog.open()
                    }
                }

                Controls.Label {
                    id: addDialogErrorLabel
                    Layout.fillWidth: true
                    color: Colors.textError
                    visible: text.length > 0
                    wrapMode: Text.Wrap
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Controls.TextField {
                        id: addDialogPathField
                        Layout.fillWidth: true
                        text: documentsFolder
                        placeholderText: "Destination folder"
                    }

                    Controls.Button {
                        text: "Destination..."
                        Layout.preferredWidth: 130
                        Layout.minimumWidth: 130
                        isDefault: false
                        onClicked: addDialogFolderDialog.open()
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 15
                    // columns: 5

                    RowLayout {
                        Layout.fillWidth: true
                        Controls.Label {
                            text: "Queue"
                            Layout.alignment: Qt.AlignRight
                        }
                        Controls.ComboBox {
                            id: addDialogQueueCombo
                            width: 170
                            Layout.fillWidth: false
                            model: downloadManager.queueNames
                        }

                        Controls.Label {
                            text: "Category"
                            Layout.fillWidth: false
                            Layout.alignment: Qt.AlignRight

                        }
                        Controls.ComboBox {
                            id: addDialogCategoryCombo
                            width: 220
                            Layout.fillWidth: false
                            model: downloadManager.categoryNames()
                        }

                        Controls.Label {
                            text: "Segments"
                        }
                        Controls.SpinBox {
                            id: addDialogSegmentsSpin
                            width: 130
                            from: 1
                            to: 64
                            value: 8
                        }

                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Controls.Switch {
                            id: addDialogPausedSwitch
                            text: "Start paused"
                        }
                        Controls.Switch {
                            id: addDialogAdaptiveSwitch
                            text: "Adaptive segments"
                            checked: false
                        }

                        Rectangle{
                            Layout.fillWidth: true
                            Layout.preferredHeight: 48
                            color: Colors.warningBack
                            radius: Metrics.innerRadius

                            Controls.Text {
                                anchors.fill: parent
                                anchors.margins: 10
                                wrapMode: Text.WordWrap
                                color: Colors.textPrimary
                                textFormat: Text.AutoText
                                text: "Adaptive note: when <strong>Adaptive Segment Controller</strong> is <strong>ON</strong>, segment count may change dynamically during download. When OFF, segment count stays fixed to your configured value."
                                font.pixelSize: Typography.t3
                                maximumLineCount: 2
                                elide: Text.ElideLeft
                                opacity: 0.7
                            }
                        }

                    }
                }



                // RowLayout {
                //     Layout.fillWidth: true
                //     Item { Layout.fillWidth: true }
                //     Controls.Button {
                //         text: "Cancel"
                //         Layout.preferredWidth: 140
                //         Layout.minimumWidth: 140
                //         onClicked: addUrlPopup.close()
                //     }
                //     Controls.Button {
                //         text: "OK"
                //         Layout.preferredWidth: 140
                //         Layout.minimumWidth: 140
                //         enabled: addDialogUrlField.text.trim().length > 0
                //         onClicked: {
                //             addDialogErrorLabel.text = ""
                //             if (appRoot.isTorrentLikeInput(addDialogUrlField.text)) {
                //                 addDialogErrorLabel.text = "Torrent/magnet is not supported in backend yet. Use an HTTP/HTTPS/FTP URL."
                //                 return
                //             }
                //             const added = appRoot.submitDownload(
                //                             addDialogUrlField.text,
                //                             addDialogPathField.text,
                //                             addDialogQueueCombo.currentText,
                //                             addDialogCategoryCombo.currentText,
                //                             addDialogPausedSwitch.checked,
                //                             addDialogSegmentsSpin.value,
                //                             addDialogAdaptiveSwitch.checked
                //                             )
                //             if (!added) {
                //                 return
                //             }

                //             appRoot.addDefaultOutputPath = addDialogPathField.text.trim()
                //             appRoot.addDefaultQueue = addDialogQueueCombo.currentText
                //             appRoot.addDefaultCategory = addDialogCategoryCombo.currentText
                //             appRoot.addDefaultSegments = addDialogSegmentsSpin.value
                //             appRoot.addDefaultAdaptive = addDialogAdaptiveSwitch.checked
                //             appRoot.addDefaultStartPaused = addDialogPausedSwitch.checked

                //             addDialogUrlField.text = ""
                //             addUrlPopup.close()
                //         }
                //     }
                // }
            }

        }
        onAccepted: {
            addDialogErrorLabel.text = ""
            if (appRoot.isTorrentLikeInput(addDialogUrlField.text)) {
                addDialogErrorLabel.text = "Torrent/magnet is not supported in backend yet. Use an HTTP/HTTPS/FTP URL."
                return
            }
            const added = appRoot.submitDownload(
                            addDialogUrlField.text,
                            addDialogPathField.text,
                            addDialogQueueCombo.currentText,
                            addDialogCategoryCombo.currentText,
                            addDialogPausedSwitch.checked,
                            addDialogSegmentsSpin.value,
                            addDialogAdaptiveSwitch.checked
                            )
            if (!added) {
                return
            }

            appRoot.addDefaultOutputPath = addDialogPathField.text.trim()
            appRoot.addDefaultQueue = addDialogQueueCombo.currentText
            appRoot.addDefaultCategory = addDialogCategoryCombo.currentText
            appRoot.addDefaultSegments = addDialogSegmentsSpin.value
            appRoot.addDefaultAdaptive = addDialogAdaptiveSwitch.checked
            appRoot.addDefaultStartPaused = addDialogPausedSwitch.checked

            addDialogUrlField.text = ""
            addUrlPopup.close()
        }


    }

    Drawer {
        id: configurationDialog
        edge: appRootObjects.isLeftToRight ? Qt.RightEdge : Qt.LeftEdge
        width: Math.min(appRoot.width, Math.max(380, Math.min(appRoot.width * 0.62, 560)))
        height: appRoot.height
        modal: true
        focus: true
        interactive: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            topLeftRadius: appRootObjects.isLeftToRight ? Metrics.outerRadius : 0
            bottomLeftRadius: appRootObjects.isLeftToRight ? Metrics.outerRadius : 0
            topRightRadius: appRootObjects.isLeftToRight ? 0 : Metrics.outerRadius
            bottomRightRadius: appRootObjects.isLeftToRight ? 0 : Metrics.outerRadius
            color: Colors.backgroundActivated
            border.width: 1
            border.color: Colors.borderActivated
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                Controls.Label {
                    text: "Configuration"
                    font.pixelSize: Typography.h3
                    font.bold: true
                }
                Item { Layout.fillWidth: true }
            }

            Controls.TabBar {
                id: configurationTabs
                Layout.fillWidth: true
                currentIndex: appRoot.configurationTabIndex
                onCurrentIndexChanged: appRoot.configurationTabIndex = currentIndex

                Controls.TabButton { text: "General" }
                Controls.TabButton { text: "Queues" }
                Controls.TabButton { text: "Network" }
                Controls.TabButton { text: "Updates" }
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: configurationTabs.currentIndex

                ScrollView {
                    id: appearanceConfigView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    ColumnLayout {
                        width: Math.max(320, appearanceConfigView.availableWidth)
                        spacing: 12

                        Controls.GroupBox {
                            title: "General"
                            Layout.fillWidth: true
                            implicitHeight: appearanceConfigLayout.implicitHeight + topPadding + bottomPadding

                            GridLayout {
                                id: appearanceConfigLayout
                                width: parent.width
                                Layout.fillWidth: true
                                columns: 2
                                columnSpacing: 12
                                rowSpacing: 8

                                Controls.Label { text: "Theme" }
                                Controls.ComboBox {
                                    Layout.preferredWidth: 220
                                    model: appRoot.themeOptions
                                    currentIndex: appRoot.themeMode
                                    onCurrentIndexChanged: {
                                        if (currentIndex >= 0)
                                            appRoot.themeMode = currentIndex
                                    }
                                }

                                Controls.Label {
                                    Layout.columnSpan: 2
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                    text: "System follows the OS appearance. Dark and Light force the application theme."
                                }
                            }
                        }

                        Controls.GroupBox {
                            title: "Restore Defaults"
                            Layout.fillWidth: true
                            implicitHeight: generalResetLayout.implicitHeight + topPadding + bottomPadding

                            ColumnLayout {
                                id: generalResetLayout
                                width: parent.width
                                spacing: 10

                                Controls.Label {
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                    color: Colors.textMuted
                                    text: "Restore RAAD defaults and clear persisted session/configuration state without deleting downloaded files."
                                }

                                RowLayout {
                                    Layout.fillWidth: true

                                    Controls.Button {
                                        text: "Restore All"
                                        style: "danger"
                                        onClicked: resetSettingsDialog.open()
                                    }

                                    Item { Layout.fillWidth: true }
                                }
                            }
                        }
                    }
                }

                ScrollView {
                    id: queueConfigView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    ColumnLayout {
                        width: Math.max(320, queueConfigView.availableWidth)
                        spacing: 12

                        Controls.GroupBox {
                            title: "Queue Configuration"
                            Layout.fillWidth: true
                            implicitHeight: queueConfigLayout.implicitHeight + topPadding + bottomPadding

                            ColumnLayout {
                                id: queueConfigLayout
                                width: parent.width
                                spacing: 10

                                RowLayout {
                                    Layout.fillWidth: true
                                    Controls.ComboBox {
                                        id: queueDialogQueueCombo
                                        Layout.preferredWidth: 260
                                        model: downloadManager.queueNames
                                        currentIndex: Math.max(0, downloadManager.queueNames.indexOf(appRoot.queueEditorName))
                                        onActivated: {
                                            appRoot.queueEditorName = currentText
                                            appRoot.loadQueueEditor()
                                        }
                                    }
                                    Item { Layout.fillWidth: true }
                                    Controls.Button {
                                        text: "Reload"
                                        onClicked: {
                                            const q = queueDialogQueueCombo.currentText
                                            if (!q || q.length === 0) return
                                            queueDialogMaxConcurrent.value = downloadManager.queueMaxConcurrent(q)
                                            queueDialogMaxSpeed.value = Math.round(downloadManager.queueMaxSpeed(q) / (1024 * 1024))
                                            queueDialogSchedule.checked = downloadManager.queueScheduleEnabled(q)
                                            queueDialogStart.value = downloadManager.queueScheduleStartMinutes(q)
                                            queueDialogEnd.value = downloadManager.queueScheduleEndMinutes(q)
                                            queueDialogQuota.checked = downloadManager.queueQuotaEnabled(q)
                                            queueDialogQuotaBytes.value = Math.round(downloadManager.queueQuotaBytes(q) / (1024 * 1024 * 1024))
                                        }
                                    }
                                    Controls.Button {
                                        text: "Apply Policy"
                                        onClicked: {
                                            const q = queueDialogQueueCombo.currentText
                                            if (!q || q.length === 0) return
                                            downloadManager.setQueueMaxConcurrent(q, queueDialogMaxConcurrent.value)
                                            downloadManager.setQueueMaxSpeed(q, queueDialogMaxSpeed.value * 1024 * 1024)
                                            downloadManager.setQueueScheduleEnabled(q, queueDialogSchedule.checked)
                                            downloadManager.setQueueScheduleStartMinutes(q, queueDialogStart.value)
                                            downloadManager.setQueueScheduleEndMinutes(q, queueDialogEnd.value)
                                            downloadManager.setQueueQuotaEnabled(q, queueDialogQuota.checked)
                                            downloadManager.setQueueQuotaBytes(q, queueDialogQuotaBytes.value * 1024 * 1024 * 1024)
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Controls.TextField {
                                        id: queueDialogNewQueueField
                                        Layout.fillWidth: true
                                        placeholderText: "New queue name"
                                    }
                                    Controls.Button {
                                        text: "Create"
                                        enabled: queueDialogNewQueueField.text.trim().length > 0
                                        onClicked: {
                                            if (appRoot.createQueueFromEditor(queueDialogNewQueueField.text.trim())) {
                                                queueDialogNewQueueField.text = ""
                                                queueDialogQueueCombo.currentIndex = Math.max(0, downloadManager.queueNames.indexOf(appRoot.queueEditorName))
                                            }
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Controls.TextField {
                                        id: queueDialogRenameQueueField
                                        Layout.fillWidth: true
                                        placeholderText: "Rename selected queue"
                                    }
                                    Controls.Button {
                                        text: "Rename"
                                        enabled: appRoot.queueEditorName.length > 0 && queueDialogRenameQueueField.text.trim().length > 0
                                        onClicked: {
                                            if (appRoot.renameCurrentQueueTo(queueDialogRenameQueueField.text.trim())) {
                                                queueDialogRenameQueueField.text = ""
                                                queueDialogQueueCombo.currentIndex = Math.max(0, downloadManager.queueNames.indexOf(appRoot.queueEditorName))
                                            }
                                        }
                                    }
                                    Controls.Button {
                                        text: "Remove"
                                        enabled: appRoot.queueEditorName.length > 0 && appRoot.queueEditorName !== downloadManager.defaultQueueName()
                                        onClicked: {
                                            if (appRoot.removeCurrentQueue()) {
                                                queueDialogQueueCombo.currentIndex = Math.max(0, downloadManager.queueNames.indexOf(appRoot.queueEditorName))
                                            }
                                        }
                                    }
                                }

                                Controls.Label {
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                    text: "Queues are custom download lanes for scheduling, routing, and per-queue limits. 'General' is the default queue. Entries like 'Test' are just user-created queues saved in the session. Use Create, Rename, and Remove here to manage them."
                                    color: Colors.textMuted
                                }

                                GridLayout {
                                    Layout.fillWidth: true
                                    columns: 2
                                    columnSpacing: 12
                                    rowSpacing: 8

                                    Controls.Label { text: "Max concurrent" }
                                    Controls.SpinBox { id: queueDialogMaxConcurrent; from: 1; to: 64; value: 2 }
                                    Controls.Label { text: "Queue speed (MB/s)" }
                                    Controls.SpinBox { id: queueDialogMaxSpeed; from: 0; to: 4096; value: 0 }
                                    Controls.Label { text: "Enable schedule" }
                                    Controls.Switch { id: queueDialogSchedule }
                                    Controls.Label { text: "Start minute" }
                                    Controls.SpinBox { id: queueDialogStart; from: 0; to: 1439; value: 0 }
                                    Controls.Label { text: "End minute" }
                                    Controls.SpinBox { id: queueDialogEnd; from: 0; to: 1439; value: 0 }
                                    Controls.Label { text: "Enable quota" }
                                    Controls.Switch { id: queueDialogQuota }
                                    Controls.Label { text: "Quota (GB/day)" }
                                    Controls.SpinBox { id: queueDialogQuotaBytes; from: 0; to: 100000; value: 0 }
                                }
                            }
                        }

                        Controls.GroupBox {
                            title: "Category Routing"
                            Layout.fillWidth: true
                            implicitHeight: categoryRoutingLayout.implicitHeight + topPadding + bottomPadding

                            ColumnLayout {
                                id: categoryRoutingLayout
                                width: parent.width
                                spacing: 10

                                RowLayout {
                                    Layout.fillWidth: true
                                    Controls.Label {
                                        text: "Category"
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                    Controls.ComboBox {
                                        id: queueDialogCategoryCombo
                                        Layout.preferredWidth: 220
                                        model: downloadManager.categoryNames()
                                        onActivated: {
                                            queueDialogCategoryFolderField.text = downloadManager.categoryFolder(currentText)
                                        }
                                        Component.onCompleted: {
                                            if (model.length > 0) {
                                                currentIndex = 0
                                                queueDialogCategoryFolderField.text = downloadManager.categoryFolder(currentText)
                                            }
                                        }
                                    }
                                    Item { Layout.fillWidth: true }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Controls.TextField {
                                        id: queueDialogCategoryFolderField
                                        Layout.fillWidth: true
                                        placeholderText: "Optional custom folder for selected category"
                                    }
                                    Controls.Button {
                                        text: "Browse..."
                                        onClicked: categoryFolderDialog.open()
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Controls.Label {
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                        text: "Map a category to a destination folder. Files detected in that category will default to this folder."
                                        color: Colors.textMuted
                                    }
                                    Controls.Button {
                                        text: "Apply"
                                        enabled: queueDialogCategoryCombo.currentText.length > 0
                                        onClicked: {
                                            downloadManager.setCategoryFolder(
                                                        queueDialogCategoryCombo.currentText,
                                                        queueDialogCategoryFolderField.text.trim())
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                ScrollView {
                    id: networkConfigView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    ColumnLayout {
                        width: Math.max(320, networkConfigView.availableWidth)
                        spacing: 12

                        Controls.GroupBox {
                            title: "Network Settings"
                            Layout.fillWidth: true
                            implicitHeight: networkSettingsLayout.implicitHeight + topPadding + bottomPadding

                            GridLayout {
                                id: networkSettingsLayout
                                width: parent.width
                                columns: 2
                                columnSpacing: 12
                                rowSpacing: 8

                                Controls.Label { text: "User-Agent" }
                                Controls.TextField { Layout.fillWidth: true; text: downloadManager.defaultUserAgent; onEditingFinished: downloadManager.defaultUserAgent = text }
                                Controls.Label { text: "Proxy host" }
                                Controls.TextField { Layout.fillWidth: true; text: downloadManager.defaultProxyHost; onEditingFinished: downloadManager.defaultProxyHost = text }
                                Controls.Label { text: "Proxy port" }
                                Controls.SpinBox { Layout.preferredWidth: 180; from: 0; to: 65535; value: downloadManager.defaultProxyPort; onValueModified: downloadManager.defaultProxyPort = value }
                                Controls.Label { text: "Proxy user" }
                                Controls.TextField { Layout.fillWidth: true; text: downloadManager.defaultProxyUser; onEditingFinished: downloadManager.defaultProxyUser = text }
                                Controls.Label { text: "Proxy password" }
                                Controls.TextField { Layout.fillWidth: true; echoMode: TextInput.Password; text: downloadManager.defaultProxyPassword; onEditingFinished: downloadManager.defaultProxyPassword = text }
                                Controls.Label { text: "Allow insecure SSL" }
                                Controls.Switch { checked: downloadManager.defaultAllowInsecureSsl; onToggled: downloadManager.defaultAllowInsecureSsl = checked }
                                Controls.Label { text: "Per-host concurrent" }
                                Controls.SpinBox { from: 1; to: 64; value: downloadManager.perHostMaxConcurrent; onValueModified: downloadManager.perHostMaxConcurrent = value }
                            }
                        }

                        Controls.GroupBox {
                            title: "URL Probe"
                            Layout.fillWidth: true
                            implicitHeight: networkProbeLayout.implicitHeight + topPadding + bottomPadding

                            ColumnLayout {
                                id: networkProbeLayout
                                width: parent.width
                                spacing: 10

                                Controls.Label {
                                    Layout.fillWidth: true
                                    text: "Test a URL with the current network configuration."
                                    color: Colors.textMuted
                                    wrapMode: Text.WordWrap
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    Controls.TextField { id: networkProbeUrl; Layout.fillWidth: true; placeholderText: "https://example.com/file.zip" }
                                    Controls.Button {
                                        text: downloadManager.networkTestRunning ? "Testing..." : "Run Test"
                                        enabled: !downloadManager.networkTestRunning && networkProbeUrl.text.trim().length > 0
                                        onClicked: downloadManager.testUrl(networkProbeUrl.text.trim())
                                    }
                                }
                                Controls.Label { Layout.fillWidth: true; text: downloadManager.networkTestMessage; wrapMode: Text.Wrap }
                            }
                        }
                    }
                }

                ScrollView {
                    id: updatesConfigView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    ColumnLayout {
                        width: Math.max(320, updatesConfigView.availableWidth)
                        spacing: 12

                        Controls.GroupBox {
                            title: "Update Settings"
                            Layout.fillWidth: true
                            implicitHeight: updatesConfigLayout.implicitHeight + topPadding + bottomPadding

                            ColumnLayout {
                                id: updatesConfigLayout
                                width: parent.width
                                spacing: 10

                                RowLayout {
                                    Controls.Label { text: "Current" }
                                    Controls.Label { text: updateClient.currentVersion }
                                    Item { Layout.fillWidth: true }
                                    Controls.Label { text: "Latest" }
                                    Controls.Label { text: updateClient.latestVersion.length > 0 ? updateClient.latestVersion : "--" }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Controls.Button { text: "Check Now"; onClicked: updateClient.checkNow() }
                                    Controls.Button { text: "Download"; enabled: updateClient.updateAvailable; onClicked: updateClient.downloadUpdate() }
                                    Controls.Button { text: "Install"; enabled: updateClient.downloadReady; onClicked: updateClient.installUpdate() }
                                }

                                Controls.ProgressBar {
                                    Layout.fillWidth: true
                                    value: Math.max(0.0, Math.min(1.0, updateClient.downloadProgress))
                                    indeterminate: updateClient.status.toLowerCase().indexOf("downloading") >= 0
                                                   && updateClient.downloadProgress <= 0
                                }

                                Controls.Label { Layout.fillWidth: true; text: "Status: " + updateClient.status }
                                Controls.Label {
                                    Layout.fillWidth: true
                                    visible: updateClient.lastError.length > 0
                                    color: Colors.error
                                    text: updateClient.lastError.length > 0 ? ("Error: " + updateClient.lastError) : ""
                                    wrapMode: Text.Wrap
                                }
                                TextArea {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 220
                                    readOnly: true
                                    text: updateClient.releaseNotes
                                    placeholderText: "Release notes"
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                Controls.Button {
                    text: "Close"
                    onClicked: configurationDialog.close()
                }
            }
        }
    }

    Shortcut {
        sequence: "Ctrl+N"
        context: Qt.ApplicationShortcut
        onActivated: {
            appRoot.pageIndex = 0
            appRoot.openAddUrlDialog()
        }
    }

    Shortcut { sequence: "Ctrl+I"; context: Qt.ApplicationShortcut; onActivated: importDialog.open() }
    Shortcut { sequence: "Ctrl+E"; context: Qt.ApplicationShortcut; onActivated: exportDialog.open() }
    Shortcut { sequence: "Ctrl+Q"; context: Qt.ApplicationShortcut; onActivated: Qt.quit() }
    Shortcut { sequence: "Ctrl+Shift+P"; context: Qt.ApplicationShortcut; onActivated: downloadManager.pauseAll() }
    Shortcut { sequence: "Ctrl+Shift+R"; context: Qt.ApplicationShortcut; onActivated: downloadManager.resumeAll() }
    Shortcut { sequence: "Ctrl+Shift+T"; context: Qt.ApplicationShortcut; onActivated: downloadManager.retryFailed() }
    Shortcut { sequence: "Ctrl+Shift+X"; context: Qt.ApplicationShortcut; onActivated: downloadManager.cancelAll() }

    Component.onCompleted: {

        AppGlobals.appPalette = palette
        AppGlobals.appWindow = appRoot
        AppGlobals.rtl = appRootObjects.isLeftToRight ? false : true

        pageIndex = 0
        queueFilter = uiSettings.savedQueueFilter
        statusFilter = uiSettings.savedStatusFilter
        categoryFilter = uiSettings.savedCategoryFilter
        sortIndex = uiSettings.savedSortIndex
        sortAscending = uiSettings.savedSortAscending
        downloadsViewMode = uiSettings.savedDownloadsViewMode === 1 ? 1 : 0
        themeMode = (uiSettings.savedThemeMode >= Colors.modeSystem && uiSettings.savedThemeMode <= Colors.modeLight)
                ? uiSettings.savedThemeMode
                : Colors.modeSystem
        Colors.mode = themeMode
        appRootObjects.isDarkMode = !Colors.lightMode
        addDefaultOutputPath = documentsFolder
        if (downloadManager.queueNames.length > 0) {
            addDefaultQueue = downloadManager.queueNames[0]
        }
        if (downloadManager.categoryNames().length > 0) {
            addDefaultCategory = downloadManager.categoryNames()[0]
        }
        appRoot.applySort()
        appRoot.rebuildDownloadTableRows()

        if (downloadManager.queueNames.length > 0) {
            queueEditorName = downloadManager.queueNames[0]
            appRoot.loadQueueEditor()
        }
    }

    onPageIndexChanged: uiSettings.savedPageIndex = pageIndex
    onQueueFilterChanged: {
        uiSettings.savedQueueFilter = queueFilter
        appRoot.scheduleRebuildDownloadTableRows()
    }
    onStatusFilterChanged: {
        uiSettings.savedStatusFilter = statusFilter
        appRoot.scheduleRebuildDownloadTableRows()
    }
    onCategoryFilterChanged: {
        uiSettings.savedCategoryFilter = categoryFilter
        appRoot.scheduleRebuildDownloadTableRows()
    }
    onSortIndexChanged: {
        uiSettings.savedSortIndex = sortIndex
        appRoot.applySort()
        appRoot.scheduleRebuildDownloadTableRows()
    }
    onSortAscendingChanged: {
        uiSettings.savedSortAscending = sortAscending
        appRoot.applySort()
    }
    onDownloadsViewModeChanged: uiSettings.savedDownloadsViewMode = downloadsViewMode === 1 ? 1 : 0
    onThemeModeChanged: {
        const mode = Math.max(Colors.modeSystem, Math.min(Colors.modeLight, themeMode))
        if (themeMode !== mode) {
            themeMode = mode
            return
        }
        Colors.mode = mode
        uiSettings.savedThemeMode = mode
        appRootObjects.isDarkMode = !Colors.lightMode
    }
    onSearchTextChanged: appRoot.scheduleRebuildDownloadTableRows()
    onCheckedTaskRowsChanged: appRoot.scheduleRebuildDownloadTableRows()

    Timer {
        id: rebuildTableTimer
        interval: 80
        repeat: false
        onTriggered: appRoot.rebuildDownloadTableRows()
    }

    Connections {
        target: downloadManager

        function onQueuesChanged() {
            if (downloadManager.queueNames.length === 0) {
                queueEditorName = ""
                addDefaultQueue = "General"
                selectedQueue = ""
                queueFilter = "All Queues"
                return
            }
            if (queueEditorName.length === 0 || downloadManager.queueNames.indexOf(queueEditorName) < 0) {
                queueEditorName = downloadManager.queueNames[0]
            }
            if (addDefaultQueue.length === 0 || downloadManager.queueNames.indexOf(addDefaultQueue) < 0) {
                addDefaultQueue = downloadManager.defaultQueueName()
            }
            if (selectedQueue.length > 0 && downloadManager.queueNames.indexOf(selectedQueue) < 0) {
                selectedQueue = downloadManager.defaultQueueName()
            }
            if (queueFilter !== "All Queues" && downloadManager.queueNames.indexOf(queueFilter) < 0) {
                queueFilter = "All Queues"
            }
            appRoot.loadQueueEditor()
            appRoot.scheduleRebuildDownloadTableRows()
        }

        function onToastRequested(message, kind) {
            appRoot.appendNotification("Downloads", message, kind)
        }
    }

    Connections {
        target: updateClient
        ignoreUnknownSignals: true

        function onUpdateAvailableChanged() {
            if (!updateClient.updateAvailable)
                return
            const version = updateClient.latestVersion.length > 0 ? updateClient.latestVersion : "new release"
            if (appRoot.lastUpdateNotificationVersion === version)
                return
            appRoot.lastUpdateNotificationVersion = version
            appRoot.appendNotification("Update available",
                                       "Version " + version + " is available. Current version: " + updateClient.currentVersion + ".",
                                       "info")
            notificationDrawer.open()
            updateAvailableDialog.open()
        }
    }

    Connections {
        target: downloadManager.model
        ignoreUnknownSignals: true

        function onDataChanged(topLeft, bottomRight, roles) {
            var changedRoles = []
            if (Array.isArray(roles)) {
                changedRoles = roles
            } else if (typeof roles === "number") {
                changedRoles = [Number(roles)]
            } else if (roles && typeof roles.length === "number") {
                for (var roleIndex = 0; roleIndex < roles.length; ++roleIndex) {
                    changedRoles.push(Number(roles[roleIndex]))
                }
            } else if (roles && typeof roles === "object") {
                for (var key in roles) {
                    if (!roles.hasOwnProperty(key))
                        continue
                    const roleValue = Number(roles[key])
                    if (isFinite(roleValue))
                        changedRoles.push(roleValue)
                }
            }
            const roleCount = changedRoles.length
            const affectsFilter =
                                changedRoles.indexOf(appRoot.fileNameRole) >= 0
                                || changedRoles.indexOf(appRoot.statusRole) >= 0
                                || changedRoles.indexOf(appRoot.queueRole) >= 0
                                || changedRoles.indexOf(appRoot.categoryRole) >= 0
                                || changedRoles.indexOf(appRoot.finishedRole) >= 0
                                || changedRoles.indexOf(appRoot.taskRole) >= 0
            const affectsSort =
                              (appRoot.sortIndex === 1 && changedRoles.indexOf(appRoot.statusRole) >= 0)
                              || (appRoot.sortIndex === 2 && changedRoles.indexOf(appRoot.bytesReceivedRole) >= 0)
                              || (appRoot.sortIndex === 3 && changedRoles.indexOf(appRoot.bytesTotalRole) >= 0)
                              || (appRoot.sortIndex === 4 && changedRoles.indexOf(appRoot.queueRole) >= 0)
                              || (appRoot.sortIndex === 5 && changedRoles.indexOf(appRoot.categoryRole) >= 0)

            if (roleCount === 0)
                return

            if (affectsFilter || affectsSort) {
                appRoot.scheduleRebuildDownloadTableRows()
            }
        }
        function onRowsInserted() { appRoot.scheduleRebuildDownloadTableRows() }
        function onRowsRemoved() { appRoot.scheduleRebuildDownloadTableRows() }
        function onModelReset() { appRoot.scheduleRebuildDownloadTableRows() }
        function onLayoutChanged() { appRoot.scheduleRebuildDownloadTableRows() }
    }

    // This is prototype drawer
    Drawer {
        id: notificationDrawer
        edge: appRootObjects.isLeftToRight ? Qt.RightEdge : Qt.LeftEdge
        width: Math.min(appRoot.width * 0.33, 420)
        height: appRoot.height
        interactive: true

        parent: Overlay.overlay

        background: Rectangle {
            id: backgroundNotify
            color: Colors.pageground
            bottomLeftRadius: Metrics.outerRadius
            topLeftRadius: appRootObjects.isLeftToRight ? Metrics.outerRadius : 0
            topRightRadius: appRootObjects.isLeftToRight ? 0 : Metrics.outerRadius

            border.width: 1
            border.color: Colors.borderActivated
            clip: false
            RectangularShadow {
                anchors.fill: parent
                offset.x: appRootObjects.isLeftToRight ? -5 : 5
                offset.y: appRootObjects.isLeftToRight ? -5 : 5
                radius: parent.radius
                blur: 32
                spread: appRootObjects.isLeftToRight ? -3 : 3
                color: Colors.lightShadow
                z: -1
            }
        }

        ListModel { id: notificationModel }

        ColumnLayout {

            anchors.fill: parent
            spacing: 0

            /* ---------- Header ---------- */
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                color: Colors.backgroundActivated
                topLeftRadius: appRootObjects.isLeftToRight ? Metrics.outerRadius : 0
                topRightRadius: appRootObjects.isLeftToRight ? 0 : Metrics.outerRadius
                z: 2

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 16

                    Text {
                        text: qsTr("Notifications")
                        font.pixelSize: 18
                        font.bold: true
                        color: Colors.textPrimary
                    }

                    Item { Layout.fillWidth: true; }

                    // Controls.Button {
                    //     setIcon: "\uf4a2"
                    //     title: qsTr("Clear")
                    //     onClicked: {
                    //         notificationModel.remove(2)
                    //     }
                    // }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    height: 1
                    width: parent.width
                    color: Colors.borderActivated
                }
            }

            Controls.VerticalSpacer {}

            Component {
                id: notifyContentEmpty
                Item {
                    anchors.fill: parent
                    anchors.margins: 12
                    Text {
                        text: qsTr("No notifications")
                        font.pixelSize: 14
                        color: Colors.textSecondary
                        Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
                        anchors.centerIn: parent
                    }
                }
            }

            Component {
                id: notifyContent
                /* ---------- Notification List ---------- */
                ScrollView {
                    id: scrollViewNotify
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ListView {
                        id: notificationList
                        width: parent.width
                        spacing: 8
                        model: notificationModel
                        boundsBehavior: Flickable.StopAtBounds

                        removeDisplaced: Transition {
                            NumberAnimation {
                                properties: "x,y"
                                duration: Animations.normal
                            }
                        }

                        delegate: Rectangle {

                            width: ListView.view.width
                            height: 128
                            topRightRadius: Colors.radius
                            bottomRightRadius: Colors.radius
                            topLeftRadius: Colors.radius
                            bottomLeftRadius: Colors.radius
                            color: Colors.backgroundItemActivated
                            border.width: 1
                            border.color: Colors.borderActivated

                            Shadow {}

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                width: 8
                                height: 8
                                anchors.leftMargin: Metrics.margins
                                anchors.topMargin: Metrics.margins
                                radius: Colors.radius
                                color: {
                                    if (type == "default") {
                                        color: Colors.primary
                                    } else if (type == "info") {
                                        color: Colors.primaryBack
                                    } else if (type == "warning") {
                                        color: Colors.warning
                                    } else if (type == "critical" || type == "danger") {
                                        color: Colors.error
                                    } else if (type == "success") {
                                        color: Colors.success
                                    } else {
                                        color: Colors.textMuted
                                    }
                                }
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 25

                                spacing: 6

                                RowLayout {
                                    Layout.preferredWidth: parent.width
                                    Layout.preferredHeight: parent.height
                                    Layout.fillWidth: true

                                    Controls.Text {
                                        text: title
                                        font.pixelSize: Typography.t1
                                        font.family: FontSystem.getTitleBoldFont.name
                                        font.weight: Font.Bold
                                        color: Colors.textPrimary
                                    }

                                    Controls.HorizontalSpacer {}

                                    Controls.Text {
                                        text: time
                                        font.pixelSize: Typography.t4
                                        color: Colors.textSecondary
                                        opacity: 0.5
                                    }
                                }

                                RowLayout {
                                    Layout.preferredWidth: parent.width
                                    Layout.preferredHeight: parent.height
                                    Layout.fillWidth: true

                                    Controls.Text {
                                        font.family: FontSystem.getContentFontRegular.name
                                        font.weight: Font.Normal
                                        text: message
                                        wrapMode: Text.WordWrap
                                        font.pixelSize: Typography.t2
                                        color: Colors.textSecondary
                                        Layout.fillWidth: true
                                        maximumLineCount: 3
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Loader {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: 10
                Layout.bottomMargin: 10
                Layout.leftMargin: 10
                Layout.rightMargin: 10
                sourceComponent: notificationModel.count > 0 ? notifyContent : notifyContentEmpty
                // clip: true
            }
        }
    }

    Window {
        id: detailsWindow

        width: 860
        height: 620
        minimumWidth: 860
        minimumHeight: 620
        maximumWidth: 860
        maximumHeight: 620

        flags: Qt.Widget

        title: appRoot.detailsTask ? Math.round(appRoot.detailsProgress * 100) + "% " + appRoot.baseName(appRoot.taskFileNameValue(appRoot.detailsTask)) : "Download Details"
        visible: false

        property int tabIndex: 0

        color: Colors.backgroundActivated

        onVisibleChanged: {
            if (visible) {
                appRoot.resetDetailsSamples()
                appRoot.refreshDetailsSnapshot()
                if (appRoot.detailsTask) {
                    appRoot.pushDetailsSpeedSample(appRoot.detailsTask.speed)
                }
            }
        }

        Timer {
            interval: 750
            repeat: true
            running: detailsWindow.visible && appRoot.detailsTask && appRoot.detailsTask.stateString === "Active"
            onTriggered: appRoot.refreshDetailsSnapshot()
        }

        Timer {
            interval: 1000
            repeat: true
            running: detailsWindow.visible && appRoot.detailsTask && appRoot.detailsTask.stateString === "Active"
            onTriggered: {
                if (appRoot.detailsTask) {
                    appRoot.pushDetailsSpeedSample(appRoot.detailsTask.speed)
                }
            }
        }

        Connections {
            target: appRoot.detailsTask

            function onProgress(received, total) {
                appRoot.detailsBytesReceived = Math.max(0, Number(received))
                appRoot.detailsBytesTotal = Math.max(0, Number(total))
                appRoot.detailsRevision += 1
            }

            function onStateChanged() {
                appRoot.refreshDetailsSnapshot()
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: appRoot.detailsTask ? appRoot.baseName(appRoot.taskFileNameValue(appRoot.detailsTask)) : "No selection"
                    font.pixelSize: 22
                    font.bold: true
                    elide: Text.ElideRight
                }
                Label {
                    text: appRoot.detailsTask ? appRoot.taskStatusText(appRoot.detailsTask, appRoot.detailsTask.stateString) : ""
                    font.bold: true
                }
            }

            Controls.ProgressBar {
                Layout.fillWidth: true
                value: appRoot.detailsProgress
                statusLevel: appRoot.detailsTask ? appRoot.detailsTask.stateString : "Queued"
                indeterminate: appRoot.detailsTask && appRoot.detailsTask.stateString === "Active" && appRoot.detailsBytesTotal <= 0
            }

            TabBar {
                id: detailsTabs
                Layout.fillWidth: true
                currentIndex: detailsWindow.tabIndex
                onCurrentIndexChanged: detailsWindow.tabIndex = currentIndex

                TabButton { text: "General" }
                TabButton { text: "Progress" }
                TabButton { text: "Connections" }
                TabButton { text: "Limits" }
                TabButton { text: "Completion" }
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: detailsWindow.tabIndex

                Item {
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 8

                        GroupBox {
                            title: "Status"
                            Layout.fillWidth: true
                            Layout.preferredHeight: statusGrid.implicitHeight + 64

                            GridLayout {
                                id: statusGrid
                                anchors.fill: parent
                                anchors.margins: 10
                                columns: 2
                                columnSpacing: 16
                                rowSpacing: 6

                                Controls.Label { text: "URL" }
                                Controls.Label {
                                    text: appRoot.detailsTask ? appRoot.detailsTask.url() : ""
                                    elide: Text.ElideMiddle
                                    Layout.fillWidth: true
                                }

                                Controls.Label { text: "State" }
                                Controls.Label { text: appRoot.detailsTask ? appRoot.taskStatusText(appRoot.detailsTask, appRoot.detailsTask.stateString) : "" }

                                Controls.Label { text: "File size" }
                                Controls.Label { text: appRoot.formatBytes(appRoot.detailsBytesTotal) }

                                Controls.Label { text: "Downloaded" }
                                Controls.Label {
                                    text: appRoot.formatBytes(appRoot.detailsBytesReceived)
                                          + (appRoot.detailsBytesTotal > 0 ? " / " + appRoot.formatBytes(appRoot.detailsBytesTotal) : "")
                                          + (appRoot.detailsBytesTotal > 0 ? " (" + (appRoot.detailsProgress * 100).toFixed(2) + "%)" : "")
                                }

                                Controls.Label { text: "Segments" }
                                Controls.Label {
                                    text: {
                                        if (!appRoot.detailsTask) return "Segments: 0"
                                        const configured = appRoot.detailsTask.segments()
                                        const active = appRoot.detailsTask.effectiveSegments()
                                        return active !== configured
                                                ? (configured + " (" + active + " active)")
                                                : (configured)
                                    }
                                    font.bold: true
                                }

                                Controls.Label { text: "Speed" }
                                Controls.Label { text: appRoot.formatSpeed(appRoot.detailsTask ? appRoot.detailsTask.speed : 0) }

                                Controls.Label { text: "ETA" }
                                Controls.Label { text: appRoot.formatEta(appRoot.detailsTask ? appRoot.detailsTask.eta : -1) }

                                Controls.Label { text: "Queue" }
                                Controls.Label { text: appRoot.detailsQueue }

                                Controls.Label { text: "Category" }
                                Controls.Label { text: appRoot.detailsCategory }
                            }
                        }

                        GroupBox {
                            title: "Segmented Progress Map"
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: 164

                            Flickable {
                                anchors.fill: parent
                                anchors.margins: Metrics.padding
                                contentWidth: grid.width
                                contentHeight: grid.height
                                clip: true

                                Grid {
                                    id: grid
                                    columns: 80
                                    spacing: 2
                                    Item { Layout.fillHeight: true }
                                    Item { Layout.fillWidth: true }

                                    Repeater {
                                        model: 80 * 18
                                        delegate: Rectangle {
                                            required property int index
                                            width: 8
                                            height: 8
                                            radius: Metrics.innerRadius / 8
                                            color: index < Math.floor((80 * 18) * appRoot.detailsProgress) ? Colors.success : Qt.lighter(Colors.textMuted)
                                        }
                                    }
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }
                    }
                }

                Item {
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            GroupBox {
                                title: "Progress"
                                Layout.fillWidth: true
                                Layout.preferredHeight: 100
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    Controls.Label { text: (appRoot.detailsProgress * 100).toFixed(2) + "%"; font.bold: true }
                                    Controls.Label { text: appRoot.formatBytes(appRoot.detailsBytesReceived) + " downloaded" }
                                }
                            }
                            GroupBox {
                                title: "Speed"
                                Layout.fillWidth: true
                                Layout.preferredHeight: 100
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    Controls.Label { text: appRoot.formatSpeed(appRoot.detailsTask ? appRoot.detailsTask.speed : 0); font.bold: true }
                                    Controls.Label { text: "Peak " + appRoot.formatSpeed(appRoot.detailsPeakSpeed) }
                                }
                            }
                        }

                        GroupBox {
                            title: "Download Speed Chart"
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.preferredHeight: 164

                            Canvas {
                                id: speedChart
                                anchors.fill: parent
                                anchors.margins: 10
                                antialiasing: true

                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.reset()

                                    var w = width
                                    var h = height
                                    if (w <= 2 || h <= 2) return

                                    var pad = 10
                                    var chartW = Math.max(1, w - pad * 2)
                                    var chartH = Math.max(1, h - pad * 2)

                                    ctx.strokeStyle = "#808080"
                                    ctx.lineWidth = 1
                                    for (var g = 0; g <= 4; ++g) {
                                        var gy = pad + (chartH * g / 4)
                                        ctx.beginPath()
                                        ctx.moveTo(pad, gy)
                                        ctx.lineTo(w - pad, gy)
                                        ctx.stroke()
                                    }

                                    var samples = appRoot.detailsSpeedSamples
                                    if (!samples || samples.length === 0) {
                                        ctx.fillStyle = "#666666"
                                        ctx.font = "12px sans-serif"
                                        ctx.fillText("Waiting for speed samples...", pad + 6, h / 2)
                                        return
                                    }

                                    var peak = Math.max(1, appRoot.detailsPeakSpeed)
                                    var step = chartW / Math.max(1, samples.length - 1)

                                    ctx.beginPath()
                                    for (var i = 0; i < samples.length; ++i) {
                                        var x = pad + i * step
                                        var y = pad + chartH - (samples[i] / peak) * chartH
                                        if (i === 0) ctx.moveTo(x, y)
                                        else ctx.lineTo(x, y)
                                    }
                                    ctx.strokeStyle = "#2f7fd8"
                                    ctx.lineWidth = 2
                                    ctx.stroke()
                                }

                                Connections {
                                    target: appRoot
                                    function onDetailsSpeedSamplesChanged() { speedChart.requestPaint() }
                                    function onDetailsPeakSpeedChanged() { speedChart.requestPaint() }
                                }

                                onWidthChanged: requestPaint()
                                onHeightChanged: requestPaint()
                            }
                        }

                    }
                }

                Item {
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 8

                        GroupBox {
                            title: "Connection table"
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            ListView {
                                anchors.fill: parent
                                anchors.margins: 8
                                clip: true
                                model: appRoot.detailsTask ? appRoot.detailsTask.effectiveSegments() : 0

                                delegate: RowLayout {
                                    required property int index
                                    readonly property string segState: {
                                        const tick = appRoot.detailsRevision
                                        return appRoot.detailsTask ? appRoot.detailsTask.segmentState(index) : "Waiting"
                                    }
                                    readonly property real segBytes: {
                                        const tick = appRoot.detailsRevision
                                        return appRoot.detailsTask ? appRoot.detailsTask.segmentDownloaded(index) : 0
                                    }

                                    width: ListView.view.width
                                    spacing: 12

                                    Controls.Label {
                                        Layout.preferredWidth: 50
                                        text: String(index + 1)
                                    }
                                    Controls.Label {
                                        Layout.preferredWidth: 180
                                        text: appRoot.formatBytes(segBytes)
                                    }
                                    Controls.Label {
                                        Layout.fillWidth: true
                                        text: segState
                                    }
                                }

                                ScrollBar.vertical: ScrollBar { }
                            }
                        }
                    }
                }

                Item {
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 8

                        GroupBox {
                            title: "Speed limits"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 140

                            GridLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                columns: 2
                                rowSpacing: 8
                                columnSpacing: 12

                                Controls.Label { text: "Task cap (MB/s)" }
                                RowLayout {
                                    Controls.SpinBox {
                                        id: detailsSpeedCap
                                        from: 0
                                        to: 4096
                                        value: appRoot.detailsRow >= 0 ? Math.round(downloadManager.taskMaxSpeed(appRoot.detailsRow) / (1024 * 1024)) : 0
                                    }
                                    Controls.Button {
                                        text: "Apply"
                                        isDefault: false
                                        enabled: appRoot.detailsRow >= 0
                                        onClicked: if (appRoot.detailsRow >= 0) downloadManager.setTaskMaxSpeed(appRoot.detailsRow, detailsSpeedCap.value * 1024 * 1024)
                                    }
                                    Controls.Button {
                                        text: "Unlimited"
                                        isDefault: false
                                        enabled: appRoot.detailsRow >= 0
                                        onClicked: {
                                            detailsSpeedCap.value = 0
                                            if (appRoot.detailsRow >= 0) downloadManager.setTaskMaxSpeed(appRoot.detailsRow, 0)
                                        }
                                    }
                                }

                                Controls.Label { text: "Global cap" }
                                Controls.Label {
                                    text: downloadManager.globalMaxSpeed > 0 ? appRoot.formatSpeed(downloadManager.globalMaxSpeed) : "Unlimited"
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }
                    }
                }

                Item {
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 8

                        GroupBox {
                            title: "After completion"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 230

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 8

                                Controls.CheckBox {
                                    text: "Open file when completed"
                                    checked: appRoot.detailsTask ? appRoot.detailsTask.postOpenFile : false
                                    onToggled: if (appRoot.detailsTask) appRoot.detailsTask.postOpenFile = checked
                                }
                                Controls.CheckBox {
                                    text: "Show in folder when completed"
                                    checked: appRoot.detailsTask ? appRoot.detailsTask.postRevealFolder : false
                                    onToggled: if (appRoot.detailsTask) appRoot.detailsTask.postRevealFolder = checked
                                }
                                Controls.CheckBox {
                                    text: "Extract when completed"
                                    checked: appRoot.detailsTask ? appRoot.detailsTask.postExtract : false
                                    onToggled: if (appRoot.detailsTask) appRoot.detailsTask.postExtract = checked
                                }

                                RowLayout {
                                    Label { text: "Post script" }
                                    TextField {
                                        Layout.fillWidth: true
                                        text: appRoot.detailsTask ? appRoot.detailsTask.postScript : ""
                                        onEditingFinished: if (appRoot.detailsTask) appRoot.detailsTask.postScript = text
                                    }
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Controls.Button {
                    implicitWidth: 86
                    isDefault: false
                    text: appRoot.detailsTask && appRoot.detailsTask.stateString === "Active" ? "Pause" : "Resume"
                    enabled: appRoot.detailsTask && (appRoot.detailsTask.stateString === "Active" || appRoot.detailsTask.stateString === "Paused")
                    onClicked: {
                        if (!appRoot.detailsTask || appRoot.detailsRow < 0) return
                        if (appRoot.detailsTask.stateString === "Active") downloadManager.pauseTask(appRoot.detailsRow)
                        else downloadManager.resumeTask(appRoot.detailsRow)
                    }
                }
                Controls.Button {
                    implicitWidth: 86
                    isDefault: false
                    text: "Retry"
                    enabled: appRoot.detailsRow >= 0
                    onClicked: if (appRoot.detailsRow >= 0) downloadManager.retryTask(appRoot.detailsRow)
                }
                Controls.Button {
                    implicitWidth: 86
                    isDefault: false
                    text: "Cancel"
                    enabled: appRoot.detailsTask && (appRoot.detailsTask.stateString === "Active" || appRoot.detailsTask.stateString === "Paused" || appRoot.detailsTask.stateString === "Queued")
                    onClicked: if (appRoot.detailsTask) appRoot.detailsTask.cancel()
                }

                Controls.Button {
                    implicitWidth: 86
                    isDefault: false
                    text: "Open"
                    enabled: appRoot.detailsRow >= 0 && appRoot.detailsIsDone
                    onClicked: if (appRoot.detailsRow >= 0 && appRoot.detailsIsDone) downloadManager.openFile(appRoot.detailsRow)
                }
                Controls.Button {
                    implicitWidth: 128
                    text: "Show in Folder"
                    Layout.fillWidth: true
                    isDefault: false
                    enabled: appRoot.detailsRow >= 0
                    onClicked: if (appRoot.detailsRow >= 0) downloadManager.revealInFolder(appRoot.detailsRow)
                }
                // Button {
                //     implicitWidth: 86
                //     isDefault: false
                //     text: "Verify"
                //     enabled: appRoot.detailsRow >= 0
                //     onClicked: if (appRoot.detailsRow >= 0) downloadManager.verifyTask(appRoot.detailsRow)
                // }
                Controls.Button {
                    implicitWidth: 86
                    // isDefault: false
                    style: "danger"
                    text: "Remove"
                    enabled: appRoot.detailsRow >= 0
                    onClicked: {
                        if (appRoot.detailsRow < 0)
                            return
                        appRoot.pendingRemoveRows = [appRoot.detailsRow]
                        detailsRemoveFromDiskCheck.checked = false
                        detailsRemovePopup.open()
                    }
                }
                Controls.Button {
                    implicitWidth: 86
                    isDefault: false
                    text: "Close"
                    onClicked: detailsWindow.close()
                }
            }

            Controls.Dialog {
                id: detailsRemovePopup

                modal: true
                focus: true
                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

                width: 460

                title: "Remove download"
                standardButtons: Dialog.Cancel | Dialog.Yes
                yesTextOverride: "Remove"
                type: "danger"

                onAccepted: appRoot.confirmRemovePending(detailsRemoveFromDiskCheck.checked)

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    Controls.Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: "Remove the selected download from RAAD?"
                    }

                    Controls.CheckBox {
                        id: detailsRemoveFromDiskCheck
                        Layout.fillWidth: true
                        text: "Also delete file and partial segments from disk"
                    }
                }
            }
        }
    }

    Controls.Dialog {
        id: updateAvailableDialog

        width: 480
        title: "Update available"
        type: updateClient.expectedSha256.length > 0 ? "info" : "warning"
        standardButtons: Dialog.Cancel | Dialog.Yes
        cancelTextOverride: "Later"
        yesTextOverride: updateClient.downloadReady ? "Install" : "Download"

        onAccepted: {
            if (updateClient.downloadReady) {
                updateClient.installUpdate()
            } else if (!(updateClient.downloadProgress > 0 && updateClient.downloadProgress < 1)) {
                updateClient.downloadUpdate()
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12

            Controls.Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: "A newer version of RAAD is available."
            }

            Controls.Label {
                text: "Current: " + updateClient.currentVersion
            }

            Controls.Label {
                text: "Latest: " + (updateClient.latestVersion.length > 0 ? updateClient.latestVersion : "--")
            }

            Controls.Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: updateClient.expectedSha256.length > 0
                      ? "Checksum metadata is available and will be verified after download."
                      : "No SHA-256 checksum metadata was found for this release. Download can continue, but release metadata should be improved before broad rollout."
            }
        }
    }

    Controls.Dialog {
        id: resetSettingsDialog
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        width: 520
        title: "Restore defaults"
        standardButtons: Dialog.Cancel | Dialog.RestoreDefaults
        type: "danger"
        restoreDefaultsStyleOverride: "danger"

        onReset: appRoot.resetAllSettingsToDefaults()

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12

            Controls.Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: "Restore RAAD to its default configuration?"
            }

            Controls.Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: "This clears saved download state, queues, rules, updater settings, and UI preferences. Existing downloaded files on disk are not deleted."
            }
        }
    }

    Controls.Dialog {
        id: removeDownloadPopup

        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        width: 460

        title: appRoot.pendingRemoveRows.length > 1 ? "Remove downloads" : "Remove download"
        standardButtons: Dialog.Cancel | Dialog.Yes
        yesTextOverride: appRoot.pendingRemoveRows.length > 1 ? "Remove All" : "Remove"

        type: "danger"

        onAccepted: appRoot.confirmRemovePending(removeFromDiskCheck.checked)

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 14

            Controls.Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: appRoot.pendingRemoveRows.length > 1
                      ? "Remove " + appRoot.pendingRemoveRows.length + " selected downloads from RAAD?"
                      : "Remove the selected download from RAAD?"
            }

            Controls.CheckBox {
                id: removeFromDiskCheck
                Layout.fillWidth: true
                text: appRoot.pendingRemoveRows.length > 1
                      ? "Also delete downloaded files and partial segments from disk"
                      : "Also delete file and partial segments from disk"
            }
        }
    }

    header: Item {
        id: headerOne
        width: parent.width
        height: 86

        Layout.fillWidth: true
        anchors.right: parent.right
        anchors.left: parent.left

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Item { Layout.preferredWidth: 5; }

                Rectangle {
                    Layout.preferredWidth: 110
                    Layout.preferredHeight: 38
                    radius: Metrics.innerRadius
                    color: Colors.lightShadow
                    clip: true
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 10
                        Controls.Text {
                            font.family: FontSystem.getAwesomeSolid.name
                            font.pixelSize: Typography.h2
                            font.weight: Font.Bold
                            color: Colors.warning
                            text: "\ue0b7"
                        }

                        Controls.Text {
                            font.family: FontSystem.getContentFont.name
                            font.pixelSize: Typography.h3
                            color: Colors.textPrimary
                            text: "RAAD"
                        }
                    }
                }

                Item { Layout.preferredWidth: 15; }

                Row {
                    spacing: 2
                    Controls.AppMenuTrigger { text: "Actions"; menu: tasksTopMenu }
                    Controls.AppMenuTrigger { text: "File"; menu: fileTopMenu }
                    Controls.AppMenuTrigger { text: "Downloads"; menu: downloadsTopMenu }
                    Controls.AppMenuTrigger { text: "Configuration"; menu: configurationTopMenu }
                    Controls.AppMenuTrigger { text: "Help"; menu: helpTopMenu }
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    Layout.preferredWidth: 512
                    Layout.preferredHeight: 82
                    radius: Metrics.innerRadius
                    color: Colors.backgroundActivated
                    border.width: 1
                    border.color: Colors.borderActivated
                    gradient: LinearGradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.33; color: "transparent" }
                        GradientStop { position: 1.0; color: Colors.backgroundItemActivated }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12

                        Rectangle {
                            Layout.preferredWidth: 58
                            Layout.preferredHeight: 58
                            radius: 18
                            color: "#001309" //Colors.backgroundItemActivated
                            border.width: 1
                            border.color: Colors.borderActivated

                            Image {
                                id: genyAdImage
                                anchors.fill: parent
                                anchors.margins: 10
                                source: appRoot.genyTokenImageUrl
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                asynchronous: true
                                cache: true
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: genyAdImage.status !== Image.Ready
                                text: "$GENY"
                                color: Colors.textPrimary
                                font.family: FontSystem.getTitleBoldFont.font.family
                                font.bold: true
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                text: "GenyToken"
                                color: Colors.textPrimary
                                font.family: FontSystem.getTitleBoldFont.font.family
                                font.pixelSize: Typography.t2
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "256M fixed-supply ERC20 powering the Genyleap ecosystem."
                                color: Colors.textSecondary
                                font.family: FontSystem.getContentFontRegular.name
                                font.pixelSize: Typography.t4
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                textFormat: Text.RichText
                                text: "<a href=\"" + appRoot.genyleapWebsiteUrl + "\"><span style=\"color:#3a86ff;text-decoration:underline;\">"
                                      + appRoot.genyleapWebsiteUrl + "</span></a>"
                                onLinkActivated: appRoot.openExternalLink(link, "Opened Genyleap website")
                                color: Colors.textAccent
                                font.family: FontSystem.getContentFontRegular.name
                                font.pixelSize: Typography.t4
                                wrapMode: Text.WrapAnywhere
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: appRoot.openExternalLink(appRoot.genyleapWebsiteUrl, "Opened Genyleap website")
                    }
                }
            }
        }

        Controls.AppMenu {
            id: tasksTopMenu
            title: "Actions"
            Controls.AppMenuItem {
                text: "Add Url"
                iconGlyph: "\uf0c1"
                onTriggered: {
                    appRoot.pageIndex = 0
                    appRoot.openAddUrlDialog()
                }
            }
            Controls.AppMenuItem { text: "Resume"; iconGlyph: "\uf01e"; enabled: appRoot.canResumeAction(); onTriggered: appRoot.applyActionToCheckedOrSelected("resume") }
            Controls.AppMenuItem { text: "Stop"; iconGlyph: "\uf28d"; enabled: appRoot.canStopAction(); onTriggered: appRoot.applyActionToCheckedOrSelected("pause") }
            Controls.AppMenuItem { text: "Stop All"; iconGlyph: "\uf28d"; enabled: appRoot.canStopAllAction(); onTriggered: appRoot.applyActionToCheckedOrSelected("pause") }
            Controls.AppMenuItem { text: "Retry Failed"; iconGlyph: "\uf01e"; onTriggered: downloadManager.retryFailed() }
            Controls.AppMenuItem { text: "Cancel All"; iconGlyph: "\uf057"; onTriggered: downloadManager.cancelAll() }
            Controls.AppMenuSeparator {}
            Controls.AppMenuItem { text: "Exit"; iconGlyph: "\uf08b"; onTriggered: Qt.quit() }
        }

        Controls.AppMenu {
            id: fileTopMenu
            title: "File"
            Controls.AppMenuItem { text: "Import List..."; iconGlyph: "\uf56f"; onTriggered: importDialog.open() }
            Controls.AppMenuItem { text: "Export List..."; iconGlyph: "\uf56e"; onTriggered: exportDialog.open() }
            Controls.AppMenuSeparator { }
            Controls.AppMenuItem { text: "Clear Completed"; iconGlyph: "\uf2ed"; onTriggered: downloadManager.clearCompleted() }
        }

        Controls.AppMenu {
            id: downloadsTopMenu
            title: "Downloads"
            Controls.AppMenuItem {
                text: "Open"
                iconGlyph: "\uf15c"
                enabled: appRoot.hasSelection
                onTriggered: if (appRoot.hasSelection) appRoot.executeRowAction(appRoot.selectedTaskIndex, appRoot.selectedTask, "open", appRoot.selectedQueue, appRoot.selectedCategory)
            }
            Controls.AppMenuItem {
                text: "Show in Folder"
                iconGlyph: "\uf07c"
                enabled: appRoot.hasSelection
                onTriggered: if (appRoot.hasSelection) appRoot.executeRowAction(appRoot.selectedTaskIndex, appRoot.selectedTask, "reveal", appRoot.selectedQueue, appRoot.selectedCategory)
            }
            Controls.AppMenuItem {
                text: "Properties"
                iconGlyph: "\uf05a"
                enabled: appRoot.hasSelection
                onTriggered: if (appRoot.hasSelection) appRoot.openDetailsFor(appRoot.selectedTaskIndex, appRoot.selectedTask, appRoot.selectedQueue, appRoot.selectedCategory)
            }
        }

        Controls.AppMenu {
            id: configurationTopMenu
            title: "Configuration"
            Controls.AppMenuItem { text: "General"; iconGlyph: "\uf53f"; onTriggered: appRoot.openConfigurationDialog(0) }
            Controls.AppMenuItem { text: "Queues"; iconGlyph: "\uf0ca"; onTriggered: appRoot.openConfigurationDialog(1) }
            Controls.AppMenuItem { text: "Network"; iconGlyph: "\uf1eb"; onTriggered: appRoot.openConfigurationDialog(2) }
            Controls.AppMenuItem { text: "Updates"; iconGlyph: "\uf021"; onTriggered: appRoot.openConfigurationDialog(3) }
            Controls.AppMenuSeparator { }
            Controls.AppMenuItem {
                text: appRoot.sortAscending ? "Sort Desc" : "Sort Asc"
                iconGlyph: "\uf884"
                onTriggered: appRoot.sortAscending = !appRoot.sortAscending
            }
        }

        Controls.AppMenu {
            id: helpTopMenu
            title: "Help"
            Controls.AppMenuItem { text: "Support & Community"; iconGlyph: "\uf500"; onTriggered: supportDialog.open() }
            Controls.AppMenuItem {
                text: "Check for Updates"
                iconGlyph: "\uf0e7"
                onTriggered: {
                    updateDialog.open()
                    updateClient.checkNow()
                }
            }
            Controls.AppMenuItem { text: "License & OpenSource"; iconGlyph: "\uf0a3"; onTriggered: licenseDialog.open() }
            Controls.AppMenuSeparator {}
            Controls.AppMenuItem { text: "Donate"; iconGlyph: "\uf004"; onTriggered: donateDialog.open() }
            Controls.AppMenuItem { text: "Buy Geny Token"; iconGlyph: "\uf471"; onTriggered: tokenDialog.open() }
            Controls.AppMenuSeparator {}
            Controls.AppMenuItem { text: "About"; iconGlyph: "\uf0e7"; onTriggered: aboutDialog.open() }
        }

        Controls.AppMenu {
            id: toolbarItemMenu
            property int targetRow: -1
            property var targetTask: null
            property string targetQueue: ""
            property string targetCategory: ""

            Controls.AppMenuItem {
                text: "Open"
                iconGlyph: "\uf15c"
                enabled: toolbarItemMenu.targetTask && toolbarItemMenu.targetTask.stateString === "Done"
                onTriggered: appRoot.executeRowAction(toolbarItemMenu.targetRow, toolbarItemMenu.targetTask, "open", toolbarItemMenu.targetQueue, toolbarItemMenu.targetCategory)
            }
            Controls.AppMenuItem {
                text: "Open Folder"
                iconGlyph: "\uf07c"
                enabled: toolbarItemMenu.targetTask
                onTriggered: appRoot.executeRowAction(toolbarItemMenu.targetRow, toolbarItemMenu.targetTask, "reveal", toolbarItemMenu.targetQueue, toolbarItemMenu.targetCategory)
            }
            Controls.AppMenuSeparator { }
            Controls.AppMenuItem {
                text: "Resume"
                iconGlyph: "\uf01e"
                enabled: toolbarItemMenu.targetTask && toolbarItemMenu.targetTask.stateString === "Paused"
                onTriggered: appRoot.executeRowAction(toolbarItemMenu.targetRow, toolbarItemMenu.targetTask, "resume", toolbarItemMenu.targetQueue, toolbarItemMenu.targetCategory)
            }
            Controls.AppMenuItem {
                text: "Stop"
                iconGlyph: "\uf28d"
                enabled: toolbarItemMenu.targetTask && toolbarItemMenu.targetTask.stateString === "Active"
                onTriggered: appRoot.executeRowAction(toolbarItemMenu.targetRow, toolbarItemMenu.targetTask, "pause", toolbarItemMenu.targetQueue, toolbarItemMenu.targetCategory)
            }
            Controls.AppMenuItem {
                text: "Retry"
                iconGlyph: "\uf2f1"
                enabled: toolbarItemMenu.targetTask
                onTriggered: appRoot.executeRowAction(toolbarItemMenu.targetRow, toolbarItemMenu.targetTask, "retry", toolbarItemMenu.targetQueue, toolbarItemMenu.targetCategory)
            }
            Controls.AppMenuSeparator { }
            Controls.AppMenuItem {
                text: "Properties"
                iconGlyph: "\uf05a"
                enabled: toolbarItemMenu.targetTask
                onTriggered: appRoot.openDetailsFor(toolbarItemMenu.targetRow, toolbarItemMenu.targetTask, toolbarItemMenu.targetQueue, toolbarItemMenu.targetCategory)
            }
            Controls.AppMenuItem {
                text: "Remove"
                iconGlyph: "\uf2ed"
                enabled: toolbarItemMenu.targetTask
                onTriggered: appRoot.executeRowAction(toolbarItemMenu.targetRow, toolbarItemMenu.targetTask, "remove", toolbarItemMenu.targetQueue, toolbarItemMenu.targetCategory)
            }
        }

    }

    contentData: ColumnLayout {
        anchors.fill: parent
        anchors.margins: Metrics.margins
        spacing: 8

        StackLayout {
            id: stackLayout
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: appRoot.pageIndex

            RowLayout {
                Layout.fillWidth: true
                spacing: Metrics.margins

                Pane {
                    id: sidebarRail
                    Layout.preferredWidth: Math.max(220, Math.min(300, appRoot.width * 0.22))
                    Layout.minimumWidth: 280
                    Layout.maximumWidth: 320
                    Layout.fillHeight: true
                    background: Rectangle {
                        color: Colors.backgroundActivated
                        radius: Metrics.outerRadius
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: Metrics.margins

                        ScrollView {
                            id: sidebarScroll
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            contentWidth: availableWidth
                            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                            ColumnLayout {
                                width: sidebarScroll.availableWidth
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                Controls.GroupBox {
                                    id: navigationTree
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: navigationTreeContent.implicitHeight + 18
                                    hasBorder: false
                                    hasShadow: false

                                    ColumnLayout {
                                        id: navigationTreeContent
                                        anchors.fill: parent
                                        spacing: 6

                                        Controls.SidebarTreeItem {
                                            Layout.fillWidth: true
                                            text: "All Downloads"
                                            iconGlyph: "\uf07c"
                                            selected: appRoot.statusFilter === "All" && appRoot.categoryFilter === "All" && appRoot.queueFilter === "All Queues"
                                            expandable: true
                                            expanded: appRoot.sidebarAllExpanded
                                            onClicked: {
                                                appRoot.setCategoryPreset("all")
                                                appRoot.sidebarAllExpanded = !appRoot.sidebarAllExpanded
                                            }
                                        }

                                        Item {
                                            Layout.fillWidth: true
                                            implicitHeight: allDownloadsChildren.implicitHeight
                                            height: appRoot.sidebarAllExpanded ? implicitHeight : 0
                                            opacity: appRoot.sidebarAllExpanded ? 1 : 0
                                            visible: height > 0 || opacity > 0

                                            Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                                            ColumnLayout {
                                                id: allDownloadsChildren
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.top: parent.top
                                                spacing: 4

                                                Controls.SidebarTreeItem {
                                                    Layout.fillWidth: true
                                                    child: true
                                                    text: "Musics"
                                                    iconGlyph: "\uf001"
                                                    selected: appRoot.categoryFilter === "Audio" && appRoot.statusFilter === "All"
                                                    onClicked: appRoot.setCategoryScope("Audio")
                                                }
                                                Controls.SidebarTreeItem {
                                                    Layout.fillWidth: true
                                                    child: true
                                                    text: "Compressed"
                                                    iconGlyph: "\uf1c6"
                                                    selected: appRoot.categoryFilter === "Archives" && appRoot.statusFilter === "All"
                                                    onClicked: appRoot.setCategoryScope("Archives")
                                                }
                                                Controls.SidebarTreeItem {
                                                    Layout.fillWidth: true
                                                    child: true
                                                    text: "Videos"
                                                    iconGlyph: "\uf03d"
                                                    selected: appRoot.categoryFilter === "Video" && appRoot.statusFilter === "All"
                                                    onClicked: appRoot.setCategoryScope("Video")
                                                }
                                                Controls.SidebarTreeItem {
                                                    Layout.fillWidth: true
                                                    child: true
                                                    text: "Programs"
                                                    iconGlyph: "\uf15b"
                                                    selected: appRoot.categoryFilter === "Programs" && appRoot.statusFilter === "All"
                                                    onClicked: appRoot.setCategoryScope("Programs")
                                                }
                                                Controls.SidebarTreeItem {
                                                    Layout.fillWidth: true
                                                    child: true
                                                    text: "Documents"
                                                    iconGlyph: "\uf15c"
                                                    selected: appRoot.categoryFilter === "Documents" && appRoot.statusFilter === "All"
                                                    onClicked: appRoot.setCategoryScope("Documents")
                                                }
                                                Controls.SidebarTreeItem {
                                                    Layout.fillWidth: true
                                                    child: true
                                                    text: "APKs"
                                                    iconGlyph: "\uf2db"
                                                    selected: appRoot.categoryFilter === "Programs" && appRoot.statusFilter === "All"
                                                    onClicked: appRoot.setCategoryScope("Programs")
                                                }
                                                Controls.SidebarTreeItem {
                                                    Layout.fillWidth: true
                                                    child: true
                                                    text: "Images"
                                                    iconGlyph: "\uf03e"
                                                    selected: appRoot.categoryFilter === "Images" && appRoot.statusFilter === "All"
                                                    onClicked: appRoot.setCategoryScope("Images")
                                                }
                                            }
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.topMargin: 6
                                            Layout.bottomMargin: 6
                                            height: 1
                                            color: Colors.lineBorderActivated
                                        }

                                        Controls.SidebarTreeItem {
                                            Layout.fillWidth: true
                                            text: "Unfinished"
                                            iconGlyph: "\uf07b"
                                            selected: appRoot.statusFilter === "Unfinished" || appRoot.statusFilter === "Active" || appRoot.statusFilter === "Queued" || appRoot.statusFilter === "Paused"
                                            expandable: true
                                            expanded: appRoot.sidebarUnfinishedExpanded
                                            onClicked: {
                                                appRoot.setCategoryPreset("unfinished")
                                                appRoot.sidebarUnfinishedExpanded = !appRoot.sidebarUnfinishedExpanded
                                            }
                                        }

                                        Item {
                                            Layout.fillWidth: true
                                            implicitHeight: unfinishedChildren.implicitHeight
                                            height: appRoot.sidebarUnfinishedExpanded ? implicitHeight : 0
                                            opacity: appRoot.sidebarUnfinishedExpanded ? 1 : 0
                                            visible: height > 0 || opacity > 0

                                            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                            Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                                            ColumnLayout {
                                                id: unfinishedChildren
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.top: parent.top
                                                spacing: 4

                                                Controls.SidebarTreeItem {
                                                    Layout.fillWidth: true
                                                    child: true
                                                    text: "Active"
                                                    iconGlyph: "\uf04b"
                                                    selected: appRoot.statusFilter === "Active"
                                                    onClicked: appRoot.setStatusScope("Active")
                                                }
                                                Controls.SidebarTreeItem {
                                                    Layout.fillWidth: true
                                                    child: true
                                                    text: "Queued"
                                                    iconGlyph: "\uf0ae"
                                                    selected: appRoot.statusFilter === "Queued"
                                                    onClicked: appRoot.setStatusScope("Queued")
                                                }
                                                Controls.SidebarTreeItem {
                                                    Layout.fillWidth: true
                                                    child: true
                                                    text: "Paused"
                                                    iconGlyph: "\uf04c"
                                                    selected: appRoot.statusFilter === "Paused"
                                                    onClicked: appRoot.setStatusScope("Paused")
                                                }
                                                Controls.SidebarTreeItem {
                                                    Layout.fillWidth: true
                                                    child: true
                                                    text: "Errors"
                                                    iconGlyph: "\uf071"
                                                    selected: appRoot.statusFilter === "Error"
                                                    onClicked: appRoot.setStatusScope("Error")
                                                }
                                            }
                                        }

                                        Controls.SidebarTreeItem {
                                            Layout.fillWidth: true
                                            text: "Finished"
                                            iconGlyph: "\uf07b"
                                            selected: appRoot.statusFilter === "History" || appRoot.statusFilter === "Done" || appRoot.statusFilter === "Canceled"
                                            expandable: true
                                            expanded: appRoot.sidebarFinishedExpanded
                                            onClicked: {
                                                appRoot.setCategoryPreset("finished")
                                                appRoot.sidebarFinishedExpanded = !appRoot.sidebarFinishedExpanded
                                            }
                                        }

                                        Item {
                                            Layout.fillWidth: true
                                            implicitHeight: finishedChildren.implicitHeight
                                            height: appRoot.sidebarFinishedExpanded ? implicitHeight : 0
                                            opacity: appRoot.sidebarFinishedExpanded ? 1 : 0
                                            visible: height > 0 || opacity > 0

                                            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                            Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                                            ColumnLayout {
                                                id: finishedChildren
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.top: parent.top
                                                spacing: 4

                                                Controls.SidebarTreeItem {
                                                    Layout.fillWidth: true
                                                    child: true
                                                    text: "Done"
                                                    iconGlyph: "\uf00c"
                                                    selected: appRoot.statusFilter === "Done"
                                                    onClicked: appRoot.setStatusScope("Done")
                                                }
                                                Controls.SidebarTreeItem {
                                                    Layout.fillWidth: true
                                                    child: true
                                                    text: "Canceled"
                                                    iconGlyph: "\uf00d"
                                                    selected: appRoot.statusFilter === "Canceled"
                                                    onClicked: appRoot.setStatusScope("Canceled")
                                                }
                                                Controls.SidebarTreeItem {
                                                    Layout.fillWidth: true
                                                    child: true
                                                    text: "Errors"
                                                    iconGlyph: "\uf071"
                                                    selected: appRoot.statusFilter === "Error"
                                                    onClicked: appRoot.setStatusScope("Error")
                                                }
                                            }
                                        }

                                    }
                                }

                                Controls.GroupBox {
                                    id: queueTree
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: queueTreeContent.implicitHeight + 18
                                    hasBorder: false
                                    hasShadow: false

                                    ColumnLayout {
                                        id: queueTreeContent
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 6

                                        Controls.SidebarTreeItem {
                                            Layout.fillWidth: true
                                            text: "Queues"
                                            iconGlyph: "\uf0ca"
                                            selected: appRoot.queueFilter !== "All Queues"
                                            expandable: true
                                            expanded: appRoot.sidebarQueuesExpanded
                                            onClicked: appRoot.sidebarQueuesExpanded = !appRoot.sidebarQueuesExpanded
                                        }

                                        Item {
                                            Layout.fillWidth: true
                                            implicitHeight: queueChildren.implicitHeight
                                            height: appRoot.sidebarQueuesExpanded ? implicitHeight : 0
                                            opacity: appRoot.sidebarQueuesExpanded ? 1 : 0
                                            visible: height > 0 || opacity > 0

                                            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                            Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                                            ColumnLayout {
                                                id: queueChildren
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.top: parent.top
                                                spacing: 4

                                                Controls.SidebarTreeItem {
                                                    Layout.fillWidth: true
                                                    text: "All Queues"
                                                    iconGlyph: "\uf03a"
                                                    selected: appRoot.queueFilter === "All Queues"
                                                    onClicked: appRoot.setQueueScope("All Queues")
                                                }
                                                Repeater {
                                                    model: downloadManager.queueNames
                                                    delegate: Controls.SidebarTreeItem {
                                                        required property string modelData
                                                        Layout.fillWidth: true
                                                        text: modelData
                                                        iconGlyph: "\uf07b"
                                                        selected: appRoot.queueFilter === modelData
                                                        onClicked: appRoot.setQueueScope(modelData)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Controls.GroupBox {
                            id: runtimeCard
                            Layout.fillWidth: true
                            Layout.fillHeight: false
                            hasBorder: true
                            Layout.preferredHeight: runtimeCardContent.implicitHeight + 48
                            readonly property real transferRatio: downloadManager.totalSize > 0
                                                                  ? Math.min(1.0, downloadManager.totalReceived / downloadManager.totalSize)
                                                                  : 0.0
                            readonly property real cpuRatio: Math.max(0, Math.min(1, downloadManager.processCpuLoad / 100.0))

                            ColumnLayout {
                                id: runtimeCardContent
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 10

                                RowLayout {
                                    Layout.fillWidth: true
                                    Controls.Label {
                                        text: "Runtime"
                                        font.bold: true
                                        font.pixelSize: Typography.t2
                                    }
                                    Item { Layout.fillWidth: true }
                                    Controls.Label {
                                        text: downloadManager.onBattery ? "Battery" : "AC Power"
                                        color: downloadManager.onBattery ? Colors.warning : Colors.success
                                    }
                                }

                                GridLayout {
                                    Layout.fillWidth: true
                                    columns: 2
                                    columnSpacing: 10
                                    rowSpacing: 8

                                    Controls.Label { text: "CPU" }
                                    Controls.Label {
                                        text: downloadManager.processCpuLoad.toFixed(1) + "%"
                                        horizontalAlignment: Text.AlignRight
                                        Layout.fillWidth: true
                                    }

                                    Controls.Label { text: "Memory" }
                                    Controls.Label {
                                        text: appRoot.formatBytes(downloadManager.processMemoryBytes)
                                        horizontalAlignment: Text.AlignRight
                                        Layout.fillWidth: true
                                    }

                                    Controls.Label { text: "Disk free" }
                                    Controls.Label {
                                        text: appRoot.formatBytes(downloadManager.diskFreeBytes)
                                        horizontalAlignment: Text.AlignRight
                                        Layout.fillWidth: true
                                    }

                                    Controls.Label { text: "Throughput" }
                                    Controls.Label {
                                        text: appRoot.formatSpeed(downloadManager.totalSpeed)
                                        horizontalAlignment: Text.AlignRight
                                        Layout.fillWidth: true
                                    }

                                    Controls.Label { text: "Active" }
                                    Controls.Label {
                                        text: String(downloadManager.activeCount)
                                        horizontalAlignment: Text.AlignRight
                                        Layout.fillWidth: true
                                    }

                                    Controls.Label { text: "Queued" }
                                    Controls.Label {
                                        text: String(downloadManager.queuedCount)
                                        horizontalAlignment: Text.AlignRight
                                        Layout.fillWidth: true
                                    }

                                    Controls.Label { text: "Network" }
                                    Controls.Label {
                                        text: downloadManager.networkReachability
                                        horizontalAlignment: Text.AlignRight
                                        Layout.fillWidth: true
                                        color: downloadManager.networkReachability === "Online"
                                               ? Colors.success
                                               : (downloadManager.networkReachability === "Offline"
                                                  ? Colors.error
                                                  : Colors.warning)
                                    }

                                    Controls.Label { text: "Avg segments" }
                                    Controls.Label {
                                        text: downloadManager.averageActiveSegments > 0
                                              ? downloadManager.averageActiveSegments.toFixed(1)
                                              : "0.0"
                                        horizontalAlignment: Text.AlignRight
                                        Layout.fillWidth: true
                                    }
                                }

                                Controls.ProgressBar {
                                    Layout.fillWidth: true
                                    value: runtimeCard.cpuRatio
                                    statusLevel: downloadManager.processCpuLoad > 80 ? "Error"
                                                                                     : (downloadManager.processCpuLoad > 60 ? "Paused" : "Done")
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 1
                                    color: Colors.lineBorderActivated
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Controls.Label { text: "Transfer"; font.bold: true }
                                    Item { Layout.fillWidth: true }
                                    Controls.Label { text: Math.round(runtimeCard.transferRatio * 100) + "%" }
                                }

                                Controls.ProgressBar {
                                    Layout.fillWidth: true
                                    value: runtimeCard.transferRatio
                                }

                                Controls.Label {
                                    Layout.fillWidth: true
                                    text: appRoot.formatBytes(downloadManager.totalReceived) + " / "
                                          + appRoot.formatBytes(downloadManager.totalSize)
                                    elide: Text.ElideMiddle
                                }
                            }

                        }

                    }
                }

                Pane {
                    id: mainPane
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    background: Rectangle {
                        color: Colors.backgroundActivated
                        radius: Metrics.outerRadius
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: Metrics.padding

                        ColumnLayout {
                            id: operationsContent
                            Layout.fillWidth: true
                            spacing: Metrics.padding

                            Item {
                                id: commandItem
                                Layout.fillWidth: true
                                Layout.preferredHeight: 72

                                AlphaGlass {
                                    width: commandStrip.width
                                    height: commandStrip.height
                                    x: commandStrip.x
                                    y: commandStrip.y
                                    scene: commandStrip
                                    radius: Metrics.outerRadius
                                    blurEnabled: true
                                    hasBorder: true
                                }

                                RowLayout {
                                    id: commandStrip
                                    anchors.fill: parent

                                    Item { Layout.preferredWidth: 5; }

                                    Controls.CommandAddUrlButton {
                                        id: addUrlButton
                                        text: "Add Url"
                                        onClicked: appRoot.openAddUrlDialog()
                                    }

                                    Item { Layout.preferredWidth: 5; }

                                    Item {
                                        Layout.preferredWidth: 128
                                        Layout.preferredHeight: 72
                                        Layout.fillWidth: true

                                        Flickable {
                                            id: commandStripFlickable
                                            anchors.fill: parent
                                            contentWidth: commandRow.implicitWidth
                                            contentHeight: height
                                            flickableDirection: Flickable.HorizontalFlick
                                            boundsBehavior: Flickable.StopAtBounds
                                            clip: true

                                            RowLayout {
                                                id: commandRow
                                                spacing: 32
                                                anchors.fill: parent

                                                Controls.CommandActionButton {
                                                    text: "Resume"
                                                    iconGlyph: "\uf04b"
                                                    enabled: appRoot.canResumeAction()
                                                    onClicked: appRoot.applyActionToCheckedOrSelected("resume")
                                                }
                                                Controls.CommandActionButton {
                                                    text: "Stop"
                                                    iconGlyph: "\uf28d"
                                                    enabled: appRoot.canStopAction()
                                                    onClicked: appRoot.applyActionToCheckedOrSelected("pause")
                                                }
                                                Controls.CommandActionButton {
                                                    text: "Stop All"
                                                    iconGlyph: "\uf28d"
                                                    enabled: appRoot.canStopAllAction()
                                                    onClicked: appRoot.applyActionToCheckedOrSelected("pause")
                                                }

                                                Controls.VerticalLine {}

                                                Controls.CommandActionButton {
                                                    text: "Delete"
                                                    iconGlyph: "\uf2ed"
                                                    enabled: appRoot.hasSelection || appRoot.checkedTaskCount() > 0
                                                    onClicked: appRoot.applyActionToCheckedOrSelected("remove")
                                                }
                                                Controls.CommandActionButton {
                                                    text: "Options"
                                                    iconGlyph: "\uf013"
                                                    enabled: appRoot.hasSelection || appRoot.checkedTaskCount() > 0
                                                    onClicked: appRoot.openPropertiesForSelection()
                                                }
                                                Controls.CommandActionButton {
                                                    text: "Queues"
                                                    iconGlyph: "\uf0ca"
                                                    onClicked: appRoot.openConfigurationDialog(1)
                                                }
                                                Controls.CommandActionButton {
                                                    text: "Schedule"
                                                    iconGlyph: "\uf073"
                                                    onClicked: appRoot.openConfigurationDialog(1)
                                                }
                                                Controls.CommandActionButton {
                                                    text: "Share"
                                                    iconGlyph: "\uf1e0"
                                                    enabled: appRoot.hasSelection || appRoot.checkedTaskCount() > 0
                                                    onClicked: appRoot.shareSelectedTargets()
                                                }

                                                Item { Layout.preferredWidth: 0; }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        id: commandHeadLight
                                        Layout.preferredWidth: 16
                                        Layout.preferredHeight: 8
                                        Layout.topMargin: -1
                                        Layout.rightMargin: 0
                                        topRightRadius: 1
                                        bottomRightRadius: 2
                                        color: Colors.staticPrimary
                                        radius: Metrics.innerRadius
                                        border.width: 1
                                        border.color: Colors.borderActivated

                                        Shadow {
                                            offset.x: -5
                                            offset.y: 0
                                            Layout.preferredWidth: 16
                                            Layout.preferredHeight: 8
                                            color: Colors.staticPrimary
                                            radius: width
                                            spread: -3
                                            blur: 32
                                            z:-1
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            Layout.preferredHeight: 2
                            color: Colors.lineBorderActivated

                        }

                        ColumnLayout {
                            id: downloadsPane
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.margins: Metrics.padding
                            spacing: Metrics.padding * 1.5

                            readonly property real tableWidth: Math.max(0, width - 36)
                            readonly property real colSpacing: 8
                            readonly property real selectCol: 28
                            readonly property real transferCol: Math.max(220, Math.min(270, tableWidth * 0.25))
                            readonly property real statusCol: Math.max(170, Math.min(200, tableWidth * 0.18))
                            readonly property real fixedCols: selectCol + transferCol + statusCol
                            readonly property int totalCols: 4
                            readonly property real nameCol: Math.max(300, tableWidth - fixedCols - colSpacing * Math.max(0, totalCols - 4) )

                            RowLayout {
                                Layout.fillWidth: true

                                Controls.Label {
                                    text: "Downloads"
                                    font.pixelSize: Typography.h3
                                    font.bold: true
                                }
                                Item { Layout.fillWidth: true }
                                Controls.Label {
                                    text: downloadManager.model.filteredCount(appRoot.queueFilter, appRoot.statusFilter, appRoot.categoryFilter, appRoot.searchText)
                                          + " visible"
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Metrics.padding

                                Controls.TextField {
                                    Layout.fillWidth: true
                                    placeholderText: "Search by file name or URL"
                                    text: appRoot.searchText
                                    onTextChanged: appRoot.searchText = text
                                }
                                Controls.ComboBox {
                                    Layout.preferredWidth: 170
                                    model: appRoot.statusOptions
                                    currentIndex: Math.max(0, appRoot.statusOptions.indexOf(appRoot.statusFilter))
                                    onCurrentIndexChanged: {
                                        if (currentIndex < 0 || currentIndex >= appRoot.statusOptions.length)
                                            return
                                        appRoot.setStatusScope(appRoot.statusOptions[currentIndex])
                                    }
                                }
                                Controls.ComboBox {
                                    Layout.preferredWidth: 170
                                    model: appRoot.sortOptions
                                    currentIndex: appRoot.sortIndex
                                    onActivated: appRoot.sortIndex = currentIndex
                                }
                                Controls.Button {
                                    isDefault: false
                                    Layout.preferredWidth: 90
                                    text: appRoot.sortAscending ? "Asc" : "Desc"
                                    onClicked: appRoot.sortAscending = !appRoot.sortAscending
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Item { Layout.preferredWidth: 3 }

                                Controls.CheckBox {
                                    id: selectAllCheckBox
                                    Layout.preferredWidth: downloadsPane.selectCol
                                    Layout.minimumWidth: downloadsPane.selectCol
                                    Layout.maximumWidth: downloadsPane.selectCol
                                    enabled: appRoot.visibleTaskCount() > 0
                                    checked: appRoot.areAllVisibleChecked()
                                    onToggled: {
                                        if (!checked) {
                                            appRoot.clearCheckedTasks()
                                            return
                                        }
                                        appRoot.checkedTaskRows = appRoot.visibleTaskRows()
                                    }
                                }

                                Item { Layout.preferredWidth: 1 }

                                Controls.Label {
                                    Layout.preferredWidth: downloadsPane.nameCol
                                    Layout.minimumWidth: downloadsPane.nameCol
                                    Layout.maximumWidth: downloadsPane.nameCol
                                    font.pixelSize: Typography.t3
                                    text: "Items"
                                    font.bold: true
                                }

                                Controls.Label {
                                    Layout.preferredWidth: downloadsPane.transferCol
                                    Layout.minimumWidth: downloadsPane.transferCol
                                    Layout.maximumWidth: downloadsPane.transferCol
                                    font.pixelSize: Typography.t3
                                    text: "Activity"
                                    font.bold: true
                                }

                                Controls.Label {
                                    Layout.preferredWidth: downloadsPane.statusCol
                                    Layout.minimumWidth: downloadsPane.statusCol
                                    Layout.maximumWidth: downloadsPane.statusCol
                                    font.pixelSize: Typography.t3
                                    text: "Progress"
                                    font.bold: true
                                }

                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                color: "transparent"

                                ListView {
                                    id: downloadList
                                    anchors.fill: parent
                                    model: downloadManager.model
                                    spacing: 0
                                    clip: true
                                    reuseItems: true
                                    boundsBehavior: Flickable.StopAtBounds

                                    delegate: Rectangle {
                                        id: downloadItem
                                        required property int index
                                        required property string fileName
                                        required property string status
                                        required property real bytesReceived
                                        required property real bytesTotal
                                        required property string queueName
                                        required property string category
                                        required property var task
                                        readonly property int rowIndex: index

                                        readonly property string urlText: task ? task.url() : ""
                                        readonly property real ratio: status === "Done"
                                                                      ? 1.0
                                                                      : (bytesTotal > 0 ? Math.min(1.0, bytesReceived / bytesTotal) : 0.0)
                                        readonly property bool accepted: appRoot.rowAccepted(queueName, status, category, fileName, urlText)
                                        readonly property bool isCheckedRow: appRoot.isTaskChecked(task)
                                        readonly property bool isPrimarySelectedRow: appRoot.selectedTaskIndex === downloadItem.index
                                        readonly property bool isFocusedRow: isPrimarySelectedRow || isCheckedRow

                                        function setColor() {
                                            if (status === "Done")
                                                return Colors.successBack
                                            if (status === "Paused")
                                                return Colors.warningBack
                                            if (status === "Error")
                                                return Colors.errorBack
                                            if (status === "Active")
                                                return Colors.primaryBack
                                            return Colors.backgroundItemActivated
                                        }

                                        visible: accepted
                                        width: ListView.view.width
                                        height: accepted ? 72 : 0
                                        color: "transparent"
                                        readonly property real rowGap: 8

                                        Rectangle {
                                            id: rowCard
                                            anchors.fill: parent
                                            anchors.bottomMargin: downloadItem.rowGap
                                            color: appRoot.selectedTaskIndex === downloadItem.index ? setColor() : Colors.backgroundItemActivated
                                            Behavior on color { ColorAnimation { duration: Animations.slow; easing.type: Easing.OutCubic } }
                                            radius: Metrics.innerRadius

                                            gradient: Gradient {
                                                orientation: Gradient.Horizontal
                                                GradientStop { position: 1.0; color: "transparent" }
                                                GradientStop { position: 0.66; color: "transparent" }
                                                GradientStop { position: 0.0; color: Colors.backgroundItemActivated }
                                            }
                                        }

                                        Rectangle {
                                            id: selectedItemRect
                                            anchors.fill: rowCard
                                            radius: Metrics.innerRadius
                                            visible: downloadItem.isFocusedRow
                                            border.color: setColor()
                                            border.width: 1
                                            color: "transparent"

                                            readonly property real loadingMargin: 0
                                            readonly property real loadingLowOpacity: 0.06
                                            readonly property real loadingHighOpacity: 0.30
                                            readonly property int loadingDuration: Animations.veryslow

                                            Behavior on opacity {
                                                NumberAnimation {
                                                    duration: Animations.slow
                                                    easing.type: Easing.OutCubic
                                                }
                                            }

                                            Rectangle {
                                                anchors.fill: parent
                                                radius: selectedItemRect.radius
                                                color: Qt.rgba(setColor().r, setColor().g, setColor().b, 0.08)
                                            }

                                            Item {
                                                id: loadingSource
                                                anchors.fill: parent
                                                visible: true
                                                opacity: 0.0
                                                layer.enabled: true

                                                Item {
                                                    id: loadingViewport
                                                    anchors.fill: parent
                                                    anchors.leftMargin: selectedItemRect.loadingMargin
                                                    anchors.rightMargin: selectedItemRect.loadingMargin
                                                    clip: true

                                                    Rectangle {
                                                        id: loadingGradientRect
                                                        width: loadingViewport.width * 1.8
                                                        height: loadingViewport.height
                                                        x: -width
                                                        y: 0
                                                        color: "transparent"

                                                        gradient: Gradient {
                                                            orientation: Gradient.Horizontal
                                                            GradientStop { position: 0.00; color: Qt.rgba(setColor().r, setColor().g, setColor().b, 0.00) }
                                                            GradientStop { position: 0.18; color: Qt.rgba(setColor().r, setColor().g, setColor().b, selectedItemRect.loadingLowOpacity) }
                                                            GradientStop { position: 0.45; color: Qt.rgba(setColor().r, setColor().g, setColor().b, selectedItemRect.loadingHighOpacity) }
                                                            GradientStop { position: 0.72; color: Qt.rgba(setColor().r, setColor().g, setColor().b, 0.10) }
                                                            GradientStop { position: 1.00; color: Qt.rgba(setColor().r, setColor().g, setColor().b, 0.00) }
                                                        }

                                                        NumberAnimation on x {
                                                            from: -loadingGradientRect.width + loadingViewport.width * 0.15
                                                            to: loadingViewport.width - loadingViewport.width * 0.15
                                                            duration: selectedItemRect.loadingDuration
                                                            loops: 1
                                                            running: selectedItemRect.visible
                                                            easing.type: Easing.Linear
                                                        }
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                id: loadingMask
                                                anchors.fill: parent
                                                radius: selectedItemRect.radius
                                                color: "white"
                                                visible: true
                                                opacity: 0.0
                                                layer.enabled: true
                                            }

                                            MultiEffect {
                                                id: loadingEffect
                                                anchors.fill: parent
                                                source: loadingSource
                                                maskEnabled: true
                                                maskSource: loadingMask
                                                maskThresholdMin: 0.0
                                                maskThresholdMax: 1.0
                                                maskSpreadAtMin: 0.0
                                                maskSpreadAtMax: 0.0
                                                visible: selectedItemRect.visible
                                            }
                                        }

                                        RowLayout {
                                            anchors.fill: rowCard
                                            anchors.margins: Metrics.padding
                                            spacing: downloadsPane.colSpacing

                                            Controls.CheckBox {
                                                id: rowCheckBox
                                                Layout.preferredWidth: downloadsPane.selectCol
                                                Layout.minimumWidth: downloadsPane.selectCol
                                                Layout.maximumWidth: downloadsPane.selectCol
                                                Layout.alignment: Qt.AlignVCenter
                                                checked: appRoot.isTaskChecked(task)
                                                enabled: true
                                                onToggled: appRoot.setTaskChecked(task, checked)
                                            }

                                            ColumnLayout {
                                                spacing: 6
                                                Layout.preferredWidth: downloadsPane.nameCol
                                                Layout.minimumWidth: downloadsPane.nameCol
                                                Layout.maximumWidth: downloadsPane.nameCol
                                                Layout.alignment: Qt.AlignVCenter

                                                Controls.Text {
                                                    font.family: FontSystem.getContentFont.name
                                                    Layout.fillWidth: true
                                                    wrapMode: Text.NoWrap
                                                    font.pixelSize: Typography.h5
                                                    font.weight: Font.Bold
                                                    text: appRoot.baseName(downloadItem.fileName)
                                                    maximumLineCount: 1
                                                    elide: Text.ElideRight
                                                    color: Colors.textPrimary
                                                }

                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 8

                                                    Rectangle {
                                                        visible: downloadItem.category.length > 0
                                                        Layout.preferredHeight: 20
                                                        Layout.preferredWidth: categoryChipLabel.implicitWidth + 12
                                                        radius: 10
                                                        color: Qt.rgba(Colors.backgroundItemHovered.r,
                                                                       Colors.backgroundItemHovered.g,
                                                                       Colors.backgroundItemHovered.b, 0.7)
                                                        border.width: 1
                                                        border.color: Qt.rgba(Colors.lineBorderActivated.r,
                                                                              Colors.lineBorderActivated.g,
                                                                              Colors.lineBorderActivated.b, 0.3)

                                                        Controls.Text {
                                                            id: categoryChipLabel
                                                            anchors.centerIn: parent
                                                            text: downloadItem.category
                                                            font.pixelSize: Typography.t5
                                                            color: Colors.textSecondary
                                                        }
                                                    }

                                                    Rectangle {
                                                        visible: downloadItem.queueName.length > 0
                                                        Layout.preferredHeight: 20
                                                        Layout.preferredWidth: queueChipLabel.implicitWidth + 12
                                                        radius: 10
                                                        color: Qt.rgba(Colors.backgroundItemHovered.r,
                                                                       Colors.backgroundItemHovered.g,
                                                                       Colors.backgroundItemHovered.b, 0.48)
                                                        border.width: 1
                                                        border.color: Qt.rgba(Colors.lineBorderActivated.r,
                                                                              Colors.lineBorderActivated.g,
                                                                              Colors.lineBorderActivated.b, 0.22)

                                                        Controls.Text {
                                                            id: queueChipLabel
                                                            anchors.centerIn: parent
                                                            text: downloadItem.queueName
                                                            font.pixelSize: Typography.t5
                                                            color: Colors.textSecondary
                                                        }
                                                    }

                                                    Item { Layout.fillWidth: true }
                                                }
                                            }

                                            ColumnLayout {
                                                spacing: 6
                                                Layout.preferredWidth: downloadsPane.transferCol
                                                Layout.minimumWidth: downloadsPane.transferCol
                                                Layout.maximumWidth: downloadsPane.transferCol
                                                Layout.alignment: Qt.AlignVCenter

                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 6

                                                    Controls.Text {
                                                        text: "\uf15c"
                                                        font.family: FontSystem.getAwesomeSolid.name
                                                        font.pixelSize: Typography.t5
                                                        color: Colors.textSecondary
                                                    }

                                                    Controls.Text {
                                                        Layout.fillWidth: true
                                                        text: appRoot.formatBytes(bytesReceived) + (bytesTotal > 0 ? " / " + appRoot.formatBytes(bytesTotal) : "")
                                                        maximumLineCount: 1
                                                        elide: Text.ElideRight
                                                        font.pixelSize: Typography.t3
                                                        font.weight: Font.DemiBold
                                                        color: Colors.textPrimary
                                                    }
                                                }

                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 8

                                                    RowLayout {
                                                        spacing: 4

                                                        Controls.Text {
                                                            text: "\uf0e7"
                                                            font.family: FontSystem.getAwesomeSolid.name
                                                            font.pixelSize: Typography.t5
                                                            color: Colors.textSecondary
                                                        }

                                                        Controls.Text {
                                                            text: task ? appRoot.formatSpeed(task.speed) : "0 B/s"
                                                            font.pixelSize: Typography.t4
                                                            color: Colors.textSecondary
                                                            opacity: 0.82
                                                        }
                                                    }
                                                }
                                            }

                                            ColumnLayout {
                                                Layout.preferredWidth: downloadsPane.statusCol
                                                Layout.minimumWidth: downloadsPane.statusCol
                                                Layout.maximumWidth: downloadsPane.statusCol
                                                Layout.alignment: Qt.AlignVCenter
                                                spacing: 6

                                                Rectangle {
                                                    Layout.alignment: Qt.AlignTop
                                                    Layout.fillWidth: false
                                                    Layout.preferredWidth: 134
                                                    Layout.minimumWidth: 134
                                                    Layout.maximumWidth: 134
                                                    Layout.preferredHeight: 18
                                                    color: Colors.backgroundActivated
                                                    border.color: Colors.borderActivated
                                                    border.width: 1

                                                    radius: Metrics.outerRadius

                                                Controls.ProgressBar {
                                                    anchors.centerIn: parent
                                                    Layout.preferredWidth: 128
                                                    Layout.minimumWidth: 128
                                                    Layout.maximumWidth: 128
                                                    implicitWidth: 128
                                                    implicitHeight: 12
                                                    value: downloadItem.ratio
                                                    indeterminate: bytesTotal <= 0 && downloadItem.status === "Active"
                                                    statusLevel: downloadItem.status

                                                    RowLayout {
                                                        anchors.fill: parent
                                                        Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter

                                                        Item { Layout.preferredWidth: 5 }

                                                        Controls.Text {
                                                            text: appRoot.taskStatusText(downloadItem.task, downloadItem.status)
                                                            maximumLineCount: 1
                                                            elide: Text.ElideRight
                                                            font.pixelSize: Typography.t5
                                                            color: (downloadItem.status === "Paused" && downloadItem.bytesReceived < 1)
                                                                   ? Colors.textPrimary
                                                                   : Colors.staticPrimary
                                                        }

                                                        Item { Layout.fillWidth: true }

                                                        Controls.Text {
                                                            text: downloadItem.bytesTotal > 0
                                                                  ? (Math.round(downloadItem.ratio * 100) + "%")
                                                                  : (downloadItem.status === "Done" ? "100%" : "--")
                                                            maximumLineCount: 1
                                                            elide: Text.ElideRight
                                                            font.pixelSize: Typography.t5
                                                            color: Colors.staticPrimary
                                                        }

                                                        Item { Layout.preferredWidth: 5 }
                                                    }
                                                }

                                                }

                                                RowLayout {
                                                    Layout.preferredWidth: 148
                                                    Layout.minimumWidth: 148
                                                    Layout.maximumWidth: 148
                                                    spacing: 10

                                                    Controls.Text {
                                                        text: "\uf017"
                                                        font.family: FontSystem.getAwesomeSolid.name
                                                        font.pixelSize: Typography.t5
                                                        color: Colors.textSecondary
                                                    }

                                                    Controls.Text {
                                                        text: task ? appRoot.formatEta(task.eta) : "--"
                                                        maximumLineCount: 1
                                                        elide: Text.ElideRight
                                                        font.pixelSize: Typography.t4
                                                        color: Colors.textSecondary
                                                        opacity: 0.82
                                                    }

                                                    Controls.Text {
                                                        text: "\uf0ae"
                                                        font.family: FontSystem.getAwesomeSolid.name
                                                        font.pixelSize: Typography.t5
                                                        color: Colors.textSecondary
                                                    }

                                                    Controls.Text {
                                                        text: (task ? (task.effectiveSegments() + "/" + task.segments()) : "0/0")
                                                        maximumLineCount: 1
                                                        elide: Text.ElideRight
                                                        font.pixelSize: Typography.t4
                                                        color: Colors.textSecondary
                                                        opacity: 0.82
                                                    }
                                                }
                                            }



                                        }

                                        MouseArea {
                                            anchors.fill: rowCard
                                            anchors.leftMargin: downloadsPane.selectCol + downloadsPane.colSpacing
                                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                                            propagateComposedEvents: true
                                            onClicked: function(mouse) {
                                                appRoot.selectTask(rowIndex, task, queueName, category)
                                                if (mouse.button === Qt.RightButton) {
                                                    rowMenu.popup(mouse.x + 4, mouse.y + 4)
                                                }
                                                mouse.accepted = false
                                            }
                                            onDoubleClicked: function(mouse) {
                                                if (mouse.button === Qt.LeftButton)
                                                    appRoot.openDetailsFor(rowIndex, task, queueName, category)
                                            }
                                        }

                                        Controls.AppMenu {
                                            id: rowMenu
                                            implicitWidth: 332

                                            Controls.AppMenuItem {
                                                text: "Open"
                                                iconGlyph: "\uf15c"
                                                enabled: status === "Done"
                                                onTriggered: appRoot.executeRowAction(rowIndex, task, "open", queueName, category)
                                            }
                                            Controls.AppMenuItem {
                                                text: "Open With"
                                                iconGlyph: "\uf35d"
                                                enabled: status === "Done"
                                                onTriggered: appRoot.executeRowAction(rowIndex, task, "open", queueName, category)
                                            }
                                            Controls.AppMenuItem {
                                                text: "Open Folder"
                                                iconGlyph: "\uf07c"
                                                onTriggered: appRoot.executeRowAction(rowIndex, task, "reveal", queueName, category)
                                            }
                                            //ToDo...
                                            // Controls.AppMenuSeparator {}
                                            // Controls.AppMenuItem {
                                            //     text: "Move/Rename"
                                            //     iconGlyph: "\uf246"
                                            //     onTriggered: appRoot.executeRowAction(rowIndex, task, "properties", queueName, category)
                                            // }
                                            Controls.AppMenuSeparator {}
                                            Controls.AppMenuItem {
                                                text: "Redownload"
                                                iconGlyph: "\uf2f1"
                                                onTriggered: appRoot.executeRowAction(rowIndex, task, "retry", queueName, category)
                                            }
                                            Controls.AppMenuSeparator {}
                                            Controls.AppMenuItem {
                                                text: "Resume Download"
                                                iconGlyph: "\uf04b"
                                                enabled: status === "Paused"
                                                onTriggered: appRoot.executeRowAction(rowIndex, task, "resume", queueName, category)
                                            }
                                            Controls.AppMenuItem {
                                                text: "Stop Download"
                                                iconGlyph: "\uf28d"
                                                enabled: status === "Active"
                                                onTriggered: appRoot.executeRowAction(rowIndex, task, "pause", queueName, category)
                                            }
                                            Controls.AppMenuItem {
                                                text: "Refresh Download Address"
                                                iconGlyph: "\uf021"
                                                onTriggered: appRoot.executeRowAction(rowIndex, task, "retry", queueName, category)
                                            }
                                            Controls.AppMenuSeparator {}
                                            Controls.AppMenu {
                                                title: "Add to queue"
                                                Repeater {
                                                    model: downloadManager.queueNames
                                                    delegate: Controls.AppMenuItem {
                                                        required property string modelData
                                                        text: modelData
                                                        iconGlyph: "\uf07b"
                                                        enabled: modelData !== queueName
                                                        onTriggered: {
                                                            downloadManager.setTaskQueue(rowIndex, modelData)
                                                            if (appRoot.selectedTaskIndex === rowIndex)
                                                                appRoot.selectedQueue = modelData
                                                        }
                                                    }
                                                }
                                            }
                                            Controls.AppMenuItem {
                                                text: "Remove"
                                                iconGlyph: "\uf2ed"
                                                onTriggered: appRoot.executeRowAction(rowIndex, task, "remove", queueName, category)
                                            }
                                            Controls.AppMenuItem {
                                                text: "Delete from Queue"
                                                iconGlyph: "\uf2ed"
                                                enabled: queueName !== downloadManager.defaultQueueName()
                                                onTriggered: {
                                                    const fallback = downloadManager.defaultQueueName()
                                                    downloadManager.setTaskQueue(rowIndex, fallback)
                                                    if (appRoot.selectedTaskIndex === rowIndex)
                                                        appRoot.selectedQueue = fallback
                                                }
                                            }
                                            Controls.AppMenuSeparator {}
                                            Controls.AppMenuItem {
                                                text: "Properties"
                                                iconGlyph: "\uf05a"
                                                onTriggered: appRoot.executeRowAction(rowIndex, task, "properties", queueName, category)
                                            }
                                        }
                                    }

                                    footer: Label {
                                        visible: downloadManager.model.filteredCount(appRoot.queueFilter, appRoot.statusFilter, appRoot.categoryFilter, appRoot.searchText) === 0
                                        width: downloadList.width
                                        horizontalAlignment: Text.AlignHCenter
                                        text: "No downloads match current filters"
                                        padding: 16
                                        color: Colors.textMuted
                                    }

                                    ScrollBar.vertical: ScrollBar { }
                                }
                            }
                        }

                        GroupBox {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 42

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Metrics.padding
                                anchors.rightMargin: Metrics.padding

                                Controls.Label {
                                    text: "Visible: "
                                          + downloadManager.model.filteredCount(appRoot.queueFilter, appRoot.statusFilter, appRoot.categoryFilter, appRoot.searchText)
                                }
                                Controls.Label { text: "Total speed: " + appRoot.formatSpeed(downloadManager.totalSpeed) }
                                Controls.Label {
                                    text: "Overall: "
                                          + (downloadManager.totalSize > 0
                                             ? (100 * downloadManager.totalReceived / downloadManager.totalSize).toFixed(1)
                                             : "0.0") + "%"
                                }
                                Controls.Label {
                                    text: "Selected: "
                                          + (appRoot.selectedTask ? appRoot.baseName(appRoot.taskFileNameValue(appRoot.selectedTask)) : "None")
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                }
            }


            ScrollView {
                clip: true
                ColumnLayout {
                    width: Math.max(parent.width, 800)
                    spacing: 12

                    GroupBox {
                        id: queuesGroup
                        title: "Queues"
                        Layout.fillWidth: true
                        readonly property real _extraContentMargins: 16
                        Layout.preferredHeight: queuesGroupContent.implicitHeight
                                                + topPadding + bottomPadding
                                                + _extraContentMargins

                        ColumnLayout {
                            id: queuesGroupContent
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 8
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                ComboBox {
                                    id: queueEditorCombo
                                    Layout.preferredWidth: 240
                                    model: downloadManager.queueNames
                                    currentIndex: Math.max(0, downloadManager.queueNames.indexOf(appRoot.queueEditorName))
                                    onActivated: {
                                        appRoot.queueEditorName = currentText
                                        appRoot.loadQueueEditor()
                                    }
                                }
                                Item { Layout.fillWidth: true }
                                Button { text: "Apply Policy"; onClicked: appRoot.applyQueueEditor() }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                TextField { id: newQueueField; Layout.fillWidth: true; placeholderText: "New queue name" }
                                Button {
                                    text: "Create"
                                    enabled: newQueueField.text.trim().length > 0
                                    onClicked: {
                                        if (appRoot.createQueueFromEditor(newQueueField.text.trim()))
                                            newQueueField.text = ""
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                TextField { id: renameQueueField; Layout.fillWidth: true; placeholderText: "Rename selected queue" }
                                Button {
                                    text: "Rename"
                                    enabled: appRoot.queueEditorName.length > 0 && renameQueueField.text.trim().length > 0
                                    onClicked: {
                                        if (appRoot.renameCurrentQueueTo(renameQueueField.text.trim()))
                                            renameQueueField.text = ""
                                    }
                                }
                                Button {
                                    text: "Remove"
                                    enabled: appRoot.queueEditorName.length > 0 && appRoot.queueEditorName !== downloadManager.defaultQueueName()
                                    onClicked: {
                                        appRoot.removeCurrentQueue()
                                    }
                                }
                            }

                            Label {
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                color: Colors.textSecondary
                                text: "Queues are fully editable here. Create a new queue, rename the selected queue, or remove any non-default queue. Existing downloads assigned to a removed queue automatically fall back to the default queue."
                            }
                        }
                    }

                    GroupBox {
                        id: queuePolicyGroup
                        title: "Queue Policy"
                        Layout.fillWidth: true
                        readonly property real _extraContentMargins: 16
                        Layout.preferredHeight: queuePolicyGrid.implicitHeight
                                                + topPadding + bottomPadding
                                                + _extraContentMargins

                        GridLayout {
                            id: queuePolicyGrid
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 8
                            columns: 2
                            rowSpacing: 8
                            columnSpacing: 12

                            Label { text: "Max concurrent" }
                            SpinBox { id: queueConcurrentSpin; from: 1; to: 64; value: 2 }

                            Label { text: "Max speed (MB/s)" }
                            SpinBox { id: queueSpeedSpin; from: 0; to: 4096; value: 0 }

                            Label { text: "Enable schedule" }
                            Switch { id: queueScheduleSwitch }

                            Label { text: "Start minute" }
                            SpinBox { id: queueStartSpin; from: 0; to: 1439; value: 0 }

                            Label { text: "End minute" }
                            SpinBox { id: queueEndSpin; from: 0; to: 1439; value: 0 }

                            Label { text: "Enable quota" }
                            Switch { id: queueQuotaSwitch }

                            Label { text: "Quota (GB/day)" }
                            SpinBox { id: queueQuotaSpin; from: 0; to: 100000; value: 0 }

                            Label { text: "Downloaded today" }
                            Label {
                                text: appRoot.queueEditorName.length > 0
                                      ? appRoot.formatBytes(downloadManager.queueDownloadedToday(appRoot.queueEditorName))
                                      : "0 B"
                            }
                        }
                    }
                }
            }

            ScrollView {
                clip: true
                ColumnLayout {
                    width: Math.max(parent.width, 760)
                    spacing: 12

                    GroupBox {
                        id: networkDefaultsGroup
                        title: "Network Defaults"
                        Layout.fillWidth: true
                        readonly property real _extraContentMargins: 16
                        Layout.preferredHeight: networkDefaultsGrid.implicitHeight
                                                + topPadding + bottomPadding
                                                + _extraContentMargins

                        GridLayout {
                            id: networkDefaultsGrid
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 8
                            columns: 2
                            rowSpacing: 8
                            columnSpacing: 12

                            Label { text: "User-Agent" }
                            TextField {
                                Layout.fillWidth: true
                                text: downloadManager.defaultUserAgent
                                onEditingFinished: downloadManager.defaultUserAgent = text
                            }

                            Label { text: "Proxy host" }
                            TextField {
                                Layout.fillWidth: true
                                text: downloadManager.defaultProxyHost
                                onEditingFinished: downloadManager.defaultProxyHost = text
                            }

                            Label { text: "Proxy port" }
                            SpinBox {
                                from: 0
                                to: 65535
                                value: downloadManager.defaultProxyPort
                                onValueModified: downloadManager.defaultProxyPort = value
                            }

                            Label { text: "Proxy user" }
                            TextField {
                                Layout.fillWidth: true
                                text: downloadManager.defaultProxyUser
                                onEditingFinished: downloadManager.defaultProxyUser = text
                            }

                            Label { text: "Proxy password" }
                            TextField {
                                Layout.fillWidth: true
                                echoMode: TextInput.Password
                                text: downloadManager.defaultProxyPassword
                                onEditingFinished: downloadManager.defaultProxyPassword = text
                            }

                            Label { text: "Allow insecure SSL" }
                            Switch {
                                checked: downloadManager.defaultAllowInsecureSsl
                                onToggled: downloadManager.defaultAllowInsecureSsl = checked
                            }

                            Label { text: "Per-host concurrent" }
                            SpinBox {
                                from: 1
                                to: 64
                                value: downloadManager.perHostMaxConcurrent
                                onValueModified: downloadManager.perHostMaxConcurrent = value
                            }

                            Label { text: "Persist sensitive options" }
                            Switch {
                                checked: downloadManager.persistSensitiveOptions
                                onToggled: downloadManager.persistSensitiveOptions = checked
                            }

                            Label { text: "Telemetry" }
                            Switch {
                                checked: downloadManager.telemetryEnabled
                                onToggled: downloadManager.telemetryEnabled = checked
                            }

                            Label { text: "Pause on battery" }
                            Switch {
                                checked: downloadManager.pauseOnBattery
                                onToggled: downloadManager.pauseOnBattery = checked
                            }

                            Label { text: "Resume on AC" }
                            Switch {
                                checked: downloadManager.resumeOnAC
                                onToggled: downloadManager.resumeOnAC = checked
                            }

                            Label { text: "Power source" }
                            Label { text: downloadManager.onBattery ? "Battery" : "AC" }
                        }
                    }

                    GroupBox {
                        id: urlProbeGroup
                        title: "URL Probe"
                        Layout.fillWidth: true
                        readonly property real _extraContentMargins: 16
                        Layout.preferredHeight: urlProbeContent.implicitHeight
                                                + topPadding + bottomPadding
                                                + _extraContentMargins

                        ColumnLayout {
                            id: urlProbeContent
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 8
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                TextField {
                                    id: probeUrlField
                                    Layout.fillWidth: true
                                    placeholderText: "https://example.com/file.zip"
                                }
                                Button {
                                    text: downloadManager.networkTestRunning ? "Testing..." : "Run Test"
                                    enabled: !downloadManager.networkTestRunning && probeUrlField.text.trim().length > 0
                                    onClicked: downloadManager.testUrl(probeUrlField.text.trim())
                                }
                            }

                            Label {
                                text: downloadManager.networkTestMessage
                                wrapMode: Text.Wrap
                            }
                        }
                    }
                }
            }

            ScrollView {
                clip: true
                ColumnLayout {
                    width: Math.max(parent.width, 760)
                    spacing: 12

                    GroupBox {
                        id: updateClientGroup
                        title: "Update Client"
                        Layout.fillWidth: true
                        readonly property real _extraContentMargins: 16
                        Layout.preferredHeight: updateClientGrid.implicitHeight
                                                + topPadding + bottomPadding
                                                + _extraContentMargins

                        GridLayout {
                            id: updateClientGrid
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 8
                            columns: 2
                            rowSpacing: 8
                            columnSpacing: 12

                            Label { text: "Current version" }
                            Label { text: updateClient.currentVersion }

                            Label { text: "Latest version" }
                            Label { text: updateClient.latestVersion.length > 0 ? updateClient.latestVersion : "--" }

                            Label { text: "Channel" }
                            ComboBox {
                                id: channelCombo
                                model: ["stable", "beta"]
                                currentIndex: Math.max(0, ["stable", "beta"].indexOf(updateClient.channel))
                                onActivated: updateClient.channel = currentText
                            }

                            Label { text: "Source" }
                            ComboBox {
                                id: sourceCombo
                                model: ["auto", "website", "github"]
                                currentIndex: Math.max(0, ["auto", "website", "github"].indexOf(updateClient.sourcePreference))
                                onActivated: updateClient.sourcePreference = currentText
                            }

                            Label { text: "GitHub repo" }
                            TextField {
                                Layout.fillWidth: true
                                text: updateClient.githubRepo
                                onEditingFinished: updateClient.githubRepo = text
                            }

                            Label { text: "Manifest URL" }
                            TextField {
                                Layout.fillWidth: true
                                text: updateClient.manifestUrl
                                onEditingFinished: updateClient.manifestUrl = text
                            }

                            Label { text: "Check on startup" }
                            Label { text: "Always" }

                            Label { text: "Update mode" }
                            ComboBox {
                                model: ["custom", "automatic"]
                                currentIndex: Math.max(0, ["custom", "automatic"].indexOf(updateClient.updateMode))
                                onActivated: updateClient.updateMode = currentText
                            }

                            Label { text: "Require signature" }
                            Switch {
                                checked: updateClient.requireSignature
                                onToggled: updateClient.requireSignature = checked
                            }

                            Label { text: "Public key" }
                            TextField {
                                Layout.fillWidth: true
                                text: updateClient.publicKeyPath
                                onEditingFinished: updateClient.publicKeyPath = text
                            }
                        }
                    }

                    GroupBox {
                        title: "Update Status"
                        Layout.fillWidth: true

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8

                            ProgressBar {
                                Layout.fillWidth: true
                                value: Math.max(0.0, Math.min(1.0, updateClient.downloadProgress))
                                indeterminate: updateClient.status.toLowerCase().indexOf("downloading") >= 0
                                               && updateClient.downloadProgress <= 0
                            }

                            Label {
                                text: "Status: " + updateClient.status
                            }
                            Label {
                                text: updateClient.lastError.length > 0 ? ("Error: " + updateClient.lastError) : ""
                                visible: updateClient.lastError.length > 0
                                wrapMode: Text.Wrap
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Button { text: "Check Now"; onClicked: updateClient.checkNow() }
                                Button {
                                    text: "Download"
                                    enabled: updateClient.updateAvailable
                                    onClicked: updateClient.downloadUpdate()
                                }
                                Button {
                                    text: "Install"
                                    enabled: updateClient.downloadReady
                                    onClicked: updateClient.installUpdate()
                                }
                                Item { Layout.fillWidth: true }
                                Label {
                                    text: updateClient.signatureVerified ? "Signature verified" : ""
                                    visible: updateClient.signatureVerified
                                }
                            }

                            TextArea {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 180
                                readOnly: true
                                text: updateClient.releaseNotes
                                placeholderText: "Release notes"
                            }
                        }
                    }

                    GroupBox {
                        title: "Configuration"
                        Layout.fillWidth: true

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8

                            Label {
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                                text: "Restore RAAD defaults and clear persisted session/configuration state without deleting downloaded files."
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Button {
                                    text: "Reset All"
                                    onClicked: resetSettingsDialog.open()
                                }
                                Item { Layout.fillWidth: true }
                            }
                        }
                    }
                }
            }

        }

        GroupBox {
            visible: appRoot.pageIndex !== 0
            Layout.fillWidth: true
            Layout.preferredHeight: 34

            RowLayout {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 8

                Label {
                    text: "Visible: " + downloadManager.model.filteredCount(appRoot.queueFilter, appRoot.statusFilter, appRoot.categoryFilter, appRoot.searchText)
                }
                Label {
                    text: "Total speed: " + appRoot.formatSpeed(downloadManager.totalSpeed)
                }
                Label {
                    text: "Overall: "
                          + (downloadManager.totalSize > 0
                             ? Math.min(100, Math.max(0, (downloadManager.totalReceived / downloadManager.totalSize) * 100)).toFixed(1) + "%"
                             : "--")
                }
                Item { Layout.fillWidth: true }
                Label {
                    text: appRoot.selectedTask
                          ? ("Selected: " + appRoot.baseName(appRoot.taskFileNameValue(appRoot.selectedTask)))
                          : "Selected: None"
                }
            }
        }

    }

}
