/*!
    \file        ReleaseCenterPage.qml
    \brief       Release Center page for tracked GitHub release apps.
    \details     Displays tracked repositories, update state, quick actions,
                 and Release Center settings.

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

Pane {
    id: page

    signal addGitHubApp()
    signal downloadAssets(var app)
    signal updateApp(var app)
    signal viewReleases(var app)
    signal openUrl(string url)
    signal openSettings()

    // Release date display format, bound from the app root. One of:
    // "relative" | "datetime" | "day" | "month".
    property string dateFormat: "datetime"
    // Emitted when the user picks a new date format in settings.
    signal requestDateFormat(string mode)

    // Labels + modes for the date-format selector.
    readonly property var dateFormatModes: ["relative", "datetime", "day", "month"]
    readonly property var dateFormatLabels: ["Relative (2 hours ago)",
                                             "Full (2026-06-05 18:23)",
                                             "Date (May 28, 2026)",
                                             "Month (Jun 2025)"]

    // Check-frequency presets. Index 0 ("Manual only") disables automatic checks;
    // the rest map to an interval in hours.
    readonly property var intervalPresetLabels: ["Manual only", "Every 6 hours",
                                                 "Every 12 hours", "Daily", "Weekly"]
    readonly property var intervalPresetHours: [0, 6, 12, 24, 168]
    function currentIntervalPresetIndex() {
        if (!releaseCenterService.automaticChecksEnabled) return 0
        const idx = intervalPresetHours.indexOf(releaseCenterService.checkIntervalHours)
        return idx > 0 ? idx : 3   // fall back to "Daily" for a custom value
    }
    function applyIntervalPreset(i) {
        if (i <= 0) { releaseCenterService.automaticChecksEnabled = false; return }
        releaseCenterService.checkIntervalHours = intervalPresetHours[i]
        releaseCenterService.automaticChecksEnabled = true
    }
    // True when the chosen interval is aggressive enough to warrant an extra note.
    readonly property bool frequentInterval: releaseCenterService.automaticChecksEnabled
                                             && releaseCenterService.checkIntervalHours <= 6

    // What to do when an update is found.
    readonly property var downloadPolicyModes: ["notify", "ask", "auto"]
    readonly property var downloadPolicyLabels: ["Notify only",
                                                 "Ask before downloading",
                                                 "Download automatically"]

    // The page always renders in the dense layout; users switch how the cards
    // are arranged instead (a vertical list or a wrapping grid).
    readonly property bool compact: true
    property string viewMode: "list"   // "list" | "grid"
    property int selectedIndex: -1     // focused card row (-1 = none)

    signal showDetails(var app)

    // --- Keyboard navigation helpers (selectedIndex == app rowIndex == array idx).
    function moveSelection(delta) {
        const count = releaseCenterService.apps.length
        if (count === 0) return
        var next = page.selectedIndex < 0
                   ? (delta > 0 ? 0 : count - 1)
                   : page.selectedIndex + delta
        page.selectedIndex = Math.max(0, Math.min(count - 1, next))
    }
    function openSelectedDetails() {
        const apps = releaseCenterService.apps
        if (page.selectedIndex >= 0 && page.selectedIndex < apps.length)
            page.showDetails(apps[page.selectedIndex])
    }

    // Build the canonical GitHub releases URL for a tracked app.
    function releasesUrlFor(app) {
        const repo = app && app.repository ? String(app.repository)
                   : (app ? (String(app.owner || "") + "/" + String(app.repo || "")) : "")
        return repo.length > 1 ? ("https://github.com/" + repo + "/releases") : ""
    }

    background: Rectangle {
        color: Colors.backgroundActivated
        radius: Metrics.outerRadius
    }

    // Re-scan install/download state whenever the page is shown, so a download
    // that completed elsewhere in the app is reflected without a manual check.
    onVisibleChanged: if (visible) releaseCenterService.refreshInstallStates()
    Component.onCompleted: releaseCenterService.refreshInstallStates()

    function statusColor(status) {
        if (status === "update_available") return Colors.secondry   // actionable -> blue
        if (status === "downloaded") return Colors.star             // ready to install -> amber
        if (status === "check_failed") return Colors.error
        if (status === "never_checked") return Colors.warning
        if (status === "up_to_date") return Colors.success          // ok -> green
        if (status === "not_installed") return Colors.primary       // neutral -> gray
        return Colors.textSecondary
    }

    function statusBorderColor(status) {
        if (status === "update_available" || status === "downloaded"
                || status === "check_failed"
                || status === "never_checked" || status === "up_to_date"
                || status === "not_installed")
            return statusColor(status)
        return Colors.lineBorderActivated
    }

    function statusBackColor(status) {
        if (status === "update_available") return Colors.secondryBack
        if (status === "downloaded") return Colors.starBack
        if (status === "check_failed") return Colors.errorBack
        if (status === "never_checked") return Colors.warningBack
        if (status === "up_to_date") return Colors.successBack
        if (status === "not_installed") return Colors.primaryBack
        return Colors.backgroundItemHovered
    }

    function statusGlyph(status) {
        if (status === "update_available") return ""  // arrow-circle-up
        if (status === "check_failed") return ""      // circle-exclamation
        if (status === "never_checked") return ""     // clock
        if (status === "up_to_date") return ""        // circle-check
        if (status === "downloaded") return String.fromCharCode(0xf358)     // arrow-circle-down (ready to install)
        if (status === "not_installed") return String.fromCharCode(0xf019)  // download
        return ""                                      // circle-question
    }

    function formatCount(value) {
        var n = Number(value || 0)
        if (n >= 1000000)
            return (n / 1000000).toFixed(n >= 10000000 ? 0 : 1) + "M"
        if (n >= 1000)
            return (n / 1000).toFixed(n >= 10000 ? 0 : 1) + "K"
        return String(n)
    }

    function ownerInitial(owner) {
        const value = String(owner || "?").trim()
        return value.length > 0 ? value.charAt(0).toUpperCase() : "?"
    }

    // ---- Reusable inline components ------------------------------------

    // Small rotating glyph used as an inline loading indicator.
    component Spinner: Text {
        text: ""                       // circle-notch
        font.family: FontSystem.getAwesomeSolid.name
        font.weight: Font.Black
        font.pixelSize: 14
        color: Colors.textSecondary
        NumberAnimation on rotation {
            from: 0; to: 360
            duration: 900
            loops: Animation.Infinite
            running: parent ? parent.visible : true
        }
    }

    // One cell of the segmented List / Grid switch. The active highlight is drawn
    // by ViewToggle as an inset, rounded sliding pill, so the cell itself only
    // needs a faint hover tint.
    component ViewSegment: Item {
        property string glyph: ""
        property string mode: ""
        readonly property bool active: page.viewMode === mode
        implicitWidth: 38
        height: parent ? parent.height : 30

        Accessible.role: Accessible.RadioButton
        Accessible.name: mode === "grid" ? "Grid view" : "List view"
        Accessible.checked: active
        Accessible.onPressAction: page.viewMode = mode

        // Faint hover background, inset + rounded so it stays inside the frame.
        Rectangle {
            anchors.fill: parent
            anchors.margins: 3
            radius: Metrics.innerRadius - 3
            color: (segHover.hovered && !active) ? Colors.backgroundItemHovered : "transparent"
            Behavior on color { ColorAnimation { duration: Animations.fast } }
        }
        Text {
            anchors.centerIn: parent
            text: glyph
            font.family: FontSystem.getAwesomeSolid.name
            font.weight: Font.Black
            font.pixelSize: 13
            color: active ? Colors.textPrimary
                          : (segHover.hovered ? Colors.textPrimary : Colors.textSecondary)
            Behavior on color { ColorAnimation { duration: Animations.fast } }
        }
        HoverHandler { id: segHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: page.viewMode = mode }
    }

    // Segmented List / Grid switch. A sliding, inset, rounded highlight marks the
    // active mode and animates between the two cells. No clip is used (rectangular
    // clipping can't follow rounded corners) - the pill is simply inset instead.
    component ViewToggle: Rectangle {
        id: toggle
        readonly property int cellW: 38
        implicitWidth: cellW * 2
        implicitHeight: 30
        radius: Metrics.innerRadius
        color: Colors.pagespaceActivated
        border.width: 1
        border.color: Colors.borderActivated

        Rectangle {
            width: toggle.cellW - 6
            height: toggle.height - 6
            y: 3
            x: 3 + (page.viewMode === "grid" ? toggle.cellW : 0)
            radius: toggle.radius - 3
            color: Colors.backgroundFocused
            border.width: 1
            border.color: Colors.borderActivated
            Behavior on x { NumberAnimation { duration: Animations.normal; easing.type: Easing.OutCubic } }
        }

        Row {
            anchors.fill: parent
            ViewSegment { glyph: String.fromCharCode(0xf03a); mode: "list" }   // list
            ViewSegment { glyph: String.fromCharCode(0xf00a); mode: "grid" }   // grid
        }
    }

    // A repository avatar with rounded masking, async loading shimmer and a
    // gradient initial fallback when no image is available.
    component AvatarBadge: Item {
        id: avatar
        property string url: ""
        property string initial: "?"
        property bool highlight: false

        Rectangle {
            id: avatarFrame
            anchors.fill: parent
            radius: width * 0.26
            border.width: 1
            border.color: avatar.highlight ? Colors.success : Colors.borderActivated
            clip: true

            // Gradient fallback shown while loading or when no avatar exists.
            gradient: Gradient {
                GradientStop { position: 0.0; color: Colors.backgroundItemHovered }
                GradientStop { position: 1.0; color: Colors.pagespaceActivated }
            }

            Controls.Label {
                anchors.centerIn: parent
                visible: repoAvatar.status !== Image.Ready
                text: avatar.initial
                font.pixelSize: Math.round(avatar.height * 0.42)
                font.bold: true
                color: Colors.textSecondary
            }

            // Subtle shimmer while the network image loads.
            Rectangle {
                anchors.fill: parent
                visible: repoAvatar.status === Image.Loading
                color: "transparent"
                Rectangle {
                    width: parent.width * 0.6
                    height: parent.height
                    rotation: 18
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "#00ffffff" }
                        GradientStop { position: 0.5; color: "#22ffffff" }
                        GradientStop { position: 1.0; color: "#00ffffff" }
                    }
                    SequentialAnimation on x {
                        running: repoAvatar.status === Image.Loading
                        loops: Animation.Infinite
                        NumberAnimation { from: -parent.width; to: parent.width * 1.4; duration: 1100; easing.type: Easing.InOutQuad }
                        PauseAnimation { duration: 250 }
                    }
                }
            }

            Image {
                id: repoAvatar
                anchors.fill: parent
                source: avatar.url
                fillMode: Image.PreserveAspectCrop
                smooth: true
                mipmap: true
                cache: true
                asynchronous: true
                sourceSize.width: 144
                sourceSize.height: 144
                visible: false
            }

            // Mask used to clip the image to the frame's rounded corners.
            Rectangle {
                id: avatarMask
                anchors.fill: parent
                radius: avatarFrame.radius
                visible: false
                layer.enabled: true
            }

            MultiEffect {
                anchors.fill: parent
                source: repoAvatar
                maskEnabled: true
                maskSource: avatarMask
                visible: repoAvatar.status === Image.Ready
            }
        }
    }

    // Icon + value pill used for stars / forks.
    component StatPill: Rectangle {
        property string glyph: ""
        property color glyphColor: Colors.textSecondary
        property string value: ""
        implicitWidth: statRow.implicitWidth + 20
        implicitHeight: page.compact ? 26 : 30
        radius: Metrics.innerRadius
        color: Colors.pagespaceActivated
        border.width: 1
        border.color: Colors.borderActivated

        RowLayout {
            id: statRow
            anchors.centerIn: parent
            spacing: 6
            Text {
                text: glyph
                font.family: FontSystem.getAwesomeSolid.name
                font.weight: Font.Black
                font.pixelSize: page.compact ? 11 : 12
                color: glyphColor
                verticalAlignment: Text.AlignVCenter
            }
            Controls.Label {
                text: value
                color: Colors.textPrimary
                font.pixelSize: page.compact ? Typography.t3 : Typography.t2
            }
        }
    }

    // Compact "label value" pair used in the version metadata row.
    component InfoField: RowLayout {
        property string label: ""
        property string value: ""
        spacing: 6
        Controls.Label {
            text: label
            color: Colors.textMuted
            font.pixelSize: Typography.t3
        }
        Controls.Label {
            text: value && value.length > 0 ? value : "--"
            color: Colors.textPrimary
            font.pixelSize: Typography.t3
            elide: Text.ElideRight
            Layout.maximumWidth: 180
        }
    }

    // Icon + text chip used for language / license / homepage.
    component MetaChip: Rectangle {
        property string glyph: ""
        property string label: ""
        property color tint: Colors.borderActivated
        property color back: Colors.pagespaceActivated
        property color fg: Colors.textSecondary
        implicitWidth: Math.min(metaRow.implicitWidth + 20, 180)
        implicitHeight: page.compact ? 26 : 30
        radius: Metrics.innerRadius
        color: back
        border.width: 1
        border.color: tint

        RowLayout {
            id: metaRow
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 6
            Text {
                text: glyph
                visible: glyph.length > 0
                font.family: FontSystem.getAwesomeSolid.name
                font.weight: Font.Black
                font.pixelSize: page.compact ? 11 : 12
                color: fg
            }
            Controls.Label {
                Layout.fillWidth: true
                text: label
                color: fg
                elide: Text.ElideRight
                font.pixelSize: page.compact ? Typography.t3 : Typography.t2
            }
        }
    }

    // Inline status banner (offline / rate-limit / error) with an optional action.
    component Banner: Rectangle {
        property string glyph: ""
        property string message: ""
        property color tint: Colors.warning
        property color back: Colors.warningBack
        property string actionText: ""
        property bool actionEnabled: true
        signal action()

        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(44, bannerRow.implicitHeight + 16)
        radius: Metrics.innerRadius
        color: back
        border.width: 1
        border.color: tint

        RowLayout {
            id: bannerRow
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 10

            Text {
                text: glyph
                visible: glyph.length > 0
                font.family: FontSystem.getAwesomeSolid.name
                font.weight: Font.Black
                font.pixelSize: 14
                color: tint
            }
            Controls.Label {
                Layout.fillWidth: true
                text: message
                color: Colors.textPrimary
                wrapMode: Text.WordWrap
            }
            Controls.Button {
                visible: actionText.length > 0
                sizeType: "small"
                text: actionText
                enabled: actionEnabled
                onClicked: action()
            }
        }
    }

    // Clickable accent chip for opening external links (official site, releases).
    component LinkChip: Rectangle {
        property string glyph: ""
        property string label: ""
        signal activated()
        implicitWidth: linkRow.implicitWidth + 20
        implicitHeight: page.compact ? 26 : 30
        radius: Metrics.innerRadius
        color: linkHover.hovered ? Colors.secondryBack : Colors.pagespaceActivated
        border.width: 1
        border.color: linkHover.hovered ? Colors.secondry : Colors.borderActivated
        Behavior on color { ColorAnimation { duration: Animations.fast } }

        RowLayout {
            id: linkRow
            anchors.centerIn: parent
            spacing: 6
            Text {
                text: glyph
                visible: glyph.length > 0
                font.family: FontSystem.getAwesomeSolid.name
                font.weight: Font.Black
                font.pixelSize: page.compact ? 11 : 12
                color: Colors.textAccent
            }
            Controls.Label {
                text: label
                color: Colors.textAccent
                font.pixelSize: page.compact ? Typography.t3 : Typography.t2
            }
        }

        HoverHandler { id: linkHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: activated() }
    }

    // -------------------------------------------------------------------

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Metrics.padding * 2
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Controls.Label {
                    text: "Release Center"
                    font.pixelSize: Typography.h3
                    font.bold: true
                }
                Controls.Label {
                    Layout.fillWidth: true
                    text: "Track public GitHub Releases and get notified when newer tags are published."
                    color: Colors.textSecondary
                    elide: Text.ElideRight
                }
            }

            // Inline "checking" indicator shown while any check is in flight.
            RowLayout {
                spacing: 8
                visible: releaseCenterService.loading
                opacity: visible ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: Animations.fast } }
                Spinner {}
                Controls.Label {
                    text: "Checking for updates..."
                    color: Colors.textSecondary
                }
            }

            ViewToggle {}

            // Opens the Release Center settings (now a tab in the Configuration
            // drawer) so this page can stay a full-height app list.
            Rectangle {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 30
                radius: Metrics.innerRadius
                color: gearHover.hovered ? Colors.backgroundItemHovered : Colors.pagespaceActivated
                border.width: 1
                border.color: Colors.borderActivated
                Behavior on color { ColorAnimation { duration: Animations.fast } }
                Text {
                    anchors.centerIn: parent
                    text: String.fromCharCode(0xf013)   // gear
                    font.family: FontSystem.getAwesomeSolid.name
                    font.weight: Font.Black
                    font.pixelSize: 13
                    color: Colors.textSecondary
                }
                Accessible.role: Accessible.Button
                Accessible.name: "Release Center settings"
                HoverHandler { id: gearHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: page.openSettings() }
                Controls.ToolTip { text: "Release Center settings"; active: gearHover.hovered }
            }

            Controls.Button {
                text: releaseCenterService.loading ? "Checking..." : "Check All"
                enabled: !releaseCenterService.loading && releaseCenterService.apps.length > 0
                onClicked: releaseCenterService.checkAll()
            }

            Controls.Button {
                text: "Add GitHub App"
                isDefault: true
                onClicked: page.addGitHubApp()
                Layout.preferredWidth: 150
            }
        }

        // Offline banner — GitHub can't be reached at all.
        Banner {
            visible: typeof downloadManager !== "undefined"
                     && downloadManager.networkReachability === "Offline"
            glyph: String.fromCharCode(0xf127)   // link-slash
            tint: Colors.error
            back: Colors.errorBack
            message: "You're offline. Release checks will resume when the connection is back."
        }

        // GitHub API rate-limit notice, with a quick retry.
        Banner {
            visible: releaseCenterService.rateLimitWarning.length > 0
            glyph: String.fromCharCode(0xf2f9)   // rotate / clock-ish
            tint: Colors.warning
            back: Colors.warningBack
            message: releaseCenterService.rateLimitWarning
            actionText: "Retry"
            actionEnabled: !releaseCenterService.loading
            onAction: releaseCenterService.checkAll()
        }

        // General error from the last request.
        Banner {
            visible: releaseCenterService.errorMessage.length > 0
            glyph: String.fromCharCode(0xf071)   // triangle-exclamation
            tint: Colors.error
            back: Colors.errorBack
            message: releaseCenterService.errorMessage
            actionText: "Retry"
            actionEnabled: !releaseCenterService.loading
            onAction: releaseCenterService.checkAll()
        }

        ScrollView {
            id: releaseCenterListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            focus: true
            activeFocusOnTab: true

            // Keyboard navigation: Up/Down move the selection, Enter opens details,
            // Space/U triggers an update for the selected app when one is available.
            Keys.onUpPressed: page.moveSelection(-1)
            Keys.onDownPressed: page.moveSelection(1)
            Keys.onReturnPressed: page.openSelectedDetails()
            Keys.onEnterPressed: page.openSelectedDetails()

            ColumnLayout {
                width: Math.max(600, releaseCenterListView.availableWidth)
                spacing: page.compact ? 8 : 10

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 86
                    radius: Metrics.innerRadius
                    color: Colors.backgroundItemActivated
                    visible: releaseCenterService.apps.length === 0

                    Controls.Label {
                        anchors.centerIn: parent
                        text: "No apps tracked yet. Add a GitHub releases page to start watching updates."
                        color: Colors.textMuted
                    }
                }

                GridLayout {
                    id: cardsGrid
                    Layout.fillWidth: true
                    columnSpacing: 10
                    rowSpacing: 10
                    columns: page.viewMode === "grid"
                             ? Math.max(1, Math.floor((width + columnSpacing) / 480))
                             : 1

                    Repeater {
                    model: releaseCenterService.apps

                    delegate: Rectangle {
                        id: card
                        required property var modelData

                        readonly property int pad: page.compact ? 12 : 14
                        readonly property bool selected: page.selectedIndex === modelData.rowIndex

                        // Screen-reader metadata: announce the app and its update state.
                        Accessible.role: Accessible.Button
                        Accessible.name: (modelData.displayName || modelData.repo)
                                         + ", " + (modelData.statusText || "")
                        Accessible.description: "Latest " + (modelData.latestTag || "unknown")
                                                + ". Press Enter for details."
                        Accessible.focusable: true
                        Accessible.onPressAction: page.showDetails(modelData)

                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        Layout.preferredHeight: cardContent.implicitHeight + pad * 2
                        radius: Metrics.innerRadius
                        color: selected ? Colors.backgroundItemFocused
                                        : (appCardHover.hovered ? Colors.backgroundItemHovered
                                                                : Colors.backgroundItemActivated)
                        border.width: selected ? 2 : 1
                        border.color: selected ? Colors.borderFocused
                                     : (modelData.status === "update_available" ? Colors.success
                                                                                : Colors.borderActivated)

                        Behavior on color { ColorAnimation { duration: Animations.fast } }
                        Behavior on border.color { ColorAnimation { duration: Animations.fast } }

                        ColumnLayout {
                            id: cardContent
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: card.pad
                            spacing: page.compact ? 8 : 12

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: page.compact ? 10 : 14

                                AvatarBadge {
                                    Layout.preferredWidth: page.compact ? 44 : 72
                                    Layout.preferredHeight: page.compact ? 44 : 72
                                    Layout.alignment: Qt.AlignTop
                                    url: card.modelData.avatarUrl || ""
                                    initial: page.ownerInitial(card.modelData.owner)
                                    highlight: card.modelData.status === "update_available"
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignTop
                                    spacing: page.compact ? 3 : 5

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Controls.Label {
                                            Layout.fillWidth: true
                                            text: card.modelData.displayName || card.modelData.repo
                                            font.bold: true
                                            font.pixelSize: page.compact ? Typography.t1 : Typography.h4
                                            elide: Text.ElideRight
                                        }

                                        Rectangle {
                                            Layout.preferredWidth: statusRow.implicitWidth + 24
                                            Layout.preferredHeight: page.compact ? 26 : 30
                                            radius: Metrics.innerRadius
                                            color: page.statusBackColor(card.modelData.status)
                                            border.width: 1
                                            border.color: page.statusBorderColor(card.modelData.status)

                                            RowLayout {
                                                id: statusRow
                                                anchors.centerIn: parent
                                                spacing: 6

                                                Text {
                                                    text: page.statusGlyph(card.modelData.status)
                                                    font.family: FontSystem.getAwesomeSolid.name
                                                    font.weight: Font.Black
                                                    font.pixelSize: page.compact ? 11 : 12
                                                    color: page.statusColor(card.modelData.status)
                                                }
                                                Controls.Label {
                                                    text: card.modelData.statusText
                                                    color: page.statusColor(card.modelData.status)
                                                    font.bold: card.modelData.status === "update_available"
                                                    font.pixelSize: page.compact ? Typography.t3 : Typography.t2
                                                }
                                            }
                                        }
                                    }

                                    Controls.Label {
                                        Layout.fillWidth: true
                                        text: card.modelData.owner + " / " + card.modelData.repo
                                        color: Colors.textSecondary
                                        elide: Text.ElideRight
                                    }
                                    Controls.Label {
                                        Layout.fillWidth: true
                                        visible: !page.compact
                                        text: card.modelData.description && card.modelData.description.length > 0
                                              ? card.modelData.description
                                              : "No repository description is available."
                                        color: Colors.textSecondary
                                        wrapMode: Text.WordWrap
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            // Stats + metadata chips. A Flow lets the chips wrap
                            // to a new line inside narrow grid cards instead of
                            // overflowing/clipping.
                            Flow {
                                Layout.fillWidth: true
                                // A Flow inside a ColumnLayout doesn't report its
                                // wrapped height automatically; bind it so the card
                                // grows instead of overflowing into the next section.
                                Layout.preferredHeight: implicitHeight
                                spacing: 8

                                StatPill {
                                    glyph: ""          // star
                                    glyphColor: Colors.star
                                    value: page.formatCount(card.modelData.stars)
                                }
                                StatPill {
                                    glyph: ""          // code-branch
                                    glyphColor: Colors.secondry
                                    value: page.formatCount(card.modelData.forks)
                                }
                                MetaChip {
                                    visible: card.modelData.language && card.modelData.language.length > 0
                                    glyph: ""          // code
                                    label: card.modelData.language || ""
                                    tint: Colors.secondry
                                    back: Colors.secondryBack
                                    fg: Colors.textPrimary
                                }
                                MetaChip {
                                    visible: card.modelData.licenseSpdxId && card.modelData.licenseSpdxId.length > 0
                                    glyph: ""          // balance-scale
                                    label: card.modelData.licenseSpdxId || ""
                                }
                                // Official site (if the repo declares a homepage).
                                LinkChip {
                                    visible: card.modelData.homepageUrl && card.modelData.homepageUrl.length > 0
                                    glyph: String.fromCharCode(0xf0ac)   // globe
                                    label: "Official"
                                    onActivated: page.openUrl(String(card.modelData.homepageUrl))
                                }
                                // GitHub Releases page (always available).
                                LinkChip {
                                    glyph: String.fromCharCode(0xf02d)   // tag/releases
                                    label: "Releases"
                                    onActivated: page.openUrl(page.releasesUrlFor(card.modelData))
                                }
                            }

                            Flow {
                                Layout.fillWidth: true
                                Layout.preferredHeight: implicitHeight
                                spacing: page.compact ? 16 : 24

                                InfoField {
                                    label: card.modelData.installSource === "os" ? "Installed" : "Local"
                                    value: {
                                        if (card.modelData.installedVersion && card.modelData.installedVersion.length > 0)
                                            return card.modelData.installedVersion
                                                   + (card.modelData.installSource === "download" ? " (downloaded)" : "")
                                        if (card.modelData.status === "downloaded")
                                            return "Downloaded — ready to install"
                                        return "Not installed"
                                    }
                                }
                                InfoField { label: "Latest"; value: card.modelData.latestTag || "" }
                                InfoField {
                                    label: "Released"
                                    value: Utils.formatReleaseDate(card.modelData.latestPublishedAt, page.dateFormat)
                                }
                                InfoField { label: "Checked"; value: card.modelData.lastCheckedText || "" }
                            }

                            // Actions wrap so they reflow inside narrow grid cards.
                            Flow {
                                Layout.fillWidth: true
                                Layout.preferredHeight: implicitHeight
                                spacing: 6

                                // Primary one-click update, shown only when an update
                                // is available. Auto-picks the right OS/arch asset.
                                Controls.Button {
                                    sizeType: "small"
                                    visible: card.modelData.status === "update_available"
                                    text: "Update"
                                    style: "success"
                                    isDefault: true
                                    enabled: card.modelData.latestAssets
                                             && card.modelData.latestAssets.length > 0
                                    onClicked: page.updateApp(card.modelData)
                                }
                                Controls.Button {
                                    sizeType: "small"
                                    text: "Check now"
                                    enabled: !releaseCenterService.loading
                                    onClicked: releaseCenterService.checkApp(card.modelData.rowIndex)
                                }
                                Controls.Button {
                                    sizeType: "small"
                                    text: "Details"
                                    onClicked: page.showDetails(card.modelData)
                                }
                                Controls.Button {
                                    sizeType: "small"
                                    text: "View releases"
                                    onClicked: page.viewReleases(card.modelData)
                                }
                                Controls.Button {
                                    id: downloadAssetsBtn
                                    sizeType: "small"
                                    text: "Download assets"
                                    enabled: card.modelData.latestAssets && card.modelData.latestAssets.length > 0
                                    onClicked: page.downloadAssets(card.modelData)

                                    Controls.ToolTip {
                                        above: true
                                        active: downloadAssetsBtn.hovered && !downloadAssetsBtn.enabled
                                        text: "The latest release has no downloadable assets. " +
                                              "This project may publish binaries on its official site instead."
                                    }
                                }
                                Controls.Button {
                                    id: markInstalledBtn
                                    sizeType: "small"
                                    text: "Mark installed"
                                    // Let users record that they already have the latest version,
                                    // whether they downloaded it elsewhere or just added the repo.
                                    enabled: card.modelData.status === "update_available"
                                             || card.modelData.status === "not_installed"
                                             || card.modelData.status === "downloaded"
                                    onClicked: releaseCenterService.markLatestKnown(card.modelData.rowIndex)

                                    Controls.ToolTip {
                                        above: true
                                        active: markInstalledBtn.hovered && markInstalledBtn.enabled
                                        text: "Mark the latest release as the version you have installed."
                                    }
                                }
                                Controls.Button {
                                    sizeType: "small"
                                    text: "Remove"
                                    style: "danger"
                                    onClicked: releaseCenterService.removeApp(card.modelData.rowIndex)
                                }

                                Item { width: 8; height: 1 }

                                Controls.Switch {
                                    text: "Prereleases"
                                    checked: card.modelData.includePrereleases === true
                                    onToggled: releaseCenterService.setAppIncludePrereleases(card.modelData.rowIndex, checked)
                                }
                                Controls.Switch {
                                    text: "Auto"
                                    checked: card.modelData.autoCheckEnabled === true
                                    onToggled: releaseCenterService.setAppAutoCheckEnabled(card.modelData.rowIndex, checked)
                                }
                            }

                            Controls.Label {
                                Layout.fillWidth: true
                                visible: card.modelData.errorMessage && card.modelData.errorMessage.length > 0
                                text: card.modelData.errorMessage || ""
                                color: Colors.error
                                elide: Text.ElideRight
                            }
                        }

                        HoverHandler {
                            id: appCardHover
                        }

                        // Click anywhere on the card (outside the controls) to
                        // focus it; double-click opens the full details dialog.
                        TapHandler {
                            acceptedButtons: Qt.LeftButton
                            onTapped: page.selectedIndex = card.modelData.rowIndex
                            onDoubleTapped: page.showDetails(card.modelData)
                        }
                    }
                    }
                }
            }
        }
    }
}
