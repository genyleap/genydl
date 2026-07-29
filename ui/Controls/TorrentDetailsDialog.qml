/*!
    \file        TorrentDetailsDialog.qml
    \brief       BitTorrent download details window for GENYDL.
    \details     Mirrors the regular download details window (header, progress
                 bar, tabbed GroupBox layout, footer actions) so HTTP and
                 torrent items share one consistent look. Adds torrent-specific
                 tabs: Swarm (seed/peer/ratio) and Files (per-file picker).

    \author      Kambiz Asadzadeh <https://github.com/thecompez>
    \copyright   Copyright (c) 2026 Genyleap. All rights reserved.
    \license     https://github.com/genyleap/genydl/blob/main/LICENSE.md
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

import GenyDL // Colors, FontSystem, Typography, Metrics
import "." as Controls
import "../utils.js" as Utils

Window {
    id: root

    LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    property int row: -1
    property var task: null
    property string queueName: ""
    property string categoryName: ""
    property int tabIndex: 0

    signal pauseResumeRequested(int row)
    signal removeRequested(int row)
    signal openRequested(int row)
    signal revealRequested(int row)
    signal copyRequested(string text)

    width: 860
    height: 680
    minimumWidth: 760
    minimumHeight: 520
    visible: false
    color: Colors.backgroundActivated

    readonly property string statusText: task ? task.stateString : ""

    title: task
           ? (Utils.formatPercent(Math.round(progressRatio * 100), 0) + " " + root.baseName(task.fileName()))
           : qsTr("Torrent Details")

    // ---- Live progress mirror (TorrentTask emits progress(received,total)) ----
    property real liveReceived: 0
    property real liveTotal: 0
    readonly property real progressRatio: liveTotal > 0 ? Math.min(1.0, liveReceived / liveTotal) : 0.0

    // Piece-completion cells for the piece map (downsampled per update).
    property var pieceCells: []

    // Piece-map grid geometry — recomputed from the card size so cells fill it.
    property int pmCols: 80
    property int pmSpacing: 2
    property int pmCell: 8
    property int pmBuckets: 800

    function updatePieceGeometry(w, h) {
        if (w <= 0 || h <= 0) return
        const cols = pmCols
        const cell = Math.max(4, Math.floor((w - (cols - 1) * pmSpacing) / cols))
        const rows = Math.max(1, Math.floor((h + pmSpacing) / (cell + pmSpacing)))
        pmCell = cell
        const n = cols * rows
        if (n !== pmBuckets) { pmBuckets = n; refreshPieces() }
    }

    function refreshFromRow() {
        if (row < 0) return
        liveReceived = Number(downloadManager.taskBytesReceived(row))
        liveTotal = Number(downloadManager.taskBytesTotal(row))
        refreshPieces()
    }

    function refreshPieces() {
        pieceCells = task ? task.pieceMap(pmBuckets) : []
    }

    onVisibleChanged: if (visible) { tabIndex = 0; refreshFromRow() }

    Connections {
        target: root.task
        ignoreUnknownSignals: true
        function onProgress(received, total) {
            root.liveReceived = Math.max(0, Number(received))
            root.liveTotal = Math.max(0, Number(total))
        }
        function onPiecesChanged() { root.refreshPieces() }
    }

    function baseName(path) {
        if (!path || path.length === 0) return qsTr("Unknown")
        const idx = Math.max(path.lastIndexOf("/"), path.lastIndexOf("\\"))
        if (idx >= 0 && idx + 1 < path.length) return path.substring(idx + 1)
        return path
    }

    function formatBytes(value) {
        return Utils.formatBytes(value)
    }

    function formatSpeed(value) { return Utils.formatSpeed(value) }

    function formatEta(seconds) {
        return Utils.formatEta(seconds)
    }

    // Status string → custom-Label role for colour (0 secondary, 4 success, 6 error)
    function statusRole(s) {
        if (s === "Error") return 6
        if (s === "Downloading" || s === "Seeding" || s === "Done") return 4
        return 0
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        // ---- Header ----
        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: root.task ? root.baseName(root.task.fileName()) : qsTr("No selection")
                font.pixelSize: 22
                font.bold: true
                color: Colors.textPrimary
                elide: AppGlobals.rtl ? Text.ElideLeft : Text.ElideRight
            }
            Controls.Label {
                text: languageManager.statusLabel(root.statusText)
                role: root.statusRole(root.statusText)
                font.bold: true
            }
        }

        Controls.ProgressBar {
            Layout.fillWidth: true
            value: root.progressRatio
            statusLevel: root.statusText
            indeterminate: root.liveTotal <= 0 && root.statusText === "Metadata"
        }

        TabBar {
            id: detailsTabs
            Layout.fillWidth: true
            currentIndex: root.tabIndex
            onCurrentIndexChanged: root.tabIndex = currentIndex

            TabButton { text: qsTr("General") }
            TabButton { text: qsTr("Swarm") }
            TabButton { text: qsTr("Files") }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root.tabIndex

            // ============================ General ============================
            Item {
                clip: true
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 8

                    Controls.GroupBox {
                        title: qsTr("Status")
                        Layout.fillWidth: true
                        Layout.preferredHeight: statusGrid.implicitHeight + 64

                        GridLayout {
                            id: statusGrid
                            anchors.fill: parent
                            anchors.margins: 10
                            columns: 2
                            columnSpacing: 16
                            rowSpacing: 6

                            Controls.Label { text: qsTr("Source") }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Controls.Label {
                                    Layout.fillWidth: true
                                    text: root.task ? root.task.url() : ""
                                    elide: Text.ElideMiddle
                                }
                                Controls.Button {
                                    text: qsTr("Copy")
                                    sizeType: "small"
                                    enabled: !!root.task
                                    onClicked: if (root.task) root.copyRequested(root.task.url())
                                }
                            }

                            Controls.Label { text: qsTr("State") }
                            Controls.Label { text: languageManager.statusLabel(root.statusText); role: root.statusRole(root.statusText) }

                            Controls.Label { text: qsTr("File size") }
                            Controls.Label { text: root.formatBytes(root.liveTotal) }

                            Controls.Label { text: qsTr("Downloaded") }
                            Controls.Label {
                                text: root.formatBytes(root.liveReceived)
                                      + (root.liveTotal > 0
                                         ? " / " + root.formatBytes(root.liveTotal)
                                           + " (" + (root.progressRatio * 100).toLocaleString(Qt.locale(languageManager.currentLocale), "f", 2) + "%)"
                                         : "")
                            }

                            Controls.Label { text: qsTr("Uploaded") }
                            Controls.Label { text: root.formatBytes(root.task ? root.task.uploadedBytes : 0) }

                            Controls.Label { text: qsTr("Peers") }
                            Controls.Label {
                                text: root.task
                                      ? qsTr("%1 seeds / %2 peers")
                                            .arg(Number(root.task.seeders).toLocaleString(Qt.locale(languageManager.currentLocale), "f", 0))
                                            .arg(Number(root.task.leechers).toLocaleString(Qt.locale(languageManager.currentLocale), "f", 0))
                                      : Utils.formatRatio(0, 0)
                                font.bold: true
                            }

                            Controls.Label { text: qsTr("Speed") }
                            Controls.Label {
                                text: qsTr("↓ ") + root.formatSpeed(root.task ? root.task.speed : 0)
                                      + "   ↑ " + root.formatSpeed(root.task ? root.task.uploadSpeed : 0)
                            }

                            Controls.Label { text: qsTr("Share ratio") }
                            Controls.Label {
                                text: root.task ? root.task.shareRatio.toLocaleString(Qt.locale(languageManager.currentLocale), "f", 2) : "0.00"
                                role: (root.task && root.task.shareRatio >= 1.0) ? 4 : 0
                            }

                            Controls.Label { text: qsTr("ETA") }
                            Controls.Label { text: root.formatEta(root.task ? root.task.eta : -1) }

                            Controls.Label { text: qsTr("Queue") }
                            Controls.Label { text: languageManager.queueLabel(root.queueName) }

                            Controls.Label { text: qsTr("Category") }
                            Controls.Label { text: languageManager.categoryLabel(root.categoryName) }
                        }
                    }

                    Controls.GroupBox {
                        title: qsTr("Piece Map")
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 90

                        Item {
                            id: pieceArea
                            anchors.fill: parent
                            anchors.margins: 10
                            clip: true

                            onWidthChanged: root.updatePieceGeometry(width, height)
                            onHeightChanged: root.updatePieceGeometry(width, height)
                            Component.onCompleted: root.updatePieceGeometry(width, height)

                            Grid {
                                anchors.fill: parent
                                columns: root.pmCols
                                spacing: root.pmSpacing

                                Repeater {
                                    model: root.pieceCells.length
                                    delegate: Rectangle {
                                        required property int index
                                        width: root.pmCell
                                        height: root.pmCell
                                        radius: 1
                                        color: {
                                            const v = root.pieceCells[index]
                                            if (v >= 0.999) return Colors.success
                                            if (v > 0.0)    return Colors.textAccent
                                            return Qt.lighter(Colors.textMuted)
                                        }
                                    }
                                }
                            }

                            // Empty-state hint until pieces are known.
                            Controls.Label {
                                anchors.centerIn: parent
                                visible: root.pieceCells.length === 0
                                text: qsTr("Piece map appears once metadata is available…")
                            }
                        }
                    }
                }
            }

            // ============================= Swarm =============================
            Item {
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Controls.GroupBox {
                            title: qsTr("Seeders")
                            Layout.fillWidth: true
                            Layout.preferredHeight: 100
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                Controls.Label {
                                    text: Number(root.task ? root.task.seeders : 0).toLocaleString(Qt.locale(languageManager.currentLocale), "f", 0)
                                    role: 4
                                    font.bold: true
                                    font.pixelSize: Typography.t1
                                }
                                Controls.Label { text: qsTr("connected + in swarm") }
                            }
                        }

                        Controls.GroupBox {
                            title: qsTr("Leechers")
                            Layout.fillWidth: true
                            Layout.preferredHeight: 100
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                Controls.Label {
                                    text: Number(root.task ? root.task.leechers : 0).toLocaleString(Qt.locale(languageManager.currentLocale), "f", 0)
                                    font.bold: true
                                    font.pixelSize: Typography.t1
                                }
                                Controls.Label { text: qsTr("downloading peers") }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Controls.GroupBox {
                            title: qsTr("Download")
                            Layout.fillWidth: true
                            Layout.preferredHeight: 100
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                Controls.Label { text: root.formatSpeed(root.task ? root.task.speed : 0); font.bold: true }
                                Controls.Label { text: qsTr("%1 received").arg(root.formatBytes(root.liveReceived)) }
                            }
                        }

                        Controls.GroupBox {
                            title: qsTr("Upload")
                            Layout.fillWidth: true
                            Layout.preferredHeight: 100
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                Controls.Label { text: root.formatSpeed(root.task ? root.task.uploadSpeed : 0); font.bold: true }
                                Controls.Label {
                                    text: qsTr("%1 sent · ratio %2")
                                          .arg(root.task ? root.formatBytes(root.task.uploadedBytes) : qsTr("0 B"))
                                          .arg(root.task ? root.task.shareRatio.toLocaleString(Qt.locale(languageManager.currentLocale), "f", 2) : "0.00")
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }

            // ============================= Files =============================
            Item {
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 8

                    Controls.GroupBox {
                        title: qsTr("Files")
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            Controls.Label {
                                Layout.fillWidth: true
                                text: {
                                    const n = root.task && root.task.fileList ? root.task.fileList.length : 0
                                    return n > 0 ? qsTr("%n file(s) — uncheck to skip downloading", "", n)
                                                 : qsTr("Waiting for torrent metadata…")
                                }
                            }

                            ListView {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                spacing: 2
                                model: root.task && root.task.fileList ? root.task.fileList : []

                                delegate: Rectangle {
                                    required property int index
                                    required property var modelData
                                    width: ListView.view.width
                                    height: 32
                                    radius: Metrics.innerRadius / 2
                                    color: index % 2 === 0 ? Colors.background : Colors.backgroundItemActivated

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        spacing: 8

                                        Controls.CheckBox {
                                            checked: true
                                            onToggled: if (root.task) root.task.setFileEnabled(index, checked)
                                        }
                                        Controls.Label {
                                            Layout.fillWidth: true
                                            text: String(modelData)
                                            elide: Text.ElideMiddle
                                        }
                                    }
                                }

                                ScrollBar.vertical: ScrollBar { }
                            }
                        }
                    }
                }
            }
        }

        // ---- Footer actions ----
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Controls.Button {
                text: (root.statusText === "Paused") ? qsTr("Resume") : qsTr("Pause")
                enabled: root.row >= 0
                onClicked: root.pauseResumeRequested(root.row)
            }

            Item { Layout.fillWidth: true }

            Controls.Button {
                text: qsTr("Open")
                enabled: root.row >= 0 && (root.statusText === "Done" || root.statusText === "Seeding")
                onClicked: root.openRequested(root.row)
            }
            Controls.Button {
                text: qsTr("Show in Folder")
                enabled: root.row >= 0
                onClicked: root.revealRequested(root.row)
            }
            Controls.Button {
                text: qsTr("Remove")
                style: "danger"
                enabled: root.row >= 0
                onClicked: root.removeRequested(root.row)
            }
            Controls.Button {
                text: qsTr("Close")
                onClicked: root.close()
            }
        }
    }
}
