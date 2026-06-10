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

Window {
    id: root

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
           ? (Math.round(progressRatio * 100) + "% " + root.baseName(task.fileName()))
           : "Torrent Details"

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
        if (!path || path.length === 0) return "Unknown"
        const idx = Math.max(path.lastIndexOf("/"), path.lastIndexOf("\\"))
        if (idx >= 0 && idx + 1 < path.length) return path.substring(idx + 1)
        return path
    }

    function formatBytes(value) {
        var v = Number(value)
        if (!isFinite(v) || v < 0) v = 0
        const units = ["B", "KB", "MB", "GB", "TB"]
        var i = 0
        while (v >= 1024 && i < units.length - 1) { v /= 1024; i += 1 }
        const digits = v >= 100 ? 0 : (v >= 10 ? 1 : 2)
        return v.toFixed(digits) + " " + units[i]
    }

    function formatSpeed(value) { return formatBytes(value) + "/s" }

    function formatEta(seconds) {
        var s = Number(seconds)
        if (!isFinite(s) || s < 0) return "—"
        if (s < 60) return Math.floor(s) + " sec"
        const m = Math.floor(s / 60)
        const sec = Math.floor(s % 60)
        if (m < 60) return m + " min " + sec + " sec"
        const h = Math.floor(m / 60)
        return h + " h " + (m % 60) + " min"
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
                text: root.task ? root.baseName(root.task.fileName()) : "No selection"
                font.pixelSize: 22
                font.bold: true
                color: Colors.textPrimary
                elide: Text.ElideRight
            }
            Controls.Label {
                text: root.statusText
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

            TabButton { text: "General" }
            TabButton { text: "Swarm" }
            TabButton { text: "Files" }
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

                            Controls.Label { text: "Source" }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Controls.Label {
                                    Layout.fillWidth: true
                                    text: root.task ? root.task.url() : ""
                                    elide: Text.ElideMiddle
                                }
                                Controls.Button {
                                    text: "Copy"
                                    sizeType: "small"
                                    enabled: !!root.task
                                    onClicked: if (root.task) root.copyRequested(root.task.url())
                                }
                            }

                            Controls.Label { text: "State" }
                            Controls.Label { text: root.statusText; role: root.statusRole(root.statusText) }

                            Controls.Label { text: "File size" }
                            Controls.Label { text: root.formatBytes(root.liveTotal) }

                            Controls.Label { text: "Downloaded" }
                            Controls.Label {
                                text: root.formatBytes(root.liveReceived)
                                      + (root.liveTotal > 0
                                         ? " / " + root.formatBytes(root.liveTotal)
                                           + " (" + (root.progressRatio * 100).toFixed(2) + "%)"
                                         : "")
                            }

                            Controls.Label { text: "Uploaded" }
                            Controls.Label { text: root.task ? root.formatBytes(root.task.uploadedBytes) : "0 B" }

                            Controls.Label { text: "Peers" }
                            Controls.Label {
                                text: root.task ? (root.task.seeders + " seeds / " + root.task.leechers + " peers") : "0 / 0"
                                font.bold: true
                            }

                            Controls.Label { text: "Speed" }
                            Controls.Label {
                                text: "↓ " + root.formatSpeed(root.task ? root.task.speed : 0)
                                      + "   ↑ " + root.formatSpeed(root.task ? root.task.uploadSpeed : 0)
                            }

                            Controls.Label { text: "Share ratio" }
                            Controls.Label {
                                text: root.task ? root.task.shareRatio.toFixed(2) : "0.00"
                                role: (root.task && root.task.shareRatio >= 1.0) ? 4 : 0
                            }

                            Controls.Label { text: "ETA" }
                            Controls.Label { text: root.formatEta(root.task ? root.task.eta : -1) }

                            Controls.Label { text: "Queue" }
                            Controls.Label { text: root.queueName }

                            Controls.Label { text: "Category" }
                            Controls.Label { text: root.categoryName }
                        }
                    }

                    Controls.GroupBox {
                        title: "Piece Map"
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
                                text: "Piece map appears once metadata is available…"
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
                            title: "Seeders"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 100
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                Controls.Label { text: root.task ? String(root.task.seeders) : "0"; role: 4; font.bold: true; font.pixelSize: Typography.t1 }
                                Controls.Label { text: "connected + in swarm" }
                            }
                        }

                        Controls.GroupBox {
                            title: "Leechers"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 100
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                Controls.Label { text: root.task ? String(root.task.leechers) : "0"; font.bold: true; font.pixelSize: Typography.t1 }
                                Controls.Label { text: "downloading peers" }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Controls.GroupBox {
                            title: "Download"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 100
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                Controls.Label { text: root.formatSpeed(root.task ? root.task.speed : 0); font.bold: true }
                                Controls.Label { text: root.formatBytes(root.liveReceived) + " received" }
                            }
                        }

                        Controls.GroupBox {
                            title: "Upload"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 100
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                Controls.Label { text: root.formatSpeed(root.task ? root.task.uploadSpeed : 0); font.bold: true }
                                Controls.Label { text: (root.task ? root.formatBytes(root.task.uploadedBytes) : "0 B") + " sent · ratio " + (root.task ? root.task.shareRatio.toFixed(2) : "0.00") }
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
                        title: "Files"
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
                                    return n > 0 ? (n + " file(s) — uncheck to skip downloading")
                                                 : "Waiting for torrent metadata…"
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
                text: (root.statusText === "Paused") ? "Resume" : "Pause"
                enabled: root.row >= 0
                onClicked: root.pauseResumeRequested(root.row)
            }

            Item { Layout.fillWidth: true }

            Controls.Button {
                text: "Open"
                enabled: root.row >= 0 && (root.statusText === "Done" || root.statusText === "Seeding")
                onClicked: root.openRequested(root.row)
            }
            Controls.Button {
                text: "Show in Folder"
                enabled: root.row >= 0
                onClicked: root.revealRequested(root.row)
            }
            Controls.Button {
                text: "Remove"
                style: "danger"
                enabled: root.row >= 0
                onClicked: root.removeRequested(root.row)
            }
            Controls.Button {
                text: "Close"
                onClicked: root.close()
            }
        }
    }
}
