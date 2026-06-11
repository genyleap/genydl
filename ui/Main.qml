/*!
    \file        Main.qml
    \brief       Implements the main application window for GENYDL.
    \details     This file defines the primary QML application shell, window structure, and top-level UI workflow for GENYDL.

    \author      Kambiz Asadzadeh <https://github.com/thecompez>
    \copyright   Copyright (c) 2026 Genyleap. All rights reserved.
    \license     https://github.com/genyleap/genydl/blob/main/LICENSE.md
*/

import QtQuick
import QtQuick.Window
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

import GenyDL 1.0

ApplicationWindow {
    id: appRoot
    visible: true

    QtObject {
        id: appAttributes
        property string name: "GenyDL - Internet Download Manager"
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
    property string sourceFilter: "All"
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
    property bool sidebarSourceExpanded: false
    property bool sidebarQueuesExpanded: true
    property var pendingRemoveRows: []
    property var tableRows: []
    property var releaseAssetPickerReleaseInfo: ({})
    property var releaseAssetPickerAssets: []
    property var releaseAssetPickerSourceAssets: []
    property bool releaseAssetPickerLoading: false
    property string releaseAssetPickerError: ""
    // Release Center app row that initiated the asset picker (-1 = ad-hoc URL, not tracked).
    property int releaseAssetPickerAppIndex: -1

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
    readonly property var queuePostActionOptions: ["Do nothing", "Exit application", "Sleep", "Shutdown system"]
    readonly property var queuePostActionIds: ["none", "exit", "sleep", "shutdown"]
    readonly property string donationAddress: "0x6E99f7564d060AA141dcC47ede34379Bad0cDCCC"
    readonly property string donationBaseExplorerUrl: "https://basescan.org/address/0x6E99f7564d060AA141dcC47ede34379Bad0cDCCC"
    readonly property string donationMainnetExplorerUrl: "https://etherscan.io/address/0x6E99f7564d060AA141dcC47ede34379Bad0cDCCC"
    readonly property string developerFarcasterUrl: "https://farcaster.xyz/compez.eth"
    readonly property string developerXUrl: "https://x.com/thecompez"
    readonly property string developerGithubUrl: "https://github.com/thecompez"
    readonly property string projectRepositoryUrl: "https://github.com/genyleap/genydl"
    readonly property string projectLicenseUrl: "https://github.com/genyleap/genydl/blob/main/LICENSE"
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
    readonly property string gplLicenseText: "GNU General Public License v3.0\n\n"
                                              + "Copyright (c) 2026 Genyleap Labs. All rights reserved.\n\n"
                                              + "This program is free software: you can redistribute it and/or modify\n"
                                              + "it under the terms of the GNU General Public License as published by\n"
                                              + "the Free Software Foundation, either version 3 of the License, or\n"
                                              + "(at your option) any later version.\n\n"
                                              + "This program is distributed in the hope that it will be useful,\n"
                                              + "but WITHOUT ANY WARRANTY; without even the implied warranty of\n"
                                              + "MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the\n"
                                              + "GNU General Public License for more details.\n\n"
                                              + "You should have received a copy of the GNU General Public License\n"
                                              + "along with this program.  If not, see <https://www.gnu.org/licenses/>."
    readonly property int fileNameRole: Qt.UserRole + 1
    readonly property int progressRole: Qt.UserRole + 2
    readonly property int finishedRole: Qt.UserRole + 3
    readonly property int taskRole: Qt.UserRole + 4
    readonly property int statusRole: Qt.UserRole + 5
    readonly property int bytesReceivedRole: Qt.UserRole + 6
    readonly property int bytesTotalRole: Qt.UserRole + 7
    readonly property int queueRole: Qt.UserRole + 8
    readonly property int categoryRole: Qt.UserRole + 9

    // Release Center date display format. Persisted via settings UI.
    // Release Center date display format, now persisted by the service.
    // One of: "relative" | "datetime" | "day" | "month"
    readonly property string releaseDateFormat: releaseCenterService.dateFormat

    // Index of the app whose update was last announced (for notification clicks).
    property int lastUpdateAppIndex: -1

    function compactCount(value) { return Utils.compactCount(value) }
    function formatReleaseDate(value) { return Utils.formatReleaseDate(value, appRoot.releaseDateFormat) }

    // Open the GitHub asset picker for a tracked Release Center app (shared by the
    // card, the details dialog, and the one-click update fallback).
    function openAssetPickerForApp(app) {
        appRoot.releaseAssetPickerAppIndex = (app && app.rowIndex !== undefined) ? app.rowIndex : -1
        appRoot.releaseAssetPickerReleaseInfo = {
            repository: app.repository,
            owner: app.owner,
            repo: app.repo,
            displayName: app.displayName || app.repo,
            name: app.latestReleaseName || app.latestTag,
            tagName: app.latestTag,
            body: app.latestBody || "",
            htmlUrl: app.latestHtmlUrl || "",
            publishedAt: app.latestPublishedAt,
            publishedText: app.latestPublishedText || "",
            description: app.description || "",
            avatarUrl: app.avatarUrl || "",
            homepageUrl: app.homepageUrl || "",
            stars: app.stars || 0,
            forks: app.forks || 0,
            language: app.language || "",
            licenseSpdxId: app.licenseSpdxId || ""
        }
        appRoot.releaseAssetPickerAssets = app.latestAssets || []
        appRoot.releaseAssetPickerSourceAssets = app.latestSourceAssets || []
        appRoot.releaseAssetPickerLoading = false
        appRoot.releaseAssetPickerError = appRoot.releaseAssetPickerAssets.length > 0
                ? "" : "This release does not publish downloadable assets."
        githubReleaseAssetPicker.open()
    }

    // One-click update: auto-pick the asset matching this OS/arch and queue it
    // directly. Falls back to the full picker when nothing matches confidently.
    function startAppUpdate(app) {
        if (!app || app.rowIndex === undefined || app.rowIndex < 0) {
            openAssetPickerForApp(app); return
        }
        const picks = releaseCenterService.platformAssetsForApp(app.rowIndex)
        if (!picks || picks.length === 0) {
            openAssetPickerForApp(app); return
        }
        const added = appRoot.submitGitHubReleaseAssets(
                        picks, appRoot.addDefaultOutputPath, appRoot.addDefaultQueue,
                        appRoot.addDefaultCategory, appRoot.addDefaultStartPaused,
                        appRoot.addDefaultSegments, appRoot.addDefaultAdaptive)
        if (added > 0) {
            appRoot.appendNotification("Updating " + (app.displayName || app.repo),
                                       "Downloading " + picks[0].name + " …", "success")
            releaseCenterService.markLatestKnown(app.rowIndex)
            appRoot.pageIndex = 0   // show the download on Home
        }
    }

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
    function setSourceScope() { return Utils.setSourceScope.apply(this, arguments) }
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
    function downloadPathForAsset() { return Utils.downloadPathForAsset.apply(this, arguments) }
    function submitGitHubReleaseAssets() { return Utils.submitGitHubReleaseAssets.apply(this, arguments) }
    function rebuildDownloadTableRows() { return Utils.rebuildDownloadTableRows.apply(this, arguments) }
    function scheduleRebuildDownloadTableRows() { return Utils.scheduleRebuildDownloadTableRows.apply(this, arguments) }
    function addDownloadFromInputs() { return Utils.addDownloadFromInputs.apply(this, arguments) }
    function openAddUrlDialog() { return Utils.openAddUrlDialog.apply(this, arguments) }
    // Open the Add URL dialog pre-filled with a dropped link/file for review.
    function openAddUrlWith(text) {
        appRoot.openAddUrlDialog()
        const t = (text || "").trim()
        if (t.length > 0)
            addDialogUrlField.text = t
    }
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
    function minutesToClockText(minutes) {
        const total = Math.max(0, Math.min(1439, Number(minutes) || 0))
        const hour = Math.floor(total / 60)
        const minute = total % 60
        return String(hour).padStart(2, "0") + ":" + String(minute).padStart(2, "0")
    }
    function clockTextToMinutes(text, fallback) {
        const raw = String(text || "").trim().toLowerCase()
        const match = raw.match(/^(\d{1,2})(?::(\d{1,2}))?\s*(am|pm)?$/)
        if (!match)
            return fallback
        var hour = Number(match[1])
        const minute = match[2] === undefined ? 0 : Number(match[2])
        if (minute < 0 || minute > 59)
            return fallback
        if (match[3] === "am") {
            if (hour === 12) hour = 0
        } else if (match[3] === "pm") {
            if (hour < 12) hour += 12
        }
        if (hour < 0 || hour > 23)
            return fallback
        return hour * 60 + minute
    }
    function queuePostActionIndex(action) {
        const idx = queuePostActionIds.indexOf(action && action.length > 0 ? action : "none")
        return idx >= 0 ? idx : 0
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
        sourceFilter = "All"
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
        property bool keepRunningInBackground: true
        property bool showRuntimeFooter: true
    }

    onClosing: function(close) {
        if (!appController.requestWindowClose(downloadManager.hasActiveDownloads)) {
            close.accepted = false
            if (!appController.trayAvailable) {
                backgroundCloseDialog.open()
            }
        }
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
        id: backgroundCloseDialog
        title: "Downloads still running"
        type: "warning"
        desc: "GenyDL can keep downloads active after the window is closed."
        message: appController.trayAvailable
                 ? "Use the tray icon to restore the main window or exit the application."
                 : "This system does not expose a tray icon right now. Use Exit to stop the application, or cancel and keep the window open."
        standardButtons: Dialog.Cancel | Dialog.Discard
        cancelTextOverride: "Keep Open"
        discardTextOverride: "Exit GenyDL"
        onDiscarded: appController.quitApplication()
    }

    Controls.Dialog {
        id: aboutDialog
        width: Math.min(appRoot.width - 60, 620)
        height: 520

        title: "About GenyDL"
        type: "info"
        desc: "GenyDL Download Manager"
        message: "GenyDL provides segmented downloading, queue control, adaptive segment scheduling, runtime policies, and update delivery in a desktop workflow."

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
                            id: genydlAboutImage
                            anchors.fill: parent
                            anchors.margins: 8
                            source: "qrc:/GenyDL.png"
                            // fillMode: Image.PreserveAspectFit
                            smooth: true
                            asynchronous: true
                            cache: true
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: genydlAboutImage.status !== Image.Ready
                            text: "GENYDL"
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
                            text: "GenyDL Download Manager"
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
                Controls.Label { text: "GenyDL Download Manager" }
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
        message: "Production links for GENYDL, Genyleap, and the developer profile."

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
                            text: "GENYDL"
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
                                    text: "Genyleap Labs home for GENYDL and ecosystem updates."
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
                                    text: "Main open source repository for GENYDL."
                                    color: Colors.textSecondary
                                    font.family: FontSystem.getContentFontRegular.name
                                    font.pixelSize: Typography.t3
                                }

                                Text {
                                    Layout.fillWidth: true
                                    textFormat: Text.RichText
                                    text: "<a href=\"" + appRoot.projectRepositoryUrl + "\"><span style=\"color:#3a86ff;text-decoration:underline;\">"
                                          + appRoot.projectRepositoryUrl + "</span></a>"
                                    onLinkActivated: appRoot.openExternalLink(link, "Opened GENYDL repository")
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
        desc: "GNU General Public License v3.0"
        message: "GENYDL is distributed under the GNU General Public License v3.0. Review the repository and full license text below."

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
                                    text: "Main source repository for GENYDL."
                                    color: Colors.textSecondary
                                    font.family: FontSystem.getContentFontRegular.name
                                    font.pixelSize: Typography.t3
                                }

                                Text {
                                    Layout.fillWidth: true
                                    textFormat: Text.RichText
                                    text: "<a href=\"" + appRoot.projectRepositoryUrl + "\"><span style=\"color:#3a86ff;text-decoration:underline;\">"
                                          + appRoot.projectRepositoryUrl + "</span></a>"
                                    onLinkActivated: appRoot.openExternalLink(link, "Opened GENYDL repository")
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
                                    text: "Published GPL license page in the repository."
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
                                    text: "GENYDL is built with Qt " + Qt.version + ". Review the official Qt open source licensing page."
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
                title: "GNU GPL v3.0 License"
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
                            text: appRoot.gplLicenseText
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
                            onClicked: appRoot.copyToClipboard(appRoot.gplLicenseText, "GPL license copied")
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
        desc: "Support GENYDL on Base and Ethereum MainNet"
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

                        Text {
                            anchors.centerIn: parent
                            text: "$" + appRoot.genyTokenSymbol
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
                if (!torrentSession.available) {
                    addDialogErrorLabel.text = "BitTorrent support is not available in this build."
                    return
                }
                downloadManager.addTorrentDownload(
                            addDialogUrlField.text.trim(),
                            addDialogPathField.text.trim(),
                            addDialogQueueCombo.currentText,
                            addDialogCategoryCombo.currentText,
                            addDialogPausedSwitch.checked)
                appRoot.addDefaultOutputPath = addDialogPathField.text.trim()
                appRoot.addDefaultQueue = addDialogQueueCombo.currentText
                appRoot.addDefaultStartPaused = addDialogPausedSwitch.checked
                addDialogUrlField.text = ""
                addUrlPopup.close()
                return
            }
            if (githubReleaseService.isReleaseUrl(addDialogUrlField.text)) {
                appRoot.addDefaultOutputPath = addDialogPathField.text.trim()
                appRoot.addDefaultQueue = addDialogQueueCombo.currentText
                appRoot.addDefaultCategory = addDialogCategoryCombo.currentText
                appRoot.addDefaultSegments = addDialogSegmentsSpin.value
                appRoot.addDefaultAdaptive = addDialogAdaptiveSwitch.checked
                appRoot.addDefaultStartPaused = addDialogPausedSwitch.checked

                githubReleaseService.clear()
                appRoot.releaseAssetPickerAppIndex = -1
                appRoot.releaseAssetPickerReleaseInfo = githubReleaseService.release
                appRoot.releaseAssetPickerAssets = githubReleaseService.assets
                appRoot.releaseAssetPickerSourceAssets = []
                appRoot.releaseAssetPickerLoading = githubReleaseService.loading
                appRoot.releaseAssetPickerError = githubReleaseService.errorMessage
                githubReleaseAssetPicker.open()
                githubReleaseService.fetchRelease(addDialogUrlField.text)
                addUrlPopup.close()
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

    Controls.Dialog {
        id: releaseCenterAddDialog
        title: "Add GitHub App"
        type: "info"
        standardButtons: Dialog.NoButton
        width: Math.min(appRoot.width - 40, 760)
        height: Math.min(implicitHeight, appRoot.height - 80)
        readonly property bool hasPreview: releaseCenterService.preview
                                           && releaseCenterService.preview.repository !== undefined
                                           && String(releaseCenterService.preview.repository).length > 0

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 10

            Controls.Label {
                Layout.fillWidth: true
                text: "Paste a GitHub repository or releases page URL."
                color: Colors.textSecondary
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Controls.TextField {
                    id: releaseCenterUrlField
                    Layout.fillWidth: true
                    placeholderText: "https://github.com/owner/repo/releases"
                    onTextChanged: releaseCenterNameField.text = ""
                }

                Controls.Button {
                    text: releaseCenterService.loading ? "Checking..." : "Preview"
                    enabled: !releaseCenterService.loading && releaseCenterUrlField.text.trim().length > 0
                    onClicked: releaseCenterService.previewApp(releaseCenterUrlField.text.trim())
                }
            }

            Controls.Label {
                Layout.fillWidth: true
                visible: releaseCenterService.errorMessage.length > 0
                text: releaseCenterService.errorMessage
                color: Colors.error
                wrapMode: Text.WordWrap
            }

            // Rich preview so the user sees exactly what will be added.
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: previewCol.implicitHeight + 28
                radius: Metrics.innerRadius
                color: Colors.backgroundItemActivated
                border.width: 1
                border.color: Colors.borderActivated
                visible: releaseCenterAddDialog.hasPreview

                ColumnLayout {
                    id: previewCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: 14
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14

                        Item {
                            Layout.preferredWidth: 52
                            Layout.preferredHeight: 52
                            Layout.alignment: Qt.AlignTop
                            Rectangle {
                                id: previewAvatarFrame
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
                                    visible: previewLogo.status !== Image.Ready
                                    text: {
                                        const o = String(releaseCenterService.preview.owner || "?")
                                        return o.length > 0 ? o.charAt(0).toUpperCase() : "?"
                                    }
                                    font.pixelSize: 22
                                    font.bold: true
                                    color: Colors.textSecondary
                                }
                                Image {
                                    id: previewLogo
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    source: releaseCenterService.preview.avatarUrl || ""
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true; mipmap: true; cache: true; asynchronous: true
                                    sourceSize.width: 104; sourceSize.height: 104
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            Text {
                                Layout.fillWidth: true
                                text: String(releaseCenterService.preview.displayName
                                             || releaseCenterService.preview.repo || "")
                                font.family: FontSystem.getContentFontBold.name
                                font.weight: Font.Bold
                                font.pixelSize: Typography.h4
                                color: Colors.textPrimary
                                elide: Text.ElideRight
                            }
                            Controls.Label {
                                Layout.fillWidth: true
                                text: releaseCenterService.preview.repository || ""
                                color: Colors.textSecondary
                                elide: Text.ElideRight
                            }
                            Controls.Label {
                                Layout.fillWidth: true
                                visible: String(releaseCenterService.preview.description || "").length > 0
                                text: releaseCenterService.preview.description || ""
                                color: Colors.textSecondary
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }
                        }
                    }

                    // Stat chips
                    Flow {
                        Layout.fillWidth: true
                        spacing: 8

                        Repeater {
                            model: [
                                { g: "", c: Colors.star, t: appRoot.compactCount(releaseCenterService.preview.stars), show: true },
                                { g: "", c: Colors.secondry, t: appRoot.compactCount(releaseCenterService.preview.forks), show: true },
                                { g: "", c: Colors.textSecondary, t: String(releaseCenterService.preview.language || ""), show: String(releaseCenterService.preview.language || "").length > 0 },
                                { g: "", c: Colors.textSecondary, t: String(releaseCenterService.preview.licenseSpdxId || ""), show: String(releaseCenterService.preview.licenseSpdxId || "").length > 0 }
                            ]
                            delegate: Rectangle {
                                required property var modelData
                                visible: modelData.show
                                width: chipContent.implicitWidth + 20
                                height: 28
                                radius: Metrics.innerRadius
                                color: Colors.pagespaceActivated
                                border.width: 1
                                border.color: Colors.borderActivated
                                Row {
                                    id: chipContent
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Text {
                                        text: modelData.g
                                        font.family: FontSystem.getAwesomeSolid.name
                                        font.weight: Font.Black
                                        font.pixelSize: 12
                                        color: modelData.c
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Controls.Label {
                                        text: modelData.t
                                        color: Colors.textPrimary
                                        font.pixelSize: Typography.t3
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }
                    }

                    // Release summary line
                    Controls.Label {
                        Layout.fillWidth: true
                        text: {
                            const tag = String(releaseCenterService.preview.latestTag || "--")
                            const when = releaseCenterService.preview.latestPublishedAt
                                       ? appRoot.formatReleaseDate(releaseCenterService.preview.latestPublishedAt)
                                       : ""
                            const n = releaseCenterService.previewAssets.length
                            return "Latest " + tag
                                 + (when.length > 0 ? "  •  " + when : "")
                                 + "  •  " + n + " asset" + (n === 1 ? "" : "s")
                        }
                        color: Colors.textSecondary
                        font.pixelSize: Typography.t3
                        elide: Text.ElideRight
                    }
                }
            }

            Controls.TextField {
                id: releaseCenterNameField
                Layout.fillWidth: true
                visible: releaseCenterAddDialog.hasPreview
                placeholderText: releaseCenterService.preview.displayName || "Display name"
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                Item { Layout.fillWidth: true }
                Controls.Button {
                    text: "Cancel"
                    onClicked: releaseCenterAddDialog.close()
                }
                Controls.Button {
                    text: "Add to Release Center"
                    isDefault: true
                    enabled: releaseCenterAddDialog.hasPreview
                    Layout.preferredWidth: 180
                    onClicked: {
                        if (releaseCenterService.confirmPreview(releaseCenterNameField.text)) {
                            appRoot.appendNotification("Release Center",
                                                       "GitHub app added to Release Center.",
                                                       "success")
                            releaseCenterAddDialog.close()
                        }
                    }
                }
            }
        }

        onOpened: {
            releaseCenterService.clearPreview()
            releaseCenterUrlField.text = ""
            releaseCenterNameField.text = ""
            releaseCenterUrlField.forceActiveFocus()
        }
    }

    // Lets the Release Center scheduler honor "only when open": when the window
    // is hidden to tray / minimized, windowActive becomes false.
    Binding {
        target: releaseCenterService
        property: "windowActive"
        value: appRoot.visible && appRoot.visibility !== Window.Minimized
                && appRoot.visibility !== Window.Hidden
    }

    Controls.GitHubReleaseAssetPicker {
        id: githubReleaseAssetPicker
        releaseInfo: appRoot.releaseAssetPickerReleaseInfo
        assets: appRoot.releaseAssetPickerAssets
        sourceAssets: appRoot.releaseAssetPickerSourceAssets
        loading: appRoot.releaseAssetPickerLoading
        errorText: appRoot.releaseAssetPickerError

        onAddSelected: function(selectedAssets) {
            const added = appRoot.submitGitHubReleaseAssets(
                            selectedAssets,
                            appRoot.addDefaultOutputPath,
                            appRoot.addDefaultQueue,
                            appRoot.addDefaultCategory,
                            appRoot.addDefaultStartPaused,
                            appRoot.addDefaultSegments,
                            appRoot.addDefaultAdaptive
                            )
            if (added > 0) {
                appRoot.appendNotification("GitHub release assets added",
                                           added + " asset" + (added === 1 ? "" : "s") + " added to the download queue.",
                                           "success")
                // Record this release as the installed version for the tracked app so
                // the Release Center compares future releases against what we downloaded.
                if (appRoot.releaseAssetPickerAppIndex >= 0)
                    releaseCenterService.markLatestKnown(appRoot.releaseAssetPickerAppIndex)
                // Jump to Home so the user immediately sees the queued downloads.
                appRoot.pageIndex = 0
            }
            appRoot.releaseAssetPickerAppIndex = -1
        }
    }

    Controls.ReleaseDetailsDialog {
        id: releaseDetailsDialog
        dateFormat: appRoot.releaseDateFormat

        onCheckNow: function(rowIndex) {
            if (rowIndex >= 0)
                releaseCenterService.checkApp(rowIndex)
        }
        onOpenUrl: function(url) {
            if (url && url.length > 0)
                appRoot.openExternalLink(url, "Opened link")
        }
        onDownloadAssets: function(app) { appRoot.openAssetPickerForApp(app) }
        onUpdateApp: function(app) { appRoot.startAppUpdate(app) }
    }

    // React to the download policy: "ask" opens the picker, "auto" queues the
    // best platform asset straight away. ("notify" only raises a notification.)
    Connections {
        target: releaseCenterService
        function onAppAutoDownloadRequested(index, assets, autoStart) {
            if (!assets || assets.length === 0) return
            if (autoStart) {
                const added = appRoot.submitGitHubReleaseAssets(
                                assets, appRoot.addDefaultOutputPath, appRoot.addDefaultQueue,
                                appRoot.addDefaultCategory, appRoot.addDefaultStartPaused,
                                appRoot.addDefaultSegments, appRoot.addDefaultAdaptive)
                if (added > 0) {
                    appRoot.appendNotification("Update download started",
                                               assets[0].name + " is downloading.", "success")
                    releaseCenterService.markLatestKnown(index)
                    appRoot.pageIndex = 0
                }
            } else {
                // "Ask before downloading" — surface the picker pre-loaded with the app.
                const apps = releaseCenterService.apps
                if (index >= 0 && index < apps.length)
                    appRoot.openAssetPickerForApp(apps[index])
            }
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
                Controls.TabButton { text: "Release Center" }
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

                                Controls.Label { text: "Close behavior" }
                                Controls.Switch {
                                    checked: uiSettings.keepRunningInBackground
                                    onCheckedChanged: {
                                        uiSettings.keepRunningInBackground = checked
                                        appController.keepRunningInBackground = checked
                                    }
                                }

                                Controls.Label { text: "Runtime footer" }
                                Controls.Switch {
                                    checked: uiSettings.showRuntimeFooter
                                    onCheckedChanged: uiSettings.showRuntimeFooter = checked
                                }

                                Controls.Label {
                                    Layout.columnSpan: 2
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                    text: "System follows the OS appearance. Closing the window can keep downloads active in the tray when background mode is enabled."
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
                                    text: "Restore GENYDL defaults and clear persisted session/configuration state without deleting downloaded files."
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
                                            queueDialogStartTime.text = appRoot.minutesToClockText(downloadManager.queueScheduleStartMinutes(q))
                                            queueDialogEndTime.text = appRoot.minutesToClockText(downloadManager.queueScheduleEndMinutes(q))
                                            queueDialogUseDates.checked = downloadManager.queueScheduleUseDates(q)
                                            queueDialogStartDate.isoValue = downloadManager.queueScheduleStart(q)
                                            queueDialogEndDate.isoValue = downloadManager.queueScheduleEnd(q)
                                            queueDialogQuota.checked = downloadManager.queueQuotaEnabled(q)
                                            queueDialogQuotaBytes.value = Math.round(downloadManager.queueQuotaBytes(q) / (1024 * 1024 * 1024))
                                            queueDialogPostAction.currentIndex = appRoot.queuePostActionIndex(downloadManager.queuePostCompletionAction(q))
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
                                            downloadManager.setQueueScheduleStartMinutes(q, appRoot.clockTextToMinutes(queueDialogStartTime.text, downloadManager.queueScheduleStartMinutes(q)))
                                            downloadManager.setQueueScheduleEndMinutes(q, appRoot.clockTextToMinutes(queueDialogEndTime.text, downloadManager.queueScheduleEndMinutes(q)))
                                            downloadManager.setQueueScheduleUseDates(q, queueDialogUseDates.checked)
                                            downloadManager.setQueueScheduleStart(q, queueDialogStartDate.isoValue)
                                            downloadManager.setQueueScheduleEnd(q, queueDialogEndDate.isoValue)
                                            downloadManager.setQueueQuotaEnabled(q, queueDialogQuota.checked)
                                            downloadManager.setQueueQuotaBytes(q, queueDialogQuotaBytes.value * 1024 * 1024 * 1024)
                                            downloadManager.setQueuePostCompletionAction(q, appRoot.queuePostActionIds[Math.max(0, queueDialogPostAction.currentIndex)])
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
                                    Controls.Label { text: "Run on schedule" }
                                    Controls.Switch { id: queueDialogSchedule }

                                    RowLayout {
                                        spacing: 6
                                        Text {
                                            text: String.fromCharCode(0xf133)   // calendar
                                            font.family: FontSystem.getAwesomeSolid.name
                                            font.weight: Font.Black
                                            font.pixelSize: 13
                                            color: Colors.textSecondary
                                        }
                                        Controls.Label { text: "Use calendar dates" }
                                    }
                                    Controls.Switch {
                                        id: queueDialogUseDates
                                        // Calendar (absolute) window vs. daily clock window.
                                    }

                                    // Mode hint spanning both columns.
                                    Controls.Label {
                                        Layout.columnSpan: 2
                                        Layout.fillWidth: true
                                        text: queueDialogUseDates.checked
                                              ? "On: runs once, only inside the exact calendar window you pick below."
                                              : "Off: repeats every day between the two clock times below. Turn on to pick exact calendar dates."
                                        color: Colors.textMuted
                                        font.pixelSize: Typography.t3
                                        wrapMode: Text.WordWrap
                                    }

                                    // Daily clock window (shown when NOT using a date range).
                                    Controls.Label {
                                        text: "Start time"
                                        visible: !queueDialogUseDates.checked
                                    }
                                    Controls.TextField {
                                        id: queueDialogStartTime
                                        visible: !queueDialogUseDates.checked
                                        placeholderText: "02:00 AM"
                                        text: "00:00"
                                    }
                                    Controls.Label {
                                        text: "End time"
                                        visible: !queueDialogUseDates.checked
                                    }
                                    Controls.TextField {
                                        id: queueDialogEndTime
                                        visible: !queueDialogUseDates.checked
                                        placeholderText: "07:00 AM"
                                        text: "00:00"
                                    }

                                    // Absolute datetime window with calendar pickers.
                                    Controls.Label {
                                        text: "Start date"
                                        visible: queueDialogUseDates.checked
                                    }
                                    Controls.DateTimeField {
                                        id: queueDialogStartDate
                                        Layout.fillWidth: true
                                        visible: queueDialogUseDates.checked
                                        placeholder: "Pick a start date/time"
                                    }
                                    Controls.Label {
                                        text: "End date"
                                        visible: queueDialogUseDates.checked
                                    }
                                    Controls.DateTimeField {
                                        id: queueDialogEndDate
                                        Layout.fillWidth: true
                                        visible: queueDialogUseDates.checked
                                        placeholder: "Pick an end date/time"
                                    }

                                    Controls.Label { text: "Enable quota" }
                                    Controls.Switch { id: queueDialogQuota }
                                    Controls.Label { text: "Quota (GB/day)" }
                                    Controls.SpinBox { id: queueDialogQuotaBytes; from: 0; to: 100000; value: 0 }
                                    Controls.Label { text: "After queue finishes" }
                                    Controls.ComboBox {
                                        id: queueDialogPostAction
                                        Layout.preferredWidth: 220
                                        model: appRoot.queuePostActionOptions
                                    }
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

                        Controls.GroupBox {
                            title: "BitTorrent"
                            Layout.fillWidth: true
                            implicitHeight: torrentSettingsLayout.implicitHeight + topPadding + bottomPadding

                            ColumnLayout {
                                id: torrentSettingsLayout
                                width: parent.width
                                spacing: 8

                                Controls.Label {
                                    Layout.fillWidth: true
                                    text: downloadManager.torrentAvailable
                                          ? "Seeding stops when either limit is reached. 0 = unlimited."
                                          : "BitTorrent support is not available in this build."
                                    color: Colors.textMuted
                                    wrapMode: Text.WordWrap
                                }

                                GridLayout {
                                    Layout.fillWidth: true
                                    columns: 2
                                    columnSpacing: 12
                                    rowSpacing: 8
                                    enabled: downloadManager.torrentAvailable

                                    Controls.Label { text: "Seed ratio limit" }
                                    Controls.SpinBox {
                                        Layout.preferredWidth: 180
                                        from: 0
                                        to: 1000
                                        stepSize: 1
                                        // SpinBox is integer; store ratio * 10 (e.g. 15 = 2.0... no, 20 = 2.0)
                                        property int scale: 10
                                        value: Math.round(downloadManager.torrentSeedRatio * scale)
                                        onValueModified: downloadManager.torrentSeedRatio = value / scale
                                        textFromValue: function(v) { return (v / scale).toFixed(1) }
                                        valueFromText: function(t) { return Math.round(parseFloat(t) * scale) }
                                    }

                                    Controls.Label { text: "Seed time limit (min)" }
                                    Controls.SpinBox {
                                        Layout.preferredWidth: 180
                                        from: 0
                                        to: 100000
                                        value: downloadManager.torrentSeedTimeMinutes
                                        onValueModified: downloadManager.torrentSeedTimeMinutes = value
                                    }
                                }
                            }
                        }

                        // Smart Gateway System — the key advantage over a browser's
                        // single hard-coded gateway. Users see live health and can
                        // prioritize, disable, reorder, or add their own gateways.
                        Controls.GroupBox {
                            id: gatewaysGroup
                            title: "IPFS Gateways (Smart Gateway System)"
                            Layout.fillWidth: true
                            implicitHeight: gatewaysLayout.implicitHeight + topPadding + bottomPadding

                            // Map a status kind token to a theme color.
                            function statusColor(kind) {
                                switch (kind) {
                                    case "success": return Colors.success
                                    case "warning": return Colors.warning
                                    case "danger":  return Colors.error
                                    default:        return Colors.textMuted
                                }
                            }

                            ColumnLayout {
                                id: gatewaysLayout
                                width: parent.width
                                spacing: 8

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Controls.Label {
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                        color: Colors.textMuted
                                        text: "Content is resolved through these gateways, ordered by preference, live health, and response time, with automatic fallback. "
                                              + gatewayService.healthyCount + " of " + gatewayService.enabledCount + " enabled gateway(s) healthy"
                                              + (gatewayService.localNodeAvailable ? "  ·  Local node detected" : "")
                                    }

                                    Controls.Button {
                                        text: gatewayService.checking ? "Checking…" : "Check now"
                                        enabled: !gatewayService.checking
                                        onClicked: gatewayService.checkHealthNow()
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 1
                                    color: Colors.borderActivated
                                }

                                Repeater {
                                    model: gatewayService.gateways

                                    delegate: RowLayout {
                                        required property var modelData
                                        required property int index
                                        Layout.fillWidth: true
                                        Layout.topMargin: 3
                                        Layout.bottomMargin: 3
                                        spacing: 10

                                        Rectangle {
                                            width: 9; height: 9; radius: 4.5
                                            Layout.alignment: Qt.AlignVCenter
                                            color: gatewaysGroup.statusColor(modelData.statusKind)
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 1

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 6

                                                Controls.Label {
                                                    elide: Text.ElideRight
                                                    font.bold: true
                                                    text: modelData.host
                                                }
                                                Rectangle {
                                                    visible: modelData.local || !modelData.builtin
                                                    radius: height / 2
                                                    color: Colors.backgroundItemActivated
                                                    implicitHeight: tagText.implicitHeight + 3
                                                    implicitWidth: tagText.implicitWidth + 12
                                                    Layout.alignment: Qt.AlignVCenter
                                                    Text {
                                                        id: tagText
                                                        anchors.centerIn: parent
                                                        text: modelData.local ? "local node" : "custom"
                                                        color: Colors.textMuted
                                                        font.pixelSize: 10
                                                    }
                                                }
                                                Item { Layout.fillWidth: true }
                                            }

                                            Controls.Label {
                                                color: gatewaysGroup.statusColor(modelData.statusKind)
                                                text: modelData.status
                                                      + (modelData.responseMs >= 0 ? "   ·   " + modelData.responseMs + " ms" : "")
                                            }
                                        }

                                        // Compact action cluster
                                        RowLayout {
                                            spacing: 2
                                            Layout.alignment: Qt.AlignVCenter

                                            Controls.MiniIconButton {
                                                glyph: "★"
                                                active: modelData.preferred
                                                glyphColor: Colors.textMuted
                                                activeColor: Colors.star
                                                onActivated: gatewayService.setGatewayPreferred(index, !modelData.preferred)
                                            }
                                            Controls.MiniIconButton {
                                                glyph: "↑"
                                                interactive: index > 0
                                                onActivated: gatewayService.moveGatewayUp(index)
                                            }
                                            Controls.MiniIconButton {
                                                glyph: "↓"
                                                interactive: index < gatewayService.gateways.length - 1
                                                onActivated: gatewayService.moveGatewayDown(index)
                                            }
                                            Controls.MiniIconButton {
                                                glyph: "✕"
                                                glyphColor: Colors.textError
                                                visible: !modelData.builtin
                                                onActivated: gatewayService.removeGateway(index)
                                            }
                                        }

                                        Controls.Switch {
                                            Layout.alignment: Qt.AlignVCenter
                                            checked: modelData.enabled
                                            onCheckedChanged: {
                                                if (checked !== modelData.enabled)
                                                    gatewayService.setGatewayEnabled(index, checked)
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 1
                                    color: Colors.borderActivated
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Controls.TextField {
                                        id: customGatewayField
                                        Layout.fillWidth: true
                                        placeholderText: "https://my-gateway.example"
                                        onAccepted: addGatewayButton.clicked()
                                    }
                                    Controls.Button {
                                        id: addGatewayButton
                                        text: "Add gateway"
                                        onClicked: {
                                            var v = customGatewayField.text.trim()
                                            if (v.length > 0) {
                                                gatewayService.addCustomGateway(v)
                                                customGatewayField.text = ""
                                            }
                                        }
                                    }
                                    Controls.Button {
                                        text: "Reset"
                                        style: "danger"
                                        onClicked: gatewayService.resetToDefaults()
                                    }
                                }
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

                ScrollView {
                    id: releaseCenterConfigView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    ColumnLayout {
                        width: Math.max(320, releaseCenterConfigView.availableWidth)
                        spacing: 12

                        Controls.ReleaseCenterSettings { Layout.fillWidth: true }

                        Item { Layout.fillHeight: true }
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
    Shortcut { sequence: "Ctrl+Q"; context: Qt.ApplicationShortcut; onActivated: appController.quitApplication() }
    Shortcut { sequence: "Ctrl+Shift+P"; context: Qt.ApplicationShortcut; onActivated: downloadManager.pauseAll() }
    Shortcut { sequence: "Ctrl+Shift+R"; context: Qt.ApplicationShortcut; onActivated: downloadManager.resumeAll() }
    Shortcut { sequence: "Ctrl+Shift+T"; context: Qt.ApplicationShortcut; onActivated: downloadManager.retryFailed() }
    Shortcut { sequence: "Ctrl+Shift+X"; context: Qt.ApplicationShortcut; onActivated: downloadManager.cancelAll() }
    Shortcut { sequence: "Ctrl+Shift+U"; context: Qt.ApplicationShortcut; onActivated: appRoot.pageIndex = 1 }

    Component.onCompleted: {

        AppGlobals.appPalette = palette
        AppGlobals.appWindow = appRoot
        AppGlobals.rtl = appRootObjects.isLeftToRight ? false : true
        appController.setMainWindow(appRoot)
        appController.keepRunningInBackground = uiSettings.keepRunningInBackground

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
        target: githubReleaseService
        ignoreUnknownSignals: true

        function onLoadingChanged() {
            appRoot.releaseAssetPickerLoading = githubReleaseService.loading
        }
        function onReleaseChanged() {
            appRoot.releaseAssetPickerReleaseInfo = githubReleaseService.release
        }
        function onAssetsChanged() {
            appRoot.releaseAssetPickerAssets = githubReleaseService.assets
            appRoot.releaseAssetPickerSourceAssets = []
        }
        function onErrorMessageChanged() {
            appRoot.releaseAssetPickerError = githubReleaseService.errorMessage
        }
    }

    Connections {
        target: releaseCenterService
        ignoreUnknownSignals: true

        function onAppUpdateFound(displayName, tagName, index) {
            appRoot.pageIndex = 1
            appRoot.lastUpdateAppIndex = index
            const message = displayName + " " + tagName + " is available. "
                          + "Click to view details."
            appRoot.appendNotification("New update available", message, "info")
            appController.showNotification("New update available", message)
            notificationDrawer.open()
        }
    }

    Connections {
        target: appController
        ignoreUnknownSignals: true

        // Clicking the OS notification acts as "View details" for the app whose
        // update was just announced. (QSystemTrayIcon can't render real action
        // buttons cross-platform, so the whole notification is the action.)
        function onNotificationClicked() {
            appRoot.pageIndex = 1
            const apps = releaseCenterService.apps
            const i = appRoot.lastUpdateAppIndex
            if (i >= 0 && i < apps.length) {
                releaseDetailsDialog.app = apps[i]
                releaseDetailsDialog.open()
            }
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

    Controls.TorrentDetailsDialog {
        id: torrentDetailsWindow

        onPauseResumeRequested: function(row) {
            downloadManager.togglePause(row)
        }
        onRemoveRequested: function(row) {
            appRoot.promptRemoveRows([row])
            torrentDetailsWindow.close()
        }
        onOpenRequested: function(row) {
            downloadManager.openFile(row)
        }
        onRevealRequested: function(row) {
            downloadManager.revealInFolder(row)
        }
        onCopyRequested: function(text) {
            downloadManager.copyText(text)
        }
    }

    Window {
        id: detailsWindow

        width: 860
        height: 640
        minimumWidth: 860
        minimumHeight: 640
        maximumWidth: 860
        maximumHeight: 640

        flags: Qt.Widget

        title: appRoot.detailsTask ? Math.round(appRoot.detailsProgress * 100) + "% " + appRoot.baseName(appRoot.taskFileNameValue(appRoot.detailsTask)) : "Download Details"
        visible: false

        property int tabIndex: 0

        // Resolve a semantic tone token (from utils.js classifiers) to a color.
        function toneColor(tone) {
            switch (tone) {
                case "success":   return Colors.textSuccess
                case "warning":   return Colors.textWarning
                case "danger":    return Colors.textError
                case "accent":    return Colors.textAccent
                case "info":      return Colors.textAccent
                case "secondary": return Colors.textSecondary
                default:          return Colors.textMuted
            }
        }

        readonly property var detailsSrcInfo: Utils.sourceTypeInfo(appRoot.detailsTask)
        readonly property var detailsVerInfo: Utils.verificationInfo(appRoot.detailsTask)
        // Blockchain/decentralized rows (IPFS, Arweave, …) get the dedicated
        // Source Information panel; plain HTTP/torrent rows keep the original
        // layout so nothing overflows the fixed-size window.
        readonly property bool detailsIsBlockchain: detailsSrcInfo.id === "ipfs"
                                                     || detailsSrcInfo.id === "arweave"
                                                     || detailsSrcInfo.id === "storage"

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
                    ScrollView {
                        id: detailsGeneralView
                        anchors.fill: parent
                        clip: true

                    ColumnLayout {
                        width: Math.max(320, detailsGeneralView.availableWidth)
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

                        // Source Information — protocol, content address, gateway,
                        // and verification transparency. Mirrors a torrent client's
                        // tracker panel so users always know where a file came from,
                        // how it was delivered, and whether it was verified.
                        GroupBox {
                            title: "Source Information"
                            visible: detailsWindow.detailsIsBlockchain
                            Layout.fillWidth: true
                            Layout.preferredHeight: sourceGrid.implicitHeight + 64

                            GridLayout {
                                id: sourceGrid
                                anchors.fill: parent
                                anchors.margins: 10
                                columns: 2
                                columnSpacing: 16
                                rowSpacing: 6

                                readonly property bool isIpfs: detailsWindow.detailsSrcInfo.id === "ipfs"
                                readonly property bool hasCid: appRoot.detailsTask
                                                               && appRoot.detailsTask.contentId
                                                               && String(appRoot.detailsTask.contentId).length > 0

                                Controls.Label { text: "Source Type" }
                                Controls.Label {
                                    text: detailsWindow.detailsSrcInfo.label
                                    color: detailsWindow.toneColor(detailsWindow.detailsSrcInfo.tone)
                                    font.bold: true
                                    Layout.fillWidth: true
                                }

                                Controls.Label { text: "Content ID (CID)"; visible: sourceGrid.hasCid }
                                Controls.Label {
                                    text: sourceGrid.hasCid ? String(appRoot.detailsTask.contentId) : ""
                                    font.family: FontSystem.getContentFontMedium.name
                                    elide: Text.ElideMiddle
                                    visible: sourceGrid.hasCid
                                    Layout.fillWidth: true
                                }

                                Controls.Label { text: "Gateway"; visible: sourceGrid.isIpfs }
                                Controls.Label {
                                    text: {
                                        if (!sourceGrid.isIpfs) return ""
                                        var gw = Utils.activeGatewayHost(appRoot.detailsTask)
                                        return gw.length > 0 ? gw : "Resolving…"
                                    }
                                    visible: sourceGrid.isIpfs
                                    Layout.fillWidth: true
                                }

                                Controls.Label { text: "Fallbacks"; visible: sourceGrid.isIpfs }
                                Controls.Label {
                                    text: sourceGrid.isIpfs
                                          ? Utils.gatewayFallbackCount(appRoot.detailsTask) + " gateway(s) available"
                                          : ""
                                    visible: sourceGrid.isIpfs
                                }

                                Controls.Label { text: "Verification"; visible: detailsWindow.detailsVerInfo.state !== "none" }
                                Controls.Label {
                                    text: (detailsWindow.detailsVerInfo.verified ? "✓ " : "")
                                          + detailsWindow.detailsVerInfo.label
                                    color: detailsWindow.toneColor(detailsWindow.detailsVerInfo.tone)
                                    font.bold: true
                                    visible: detailsWindow.detailsVerInfo.state !== "none"
                                }

                                Controls.Label { text: "Integrity"; visible: detailsWindow.detailsVerInfo.state !== "none" }
                                Controls.Label {
                                    text: {
                                        switch (detailsWindow.detailsVerInfo.state) {
                                            case "verified":  return "✓ Verified Content"
                                            case "mismatch":  return "✗ Integrity check failed"
                                            case "verifying": return "Checking…"
                                            case "trusted":   return "Gateway-trusted (not byte-verifiable)"
                                            default:          return "—"
                                        }
                                    }
                                    color: detailsWindow.toneColor(detailsWindow.detailsVerInfo.tone)
                                    visible: detailsWindow.detailsVerInfo.state !== "none"
                                }

                                Controls.Label { text: "Downloaded Via" }
                                Controls.Label { text: Utils.deliveryChannel(appRoot.detailsTask) }
                            }
                        }

                        GroupBox {
                            title: "Segmented Progress Map"
                            // Hidden for blockchain rows: content-addressed fetches
                            // are typically small single objects, and the Source
                            // Information panel takes this slot instead — keeping the
                            // fixed-size window from overflowing.
                            visible: !detailsWindow.detailsIsBlockchain
                            Layout.fillWidth: true
                            Layout.preferredHeight: 220
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
                        text: "Remove the selected download from GENYDL?"
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
                text: "A newer version of GENYDL is available."
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
                text: "Restore GENYDL to its default configuration?"
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
                      ? "Remove " + appRoot.pendingRemoveRows.length + " selected downloads from GENYDL?"
                      : "Remove the selected download from GENYDL?"
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
        height: 72
        anchors.left: parent.left
        anchors.right: parent.right

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 22
            anchors.rightMargin: 18
            anchors.topMargin: 8
            anchors.bottomMargin: 8
            spacing: 8

            Rectangle {
                Layout.preferredWidth: 142
                Layout.preferredHeight: 42
                Layout.alignment: Qt.AlignVCenter
                radius: Metrics.innerRadius
                color: Colors.lightShadow
                clip: true

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 9

                    Item { Layout.preferredWidth: 2; }

                    // Wordmark / logotype.
                    Controls.Text {
                        font.family: FontSystem.getContentFontBold.name
                        font.pixelSize: Typography.h3
                        font.letterSpacing: 0.6
                        color: Colors.textPrimary
                        text: "GENY<strong>DL</strong>"
                    }

                    Item { Layout.preferredWidth: 2; }
                }

            }

            Item {

                Layout.preferredWidth: 18

            }

            RowLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 8

                function navSeparator() { return "|" }

                Controls.AppMenuTrigger {
                    text: "Home"
                    selected: appRoot.pageIndex === 0
                    onTriggered: appRoot.pageIndex = 0
                }
                Text { text: "|"; color: Colors.lineBorderActivated; font.pixelSize: Typography.t2 }
                Controls.AppMenuTrigger { text: "Actions"; menu: tasksTopMenu }
                Text { text: "|"; color: Colors.lineBorderActivated; font.pixelSize: Typography.t2 }
                Controls.AppMenuTrigger { text: "File"; menu: fileTopMenu }
                Text { text: "|"; color: Colors.lineBorderActivated; font.pixelSize: Typography.t2 }
                Controls.AppMenuTrigger { text: "Downloads"; menu: downloadsTopMenu }
                Text { text: "|"; color: Colors.lineBorderActivated; font.pixelSize: Typography.t2 }
                Controls.AppMenuTrigger {
                    text: "Release Center"
                    menu: releaseCenterTopMenu
                    selected: appRoot.pageIndex === 1
                }
                Text { text: "|"; color: Colors.lineBorderActivated; font.pixelSize: Typography.t2 }
                Controls.AppMenuTrigger { text: "Configuration"; menu: configurationTopMenu }
                Text { text: "|"; color: Colors.lineBorderActivated; font.pixelSize: Typography.t2 }
                Controls.AppMenuTrigger { text: "Help"; menu: helpTopMenu }

            }

            Item { Layout.fillWidth: true }

            Rectangle {
                // fillWidth + cap lets the promo card shrink on narrow windows
                // instead of overflowing past the right edge and clipping its
                // rounded corner. minimumWidth 0 + content elision handle the rest.
                Layout.fillWidth: true
                Layout.preferredWidth: 512
                Layout.maximumWidth: 512
                Layout.minimumWidth: 0
                Layout.preferredHeight: 58
                Layout.maximumHeight: 58
                Layout.alignment: Qt.AlignVCenter
                radius: Metrics.innerRadius
                color: Colors.backgroundActivated
                border.width: 1
                border.color: genyAdHover.hovered ? Colors.secondry : Colors.borderActivated
                clip: true

                Behavior on border.color { ColorAnimation { duration: Animations.normal; easing.type: Easing.OutCubic } }

                // Opaque, theme-synced sheen so the promo reads as one solid card.
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Colors.backgroundActivated }
                    GradientStop { position: 0.55; color: Colors.backgroundActivated }
                    GradientStop { position: 1.0; color: Colors.backgroundItemActivated }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 12

                    Rectangle {
                        id: genyLogoFrame
                        Layout.preferredWidth: 42
                        Layout.preferredHeight: 42
                        Layout.alignment: Qt.AlignVCenter
                        radius: 14
                        color: "#001309"
                        border.width: 1
                        border.color: Colors.borderActivated
                        clip: true

                        // Fallback brand mark shown until the logo image is ready.
                        Text {
                            anchors.centerIn: parent
                            visible: genyLogo.status !== Image.Ready
                            text: "$" + appRoot.genyTokenSymbol
                            color: Colors.textPrimary
                            font.family: FontSystem.getTitleBoldFont.font.family
                            font.pixelSize: Typography.t5
                            font.bold: true
                        }

                        Image {
                            id: genyLogo
                            anchors.fill: parent
                            anchors.margins: 6
                            source: appRoot.genyTokenImageUrl
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            mipmap: true
                            cache: true
                            asynchronous: true
                            // Render the SVG at 2x for a crisp mark.
                            sourceSize.width: 72
                            sourceSize.height: 72
                            visible: status === Image.Ready
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 0

                        Text {
                            Layout.fillWidth: true
                            text: "GenyToken"
                            color: Colors.textPrimary
                            font.family: FontSystem.getTitleBoldFont.font.family
                            font.pixelSize: Typography.t3
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "256M fixed-supply ERC20 powering the Genyleap ecosystem."
                            color: Colors.textSecondary
                            font.family: FontSystem.getContentFontRegular.name
                            font.pixelSize: Typography.t5
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
                            font.pixelSize: Typography.t5
                            elide: Text.ElideRight
                            wrapMode: Text.NoWrap
                        }
                    }
                }

                HoverHandler { id: genyAdHover }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: appRoot.openExternalLink(appRoot.genyleapWebsiteUrl, "Opened Genyleap website")
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
            Controls.AppMenuItem { text: "Exit"; iconGlyph: "\uf08b"; onTriggered: appController.quitApplication() }
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
            id: releaseCenterTopMenu
            title: "Release Center"
            Controls.AppMenuItem {
                text: "Open Release Center"
                iconGlyph: "\uf135"
                onTriggered: appRoot.pageIndex = 1
            }
            Controls.AppMenuItem {
                text: "Add GitHub App"
                iconGlyph: "\uf0fe"
                onTriggered: {
                    appRoot.pageIndex = 1
                    releaseCenterAddDialog.open()
                }
            }
            Controls.AppMenuItem {
                text: "Check All"
                iconGlyph: "\uf021"
                onTriggered: {
                    appRoot.pageIndex = 1
                    releaseCenterService.checkAll()
                }
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
                    // Inset the scrolling content vertically by the corner radius so
                    // the ScrollView's rectangular clip stays inside the straight part
                    // of the rounded background. Without this, scrolled rows bleed into
                    // the top/bottom corners and visually square them off.
                    topPadding: Metrics.outerRadius
                    bottomPadding: Metrics.outerRadius
                    background: Rectangle {
                        color: Colors.backgroundActivated
                        radius: Metrics.outerRadius
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: Metrics.margins

                        // Hosts the scroll area plus top/bottom fade overlays so rows
                        // feather out at the edges instead of being hard-clipped where
                        // the list meets the drop zone.
                        Item {
                            id: sidebarScrollArea
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                        ScrollView {
                            id: sidebarScroll
                            anchors.fill: parent
                            contentWidth: availableWidth
                            contentHeight: sidebarContent.implicitHeight
                            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                            ColumnLayout {
                                id: sidebarContent
                                width: sidebarScroll.availableWidth

                                Controls.GroupBox {
                                    id: navigationTree
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: navigationTreeContent.implicitHeight + topPadding + bottomPadding
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
                                                    text: "Videos"
                                                    iconGlyph: "\uf03d"
                                                    selected: appRoot.categoryFilter === "Video" && appRoot.statusFilter === "All"
                                                    onClicked: appRoot.setCategoryScope("Video")
                                                }
                                                Controls.SidebarTreeItem {
                                                    Layout.fillWidth: true
                                                    child: true
                                                    text: "Music"
                                                    iconGlyph: "\uf001"
                                                    selected: appRoot.categoryFilter === "Audio" && appRoot.statusFilter === "All"
                                                    onClicked: appRoot.setCategoryScope("Audio")
                                                }
                                                Controls.SidebarTreeItem {
                                                    Layout.fillWidth: true
                                                    child: true
                                                    text: "Images"
                                                    iconGlyph: "\uf03e"
                                                    selected: appRoot.categoryFilter === "Images" && appRoot.statusFilter === "All"
                                                    onClicked: appRoot.setCategoryScope("Images")
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
                                                    text: "Archives"
                                                    iconGlyph: "\uf1c6"
                                                    selected: appRoot.categoryFilter === "Archives" && appRoot.statusFilter === "All"
                                                    onClicked: appRoot.setCategoryScope("Archives")
                                                }
                                                Controls.SidebarTreeItem {
                                                    Layout.fillWidth: true
                                                    child: true
                                                    text: "Windows"
                                                    iconGlyph: "\uf17a"
                                                    iconBrand: true
                                                    selected: appRoot.categoryFilter === "Windows" && appRoot.statusFilter === "All"
                                                    onClicked: appRoot.setCategoryScope("Windows")
                                                }
                                                Controls.SidebarTreeItem {
                                                    Layout.fillWidth: true
                                                    child: true
                                                    text: "macOS"
                                                    iconGlyph: "\uf179"
                                                    iconBrand: true
                                                    selected: appRoot.categoryFilter === "macOS" && appRoot.statusFilter === "All"
                                                    onClicked: appRoot.setCategoryScope("macOS")
                                                }
                                                Controls.SidebarTreeItem {
                                                    Layout.fillWidth: true
                                                    child: true
                                                    text: "Linux"
                                                    iconGlyph: "\uf17c"
                                                    iconBrand: true
                                                    selected: appRoot.categoryFilter === "Linux" && appRoot.statusFilter === "All"
                                                    onClicked: appRoot.setCategoryScope("Linux")
                                                }
                                                Controls.SidebarTreeItem {
                                                    Layout.fillWidth: true
                                                    child: true
                                                    text: "Android"
                                                    iconGlyph: "\uf17b"
                                                    iconBrand: true
                                                    selected: appRoot.categoryFilter === "Android" && appRoot.statusFilter === "All"
                                                    onClicked: appRoot.setCategoryScope("Android")
                                                }
                                                Controls.SidebarTreeItem {
                                                    Layout.fillWidth: true
                                                    child: true
                                                    text: "Disk Images"
                                                    iconGlyph: "\uf51f"
                                                    selected: appRoot.categoryFilter === "Disk Images" && appRoot.statusFilter === "All"
                                                    onClicked: appRoot.setCategoryScope("Disk Images")
                                                }
                                                Controls.SidebarTreeItem {
                                                    Layout.fillWidth: true
                                                    child: true
                                                    text: "Games"
                                                    iconGlyph: "\uf11b"
                                                    selected: appRoot.categoryFilter === "Games" && appRoot.statusFilter === "All"
                                                    onClicked: appRoot.setCategoryScope("Games")
                                                }
                                                Controls.SidebarTreeItem {
                                                    Layout.fillWidth: true
                                                    child: true
                                                    text: "Torrents"
                                                    iconGlyph: "\uf076"
                                                    selected: appRoot.categoryFilter === "Torrents" && appRoot.statusFilter === "All"
                                                    onClicked: appRoot.setCategoryScope("Torrents")
                                                }
                                                Controls.SidebarTreeItem {
                                                    Layout.fillWidth: true
                                                    child: true
                                                    text: "NFTs"
                                                    iconGlyph: "\uf3a5"
                                                    selected: appRoot.categoryFilter === "NFT" && appRoot.statusFilter === "All"
                                                    onClicked: appRoot.setCategoryScope("NFT")
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

                                        // ---- Group by source / protocol ----
                                        Controls.SidebarTreeItem {
                                            Layout.fillWidth: true
                                            text: "By Source"
                                            iconGlyph: "\uf0e8"
                                            selected: appRoot.sourceFilter !== "All"
                                            expandable: true
                                            expanded: appRoot.sidebarSourceExpanded
                                            onClicked: appRoot.sidebarSourceExpanded = !appRoot.sidebarSourceExpanded
                                        }

                                        Item {
                                            Layout.fillWidth: true
                                            implicitHeight: sourceChildren.implicitHeight
                                            height: appRoot.sidebarSourceExpanded ? implicitHeight : 0
                                            opacity: appRoot.sidebarSourceExpanded ? 1 : 0
                                            visible: height > 0 || opacity > 0

                                            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                            Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                                            ColumnLayout {
                                                id: sourceChildren
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.top: parent.top
                                                spacing: 4

                                                Controls.SidebarTreeItem {
                                                    Layout.fillWidth: true
                                                    child: true
                                                    text: "Direct Downloads"
                                                    iconGlyph: "\uf0ac"
                                                    selected: appRoot.sourceFilter === "Direct"
                                                    onClicked: appRoot.setSourceScope("Direct")
                                                }
                                                Controls.SidebarTreeItem {
                                                    Layout.fillWidth: true
                                                    child: true
                                                    text: "Torrents"
                                                    iconGlyph: "\uf0e8"
                                                    selected: appRoot.sourceFilter === "Torrent"
                                                    onClicked: appRoot.setSourceScope("Torrent")
                                                }
                                                Controls.SidebarTreeItem {
                                                    Layout.fillWidth: true
                                                    child: true
                                                    text: "Blockchain Storage"
                                                    iconGlyph: "\uf0c2"
                                                    selected: appRoot.sourceFilter === "Blockchain"
                                                    onClicked: appRoot.setSourceScope("Blockchain")
                                                }
                                                Controls.SidebarTreeItem {
                                                    Layout.fillWidth: true
                                                    child: true
                                                    text: "IPFS"
                                                    iconGlyph: "\uf1c0"
                                                    selected: appRoot.sourceFilter === "IPFS"
                                                    onClicked: appRoot.setSourceScope("IPFS")
                                                }
                                                Controls.SidebarTreeItem {
                                                    Layout.fillWidth: true
                                                    child: true
                                                    text: "Arweave"
                                                    iconGlyph: "\uf187"
                                                    selected: appRoot.sourceFilter === "Arweave"
                                                    onClicked: appRoot.setSourceScope("Arweave")
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
                                            text: "Queues"
                                            iconGlyph: "\uf0ca"
                                            selected: appRoot.queueFilter !== "All Queues"
                                            expandable: true
                                            expanded: appRoot.sidebarQueuesExpanded
                                            onClicked: appRoot.sidebarQueuesExpanded = !appRoot.sidebarQueuesExpanded
                                        }

                                        Item {
                                            Layout.fillWidth: true
                                            implicitHeight: sidebarQueueChildren.implicitHeight
                                            height: appRoot.sidebarQueuesExpanded ? implicitHeight : 0
                                            opacity: appRoot.sidebarQueuesExpanded ? 1 : 0
                                            visible: height > 0 || opacity > 0
                                            clip: true

                                            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                            Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                                            ColumnLayout {
                                                id: sidebarQueueChildren
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.top: parent.top
                                                spacing: 4

                                                Controls.SidebarTreeItem {
                                                    Layout.fillWidth: true
                                                    child: true
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
                                                        child: true
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

                                Controls.GroupBox {
                                    id: queueTree
                                    visible: false
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 0
                                    Layout.maximumHeight: 0
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
                        } // ScrollView

                            // Edge fades: short gradients matching the panel background.
                            // Disabled for input so scroll/clicks pass through, and each
                            // only appears when there is clipped content in its direction.
                            // Fading to the bg colour at zero alpha (not "transparent",
                            // which is transparent black) avoids a dark fringe.
                            Rectangle {
                                id: topFade
                                anchors { left: parent.left; right: parent.right; top: parent.top }
                                height: Metrics.outerRadius
                                enabled: false
                                readonly property color bg: Colors.backgroundActivated
                                readonly property Flickable flick: sidebarScroll.contentItem
                                opacity: flick ? Math.min(1, flick.contentY / 18) : 0
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: topFade.bg }
                                    GradientStop { position: 1.0; color: Qt.rgba(topFade.bg.r, topFade.bg.g, topFade.bg.b, 0) }
                                }
                            }
                            Rectangle {
                                id: bottomFade
                                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                                height: Metrics.outerRadius
                                enabled: false
                                readonly property color bg: Colors.backgroundActivated
                                readonly property Flickable flick: sidebarScroll.contentItem
                                opacity: flick ? Math.min(1, Math.max(0, (flick.contentHeight - flick.height - flick.contentY) / 18)) : 0
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: Qt.rgba(bottomFade.bg.r, bottomFade.bg.g, bottomFade.bg.b, 0) }
                                    GradientStop { position: 1.0; color: bottomFade.bg }
                                }
                            }
                        } // sidebarScrollArea

                        Controls.GroupBox {
                            id: runtimeCard
                            visible: false
                            Layout.fillWidth: true
                            Layout.fillHeight: false
                            hasBorder: true
                            Layout.preferredHeight: 0
                            Layout.maximumHeight: 0
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

                        // Persistent drag-and-drop target pinned to the bottom of
                        // the sidebar. Accepts dropped links/files and also opens
                        // the Add URL dialog (prefilled) when clicked.
                        Controls.DropZone {
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            compact: true
                            onClicked: appRoot.openAddUrlDialog()
                            onDropped: (text) => appRoot.openAddUrlWith(text)
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
                                        readonly property bool accepted: appRoot.rowAccepted(queueName, status, category, fileName, urlText, task)
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
                                                        font.weight: Font.Black
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
                                                            font.weight: Font.Black
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
                                                        font.weight: Font.Black
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
                                                        font.weight: Font.Black
                                                        font.pixelSize: Typography.t5
                                                        color: Colors.textSecondary
                                                    }

                                                    Controls.Text {
                                                        text: {
                                                            if (!task) return "0/0"
                                                            if (task.isTorrent) return task.seeders + "/" + task.leechers
                                                            return task.effectiveSegments() + "/" + task.segments()
                                                        }
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

                                // Empty-state: fill the list area with a friendly
                                // drag-and-drop target when there are no downloads.
                                Controls.DropZone {
                                    anchors.fill: parent
                                    anchors.margins: Metrics.padding
                                    visible: downloadList.count === 0
                                    title: "No downloads yet"
                                    subtitle: "Drag a link, magnet, or .torrent here — or click to add manually"
                                    activeTitle: "Drop to add a download"
                                    onClicked: appRoot.openAddUrlDialog()
                                    onDropped: (text) => appRoot.openAddUrlWith(text)
                                }
                            }
                        }

                        Rectangle {
                            id: runtimeFooter
                            visible: uiSettings.showRuntimeFooter
                            Layout.fillWidth: true
                            Layout.preferredHeight: visible ? 42 : 0
                            radius: Metrics.outerRadius
                            color: Colors.backgroundActivated
                            border.width: 1
                            border.color: Colors.borderActivated
                            clip: true
                            readonly property real transferRatio: downloadManager.totalSize > 0
                                                                  ? Math.min(1.0, downloadManager.totalReceived / downloadManager.totalSize)
                                                                  : 0.0

                            // One footer metric: a Font Awesome glyph that names the
                            // value at a glance, the value itself, and a hover tooltip
                            // spelling out what it is. The glyph replaces the old
                            // "Label: " prefix so the row reads as icons, not text.
                            component StatItem: RowLayout {
                                id: stat
                                property string glyph: ""
                                property string value: ""
                                property string hint: ""
                                property color tint: Colors.textSecondary
                                property int minValueWidth: 0
                                spacing: 6

                                Text {
                                    text: stat.glyph
                                    font.family: FontSystem.getAwesomeSolid.name
                                    font.weight: Font.Black   // selects the Solid face; without it Qt falls back to Regular and the glyph renders as tofu
                                    font.pixelSize: 12
                                    color: stat.tint
                                    Layout.alignment: Qt.AlignVCenter
                                }
                                Controls.Label {
                                    text: stat.value
                                    color: Colors.textPrimary
                                    elide: Text.ElideRight
                                    Layout.minimumWidth: stat.minValueWidth
                                    Layout.alignment: Qt.AlignVCenter
                                }
                                HoverHandler { id: statHover }
                                Controls.ToolTip {
                                    text: stat.hint
                                    active: statHover.hovered
                                    above: true
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 18
                                anchors.rightMargin: 18
                                spacing: 16

                                StatItem {
                                    glyph: String.fromCharCode(0xf06e)   // eye
                                    hint: "Visible downloads (current filter)"
                                    minValueWidth: 18
                                    value: downloadManager.model.filteredCount(appRoot.queueFilter, appRoot.statusFilter, appRoot.categoryFilter, appRoot.searchText)
                                }
                                StatItem {
                                    glyph: String.fromCharCode(0xf625)   // gauge-high
                                    hint: "Total download speed"
                                    tint: downloadManager.totalSpeed > 0 ? Colors.textAccent : Colors.textSecondary
                                    minValueWidth: 78
                                    value: appRoot.formatSpeed(downloadManager.totalSpeed)
                                }
                                StatItem {
                                    glyph: String.fromCharCode(0xf0ed)   // cloud-arrow-down
                                    hint: "Transferred (received / total)"
                                    minValueWidth: 36
                                    value: Math.round(runtimeFooter.transferRatio * 100) + "%"
                                }
                                StatItem {
                                    glyph: String.fromCharCode(0xf2db)   // microchip
                                    hint: "App CPU usage"
                                    minValueWidth: 40
                                    value: downloadManager.processCpuLoad.toFixed(1) + "%"
                                }
                                StatItem {
                                    glyph: String.fromCharCode(0xf538)   // memory
                                    hint: "App memory usage"
                                    minValueWidth: 56
                                    value: appRoot.formatBytes(downloadManager.processMemoryBytes)
                                }
                                StatItem {
                                    glyph: String.fromCharCode(0xf0a0)   // hard-drive
                                    hint: "Free disk space"
                                    minValueWidth: 60
                                    value: appRoot.formatBytes(downloadManager.diskFreeBytes)
                                }

                                // Spacer pushes the connectivity indicators to the far
                                // right, separating live stats from system status.
                                Item { Layout.fillWidth: true }

                                StatItem {
                                    glyph: downloadManager.networkReachability === "Offline"
                                           ? String.fromCharCode(0xf071)   // triangle-exclamation (no connection)
                                           : String.fromCharCode(0xf1eb)   // wifi
                                    hint: "Network: " + downloadManager.networkReachability
                                    tint: downloadManager.networkReachability === "Online"
                                          ? Colors.success
                                          : (downloadManager.networkReachability === "Offline"
                                             ? Colors.error
                                             : Colors.warning)
                                    value: downloadManager.networkReachability
                                }
                                StatItem {
                                    glyph: downloadManager.onBattery
                                           ? String.fromCharCode(0xf240)   // battery-full
                                           : String.fromCharCode(0xf1e6)   // plug
                                    hint: downloadManager.onBattery ? "Running on battery" : "Plugged in (AC power)"
                                    tint: downloadManager.onBattery ? Colors.warning : Colors.success
                                    value: downloadManager.onBattery ? "Battery" : "AC"
                                }
                            }
                        }
                    }

                }
            }

            Controls.ReleaseCenterPage {
                Layout.fillWidth: true
                Layout.fillHeight: true
                dateFormat: appRoot.releaseDateFormat
                onOpenSettings: appRoot.openConfigurationDialog(4)
                onAddGitHubApp: releaseCenterAddDialog.open()
                onViewReleases: function(app) {
                    const url = app && app.repository ? ("https://github.com/" + app.repository + "/releases") : ""
                    if (url.length > 0)
                        appRoot.openExternalLink(url, "Opened GitHub releases")
                }
                onOpenUrl: function(url) {
                    if (url && url.length > 0)
                        appRoot.openExternalLink(url, "Opened link")
                }
                onDownloadAssets: function(app) { appRoot.openAssetPickerForApp(app) }
                onUpdateApp: function(app) { appRoot.startAppUpdate(app) }
                onShowDetails: function(app) {
                    releaseDetailsDialog.app = app
                    releaseDetailsDialog.open()
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

                            Label { text: "Run on schedule" }
                            Switch { id: queueScheduleSwitch }

                            Label { text: "Start time" }
                            TextField {
                                id: queueStartTimeField
                                placeholderText: "02:00 AM"
                                text: "00:00"
                            }

                            Label { text: "End time" }
                            TextField {
                                id: queueEndTimeField
                                placeholderText: "07:00 AM"
                                text: "00:00"
                            }

                            Label { text: "Enable quota" }
                            Switch { id: queueQuotaSwitch }

                            Label { text: "Quota (GB/day)" }
                            SpinBox { id: queueQuotaSpin; from: 0; to: 100000; value: 0 }

                            Label { text: "After queue finishes" }
                            ComboBox {
                                id: queuePostActionCombo
                                Layout.preferredWidth: 220
                                model: appRoot.queuePostActionOptions
                            }

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
                                text: "Restore GENYDL defaults and clear persisted session/configuration state without deleting downloaded files."
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

        Rectangle {
            readonly property bool shouldShow: appRoot.pageIndex !== 0 && appRoot.pageIndex !== 1
            visible: shouldShow
            Layout.fillWidth: true
            Layout.preferredHeight: shouldShow ? 42 : 0
            radius: Metrics.outerRadius
            color: Colors.backgroundActivated
            border.width: 1
            border.color: Colors.borderActivated
            clip: true

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                spacing: 12

                Controls.Label {
                    Layout.preferredWidth: 78
                    elide: Text.ElideRight
                    text: "Visible: " + downloadManager.model.filteredCount(appRoot.queueFilter, appRoot.statusFilter, appRoot.categoryFilter, appRoot.searchText)
                }
                Controls.Label {
                    Layout.preferredWidth: 140
                    elide: Text.ElideRight
                    text: "Speed: " + appRoot.formatSpeed(downloadManager.totalSpeed)
                }
                Controls.Label {
                    Layout.preferredWidth: 112
                    elide: Text.ElideRight
                    text: "Overall: "
                          + (downloadManager.totalSize > 0
                             ? Math.min(100, Math.max(0, (downloadManager.totalReceived / downloadManager.totalSize) * 100)).toFixed(1) + "%"
                             : "--")
                }
                Item { Layout.fillWidth: true }
                Controls.Label {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignRight
                    text: appRoot.selectedTask
                          ? ("Selected: " + appRoot.baseName(appRoot.taskFileNameValue(appRoot.selectedTask)))
                          : "Selected: None"
                }
            }
        }

    }

}
