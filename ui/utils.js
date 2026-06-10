/*!
    \file        utils.js
    \brief       Provides shared JavaScript helper functions for GENYDL QML.
    \details     This file contains application-level helper logic used by Main.qml for formatting, filtering, selection, queue actions, and download workflows.

    \author      Kambiz Asadzadeh <https://github.com/thecompez>
    \copyright   Copyright (c) 2026 Genyleap. All rights reserved.
    \license     https://github.com/genyleap/genydl/blob/main/LICENSE.md
*/

function formatBytes(value) {
    var v = Number(value)
    if (!isFinite(v) || v < 0) v = 0
    const units = ["B", "KB", "MB", "GB", "TB"]
    var i = 0
    while (v >= 1024 && i < units.length - 1) {
        v /= 1024
        i += 1
    }
    const digits = v >= 100 ? 0 : (v >= 10 ? 1 : 2)
    return v.toFixed(digits) + " " + units[i]
}

function formatSpeed(value) {
    return formatBytes(value) + "/s"
}

// Compact integer formatting (1234 -> "1.2K", 39000 -> "39K").
function compactCount(value) {
    var n = Number(value || 0)
    if (!isFinite(n)) n = 0
    if (n >= 1000000) return (n / 1000000).toFixed(n >= 10000000 ? 0 : 1) + "M"
    if (n >= 1000) return (n / 1000).toFixed(n >= 10000 ? 0 : 1) + "K"
    return String(n)
}

// Format a release date according to `mode`. Accepts a Date, an ISO string, or a
// QDateTime variant. mode: "relative" | "datetime" | "day" | "month".
// Returns "" for empty input. Requires Qt to be in scope (it is in QML/JS modules).
function formatReleaseDate(value, mode) {
    if (value === undefined || value === null || value === "")
        return ""
    var d = (value instanceof Date) ? value : new Date(value)
    if (isNaN(d.getTime()))
        return String(value)

    if (mode === "datetime")
        return Qt.formatDateTime(d, "yyyy-MM-dd hh:mm")
    if (mode === "day")
        return Qt.formatDate(d, "MMM d, yyyy")        // May 28, 2026
    if (mode === "month")
        return Qt.formatDate(d, "MMM yyyy")           // Jun 2025

    // "relative" (default)
    var now = new Date()
    var secs = Math.floor((now.getTime() - d.getTime()) / 1000)
    if (secs < 0) secs = 0
    var mins = Math.floor(secs / 60)
    var hours = Math.floor(mins / 60)
    var days = Math.floor(hours / 24)
    if (secs < 45) return "just now"
    if (mins < 60) return mins + (mins === 1 ? " minute ago" : " minutes ago")
    if (hours < 24) return hours + (hours === 1 ? " hour ago" : " hours ago")
    if (days === 1) return "Yesterday"
    if (days < 7) return days + " days ago"
    if (days < 30) {
        var weeks = Math.floor(days / 7)
        return weeks + (weeks === 1 ? " week ago" : " weeks ago")
    }
    return Qt.formatDate(d, "MMM d, yyyy")
}

function formatEta(seconds) {
    var s = Number(seconds)
    if (!isFinite(s) || s < 0) return "--"
    if (s < 60) return Math.floor(s) + " sec"
    const m = Math.floor(s / 60)
    const sec = Math.floor(s % 60)
    if (m < 60) return m + " min " + sec + " sec"
    const h = Math.floor(m / 60)
    return h + " h " + (m % 60) + " min"
}

function baseName(path) {
    if (!path || path.length === 0) {
        return "Unknown file"
    }
    const slash = Math.max(path.lastIndexOf("/"), path.lastIndexOf("\\"))
    if (slash >= 0 && slash + 1 < path.length) {
        return path.substring(slash + 1)
    }
    return path
}

function applySort() {
    var roleName = "fileName"
    if (sortIndex === 1) roleName = "status"
    else if (sortIndex === 2) roleName = "bytesReceived"
    else if (sortIndex === 3) roleName = "bytesTotal"
    else if (sortIndex === 4) roleName = "queueName"
    else if (sortIndex === 5) roleName = "category"
    downloadManager.model.sortBy(roleName, sortAscending)
}

function statusPasses(status) {
    if (statusFilter === "All") return true
    if (statusFilter === "Unfinished") {
        return status !== "Done" && status !== "Canceled" && status !== "Error"
    }
    if (statusFilter === "History") {
        return status === "Done" || status === "Canceled" || status === "Error"
    }
    return status === statusFilter
}

function rowAccepted(queueName, status, categoryName, fileName, urlText, taskObj) {
    if (queueFilter !== "All Queues" && queueName !== queueFilter) return false
    if (!statusPasses(status)) return false
    if (categoryFilter !== "All" && categoryName !== categoryFilter) return false
    if (sourceFilter !== "All" && !sourceMatchesFilter(taskObj, sourceFilter)) return false

    const needle = searchText.trim().toLowerCase()
    if (needle.length === 0) return true

    const file = (fileName || "").toLowerCase()
    const url = (urlText || "").toLowerCase()
    return file.indexOf(needle) >= 0 || url.indexOf(needle) >= 0
}

function setStatusScope(scope) {
    queueFilter = "All Queues"
    categoryFilter = "All"
    sourceFilter = "All"
    statusFilter = scope
    clearCheckedTasks()
    if (selectedTask && downloadManager.indexOfTask(selectedTask) >= 0) {
        const row = downloadManager.indexOfTask(selectedTask)
        if (!rowAccepted(downloadManager.taskQueueName(row), selectedTask.stateString, downloadManager.taskCategoryName(row), selectedTask.fileName(), selectedTask.url(), selectedTask)) {
            clearSelection()
        }
    }
}

function setCategoryScope(scope) {
    queueFilter = "All Queues"
    statusFilter = "All"
    sourceFilter = "All"
    categoryFilter = scope
    clearCheckedTasks()
    if (selectedTask && downloadManager.indexOfTask(selectedTask) >= 0) {
        const row = downloadManager.indexOfTask(selectedTask)
        if (!rowAccepted(downloadManager.taskQueueName(row), selectedTask.stateString, downloadManager.taskCategoryName(row), selectedTask.fileName(), selectedTask.url(), selectedTask)) {
            clearSelection()
        }
    }
}

// Filter the list to a single source family (Direct / Torrent / Blockchain /
// IPFS / Arweave). Resets the other filter dimensions like the sibling scopes.
function setSourceScope(scope) {
    queueFilter = "All Queues"
    statusFilter = "All"
    categoryFilter = "All"
    sourceFilter = scope && scope.length > 0 ? scope : "All"
    clearCheckedTasks()
    if (selectedTask && downloadManager.indexOfTask(selectedTask) >= 0) {
        const row = downloadManager.indexOfTask(selectedTask)
        if (!rowAccepted(downloadManager.taskQueueName(row), selectedTask.stateString, downloadManager.taskCategoryName(row), selectedTask.fileName(), selectedTask.url(), selectedTask)) {
            clearSelection()
        }
    }
}

function setQueueScope(scope) {
    queueFilter = scope && scope.length > 0 ? scope : "All Queues"
    statusFilter = "All"
    categoryFilter = "All"
    sourceFilter = "All"
    clearCheckedTasks()
    if (selectedTask && downloadManager.indexOfTask(selectedTask) >= 0) {
        const row = downloadManager.indexOfTask(selectedTask)
        if (!rowAccepted(downloadManager.taskQueueName(row), selectedTask.stateString, downloadManager.taskCategoryName(row), selectedTask.fileName(), selectedTask.url())) {
            clearSelection()
        }
    }
}

function visibleTaskRows() {
    var visible = []
    for (var i = 0; i < downloadManager.taskCount(); ++i) {
        var taskObj = downloadManager.taskObjectAt(i)
        if (!taskObj)
            continue
        if (!rowAccepted(downloadManager.taskQueueName(i),
                         taskObj.stateString,
                         downloadManager.taskCategoryName(i),
                         taskObj.fileName(),
                         taskObj.url())) {
            continue
        }
        visible.push(i)
    }
    return visible
}

function visibleTaskCount() {
    return visibleTaskRows().length
}

function areAllVisibleChecked() {
    var visible = visibleTaskRows()
    var checked = sanitizedCheckedTaskRows()
    if (visible.length === 0)
        return false
    for (var i = 0; i < visible.length; ++i) {
        if (checked.indexOf(visible[i]) < 0)
            return false
    }
    return true
}

function syncSelectAllCheckBox(box) {
    if (!box)
        return
    box.checked = areAllVisibleChecked()
}

function clearSelection() {
    selectedTaskIndex = -1
    selectedTask = null
    selectedQueue = ""
    selectedCategory = ""
}

function selectTask(row, taskObj, queueName, categoryName) {
    selectedTaskIndex = row
    selectedTask = row >= 0 ? downloadManager.taskObjectAt(row) : taskObj
    selectedQueue = queueName
    selectedCategory = categoryName
}

function selectedState() {
    var taskObj = selectedTaskIndex >= 0 ? downloadManager.taskObjectAt(selectedTaskIndex) : selectedTask
    return taskObj ? taskObj.stateString : ""
}

function sanitizedCheckedTaskRows() {
    var kept = []
    for (var i = 0; i < checkedTaskRows.length; ++i) {
        var row = Number(checkedTaskRows[i])
        if (row >= 0 && row < downloadManager.taskCount() && kept.indexOf(row) < 0)
            kept.push(row)
    }
    return kept
}

function sanitizeCheckedTaskRows() {
    checkedTaskRows = sanitizedCheckedTaskRows()
}

function isRowChecked(row) {
    if (row < 0)
        return false
    return sanitizedCheckedTaskRows().indexOf(row) >= 0
}

function isTaskChecked(taskObj) {
    if (!taskObj)
        return false
    return isRowChecked(downloadManager.indexOfTask(taskObj))
}

function setRowChecked(row, checked) {
    row = Number(row)
    if (row < 0)
        return
    var rows = sanitizedCheckedTaskRows()
    var idx = rows.indexOf(row)
    if (checked && idx < 0)
        rows.push(row)
    else if (!checked && idx >= 0)
        rows.splice(idx, 1)
    checkedTaskRows = rows
}

function setTaskChecked(taskObj, checked) {
    if (!taskObj)
        return
    setRowChecked(downloadManager.indexOfTask(taskObj), checked)
}

function clearCheckedTasks() {
    checkedTaskRows = []
}

function checkedTaskCount() {
    return sanitizedCheckedTaskRows().length
}

function actionTargetRows() {
    var rows = sanitizedCheckedTaskRows()
    if (rows.length === 0 && hasSelection && selectedTaskIndex >= 0)
        rows.push(selectedTaskIndex)
    return rows
}

function actionTargets() {
    var rows = actionTargetRows()
    var targets = []
    for (var i = 0; i < rows.length; ++i) {
        var taskObj = downloadManager.taskObjectAt(rows[i])
        if (taskObj)
            targets.push(taskObj)
    }
    return targets
}

function canResumeAction() {
    var rows = actionTargetRows()
    if (rows.length === 0)
        return false
    var hasResumable = false
    for (var i = 0; i < rows.length; ++i) {
        var t = downloadManager.taskObjectAt(rows[i])
        if (!t)
            continue
        var state = t.stateString
        if (state === "Active")
            return false
        if (state === "Paused" || state === "Error")
            hasResumable = true
    }
    return hasResumable
}

function canStopAction() {
    var rows = actionTargetRows()
    if (rows.length === 0)
        return false
    for (var i = 0; i < rows.length; ++i) {
        var t = downloadManager.taskObjectAt(rows[i])
        if (t && t.stateString === "Active")
            return true
    }
    return false
}

function canStopAllAction() {
    return canStopAction()
}

function applyActionToCheckedOrSelected(action) {
    var rows = actionTargetRows()
    if (rows.length === 0)
        return

    if (action === "remove") {
        promptRemoveRows(rows)
        return
    }

    for (var i = 0; i < rows.length; ++i) {
        var rowIdx = rows[i]
        var taskObj = downloadManager.taskObjectAt(rowIdx)
        if (!taskObj)
            continue
        executeRowAction(rowIdx,
                         taskObj,
                         action,
                         "",
                         "")
    }
}

function openToolbarItemMenu(sourceButton) {
    var rows = actionTargetRows()
    if (rows.length === 0)
        return
    var rowIdx = rows[0]
    var taskObj = downloadManager.taskObjectAt(rowIdx)
    if (!taskObj)
        return
    var p = sourceButton.mapToItem(null, 0, sourceButton.height + 4)
    toolbarItemMenu.targetRow = rowIdx
    toolbarItemMenu.targetTask = taskObj
    toolbarItemMenu.targetQueue = downloadManager.taskQueueName(rowIdx)
    toolbarItemMenu.targetCategory = downloadManager.taskCategoryName(rowIdx)
    toolbarItemMenu.x = p.x
    toolbarItemMenu.y = p.y
    toolbarItemMenu.open()
}

function openPropertiesForSelection() {
    var rows = actionTargetRows()
    if (rows.length === 0)
        return
    var rowIdx = rows[0]
    var taskObj = downloadManager.taskObjectAt(rowIdx)
    if (!taskObj)
        return
    openDetailsFor(rowIdx,
                   taskObj,
                   downloadManager.taskQueueName(rowIdx),
                   downloadManager.taskCategoryName(rowIdx))
}

function shareSelectedTargets() {
    var rows = actionTargetRows()
    if (rows.length === 0)
        return
    var urls = []
    for (var i = 0; i < rows.length; ++i) {
        var t = downloadManager.taskObjectAt(rows[i])
        if (!t)
            continue
        var u = String(t.url ? t.url() : "").trim()
        if (u.length > 0)
            urls.push(u)
    }
    if (urls.length === 0)
        return
    downloadManager.copyText(urls.join("\n"))
    var body = encodeURIComponent(urls.join("\n"))
    Qt.openUrlExternally("mailto:?subject=GENYDL%20Downloads&body=" + body)
    downloadManager.showToast("Share links copied", "info")
}

function resolveTaskRow(row, taskObj) {
    if (taskObj) {
        const resolved = downloadManager.indexOfTask(taskObj)
        if (resolved >= 0)
            return resolved
    }
    return row >= 0 ? row : -1
}

function taskStatusText(taskObj, fallbackStatus) {
    const state = taskObj ? taskObj.stateString : fallbackStatus
    if (!taskObj || state !== "Paused")
        return state || ""
    const reason = taskObj.pauseReason ? String(taskObj.pauseReason) : ""
    if (reason.length === 0 || reason === "User")
        return state
    return state + " (" + reason + ")"
}

function taskFileNameValue(taskObj) {
    if (!taskObj)
        return ""
    if (typeof taskObj.fileName === "function")
        return String(taskObj.fileName())
    if (taskObj.fileName !== undefined && taskObj.fileName !== null)
        return String(taskObj.fileName)
    return ""
}

function setCategoryPreset(preset) {
    if (preset === "all") {
        setStatusScope("All")
        return
    }
    if (preset === "unfinished") {
        setStatusScope("Unfinished")
        return
    }
    if (preset === "finished") {
        setStatusScope("History")
        return
    }
    if (preset === "active") {
        setStatusScope("Active")
        return
    }
    if (preset === "queued") {
        setStatusScope("Queued")
        return
    }
    if (preset === "errors") {
        setStatusScope("Error")
    }
}

function openDetailsFor(row, taskObj, queueName, categoryName) {
    const resolvedRow = resolveTaskRow(row, taskObj)
    if (!taskObj || resolvedRow < 0) return
    selectTask(resolvedRow, taskObj, queueName, categoryName)

    // Torrents have a dedicated details window (swarm stats + file picker).
    if (taskObj.isTorrent) {
        torrentDetailsWindow.row = resolvedRow
        torrentDetailsWindow.task = taskObj
        torrentDetailsWindow.queueName = queueName
        torrentDetailsWindow.categoryName = categoryName
        torrentDetailsWindow.refreshFromRow()
        torrentDetailsWindow.show()
        torrentDetailsWindow.raise()
        torrentDetailsWindow.requestActivate()
        return
    }

    detailsRow = resolvedRow
    detailsTask = taskObj
    detailsQueue = queueName
    detailsCategory = categoryName
    detailsWindow.tabIndex = 0
    resetDetailsSamples()
    refreshDetailsSnapshot()
    detailsWindow.show()
    detailsWindow.raise()
    detailsWindow.requestActivate()
}

function openConfigurationDialog(tabIndex) {
    configurationTabIndex = Math.max(0, Math.min(4, Number(tabIndex)))
    if (!queueEditorName || queueEditorName.length === 0) {
        if (downloadManager.queueNames.length > 0)
            queueEditorName = downloadManager.queueNames[0]
        loadQueueEditor()
    }
    configurationDialog.open()
}

function promptRemoveRows(rows) {
    var uniqueRows = []
    for (var i = 0; i < rows.length; ++i) {
        var row = Number(rows[i])
        if (row < 0 || uniqueRows.indexOf(row) >= 0)
            continue
        uniqueRows.push(row)
    }
    if (uniqueRows.length === 0)
        return
    uniqueRows.sort(function(a, b) { return b - a })
    pendingRemoveRows = uniqueRows
    removeFromDiskCheck.checked = false
    Qt.callLater(function() {
        if (appRoot.pendingRemoveRows.length > 0)
            removeDownloadPopup.open()
    })
}

function confirmRemovePending(deleteFromDisk) {
    if (pendingRemoveRows.length === 0)
        return
    const shouldDeleteFromDisk = (deleteFromDisk === undefined) ? removeFromDiskCheck.checked : !!deleteFromDisk
    for (var i = 0; i < pendingRemoveRows.length; ++i) {
        downloadManager.removeDownloadWithOptions(pendingRemoveRows[i], shouldDeleteFromDisk)
    }
    pendingRemoveRows = []
    clearCheckedTasks()
    clearSelection()
    detailsWindow.close()
    removeDownloadPopup.close()
}

function executeRowAction(row, taskObj, action, queueName, categoryName) {
    const resolvedRow = resolveTaskRow(row, taskObj)
    if (resolvedRow < 0)
        return
    const resolvedTask = taskObj ? taskObj : downloadManager.taskObjectAt(resolvedRow)
    if (!resolvedTask)
        return

    if (action === "resume") {
        downloadManager.resumeTask(resolvedRow)
        return
    }
    if (action === "pause" || action === "stop") {
        downloadManager.pauseTask(resolvedRow)
        return
    }
    if (action === "retry") {
        downloadManager.retryTask(resolvedRow)
        return
    }
    if (action === "cancel") {
        resolvedTask.cancel()
        return
    }
    if (action === "open") {
        downloadManager.openFile(resolvedRow)
        return
    }
    if (action === "reveal") {
        downloadManager.revealInFolder(resolvedRow)
        return
    }
    if (action === "copy_url") {
        downloadManager.copyText(resolvedTask.url())
        return
    }
    if (action === "copy_path") {
        downloadManager.copyText(resolvedTask.fileName())
        return
    }
    if (action === "verify") {
        downloadManager.verifyTask(resolvedRow)
        return
    }
    if (action === "properties") {
        openDetailsFor(resolvedRow, taskObj, queueName, categoryName)
        return
    }
    if (action === "remove") {
        promptRemoveRows([resolvedRow])
    }
}

function submitDownload(url, output, queueName, categoryName, startPaused, segments, adaptive, digest) {
    const safeUrl = (url || "").trim()
    const safeOutput = (output || "").trim()
    if (safeUrl.length === 0 || safeOutput.length === 0) {
        return false
    }

    const options = {
        "segments": Number(segments),
        "adaptiveSegments": !!adaptive
    }

    // GitHub asset integrity digest ("sha256:<hex>") → verify the file on
    // completion using the download engine's built-in checksum support.
    const rawDigest = (digest || "").trim()
    if (rawDigest.indexOf(":") > 0) {
        const parts = rawDigest.split(":")
        options["checksumAlgo"] = parts[0].toLowerCase()
        options["checksumExpected"] = parts[1]
        options["verifyOnComplete"] = true
    }

    downloadManager.addDownloadAdvancedWithExtras(
                safeUrl,
                safeOutput,
                queueName && queueName.length > 0 ? queueName : "General",
                categoryName && categoryName.length > 0 ? categoryName : "Auto",
                !!startPaused,
                options
                )
    return true
}

function downloadPathForAsset(output, fileName) {
    const safeName = (fileName || "").trim()
    const rawBase = (output || documentsFolder || "").trim()
    const base = rawBase.startsWith("file://") ? decodeURIComponent(rawBase.slice(7)) : rawBase
    if (safeName.length === 0 || base.length === 0) {
        return base
    }
    if (base.endsWith("/") || base.endsWith("\\")) {
        return base + safeName
    }
    return base + "/" + safeName
}

function submitGitHubReleaseAssets(assets, output, queueName, categoryName, startPaused, segments, adaptive) {
    if (!assets || assets.length === 0) {
        return 0
    }

    var added = 0
    for (var i = 0; i < assets.length; ++i) {
        const asset = assets[i]
        const url = asset && asset.downloadUrl !== undefined ? String(asset.downloadUrl) : ""
        const name = asset && asset.name !== undefined ? String(asset.name) : ""
        const digest = asset && asset.digest !== undefined ? String(asset.digest) : ""
        if (url.length === 0 || name.length === 0) {
            continue
        }

        if (submitDownload(url,
                           downloadPathForAsset(output, name),
                           queueName,
                           categoryName,
                           startPaused,
                           segments,
                           adaptive,
                           digest)) {
            ++added
        }
    }
    return added
}

function rebuildDownloadTableRows() {
    var rows = []
    const count = downloadManager.taskCount()
    for (var i = 0; i < count; ++i) {
        var taskObj = downloadManager.taskObjectAt(i)
        if (!taskObj)
            continue
        var q = downloadManager.taskQueueName(i)
        var c = downloadManager.taskCategoryName(i)
        var s = String(taskObj.stateString || "")
        var f = String(taskObj.fileName ? taskObj.fileName() : "")
        var u = String(taskObj.url ? taskObj.url() : "")
        if (!rowAccepted(q, s, c, f, u))
            continue

        var received = Math.max(0, Number(downloadManager.taskBytesReceived(i)))
        var total = Math.max(0, Number(downloadManager.taskBytesTotal(i)))
        var ratio = s === "Done" ? 1.0 : (total > 0 ? Math.min(1.0, received / total) : 0.0)
        var isTorrent = !!taskObj.isTorrent
        // Torrents have no HTTP segments; show seed/peer counts instead.
        var segText = isTorrent
                ? (String(taskObj.seeders) + "S/" + String(taskObj.leechers) + "P")
                : (String(taskObj.effectiveSegments()) + "/" + String(taskObj.segments()))
        rows.push({
                      rowIndex: i,
                      checked: isRowChecked(i),
                      fileName: baseName(f),
                      fullPath: f,
                      url: u,
                      queueName: q,
                      isTorrent: isTorrent,
                      bytesReceived: received,
                      bytesTotal: total,
                      rawStatus: s,
                      sizeText: formatBytes(received) + (total > 0 ? " / " + formatBytes(total) : ""),
                      statusText: taskStatusText(taskObj, s),
                      etaText: formatEta(taskObj.eta),
                      speedText: formatSpeed(taskObj.speed),
                      segText: segText,
                      categoryText: c,
                      progress: ratio
                  })
    }
    tableRows = rows
}

function scheduleRebuildDownloadTableRows() {
    rebuildTableTimer.stop()
    rebuildTableTimer.start()
}

function addDownloadFromInputs() {
    openAddUrlDialog()
}

function openAddUrlDialog() {
    const queueList = downloadManager.queueNames
    const categoryList = downloadManager.categoryNames()
    const defaultPath = appRoot.addDefaultOutputPath.trim().length > 0 ? appRoot.addDefaultOutputPath : documentsFolder
    const clip = (downloadManager.clipboardText() || "").trim()

    addDialogErrorLabel.text = ""
    addDialogUrlField.text = ""
    if (clip.length > 0) {
        const lines = clip.split(/\r?\n/)
        for (let i = 0; i < lines.length; ++i) {
            const candidate = lines[i].trim()
            if (!candidate.length)
                continue
            if (candidate.startsWith("http://")
                    || candidate.startsWith("https://")
                    || candidate.startsWith("ftp://")
                    || candidate.startsWith("magnet:")
                    || candidate.startsWith("file://")
                    || candidate.endsWith(".torrent")) {
                addDialogUrlField.text = candidate
                break
            }
        }
    }
    addDialogPathField.text = defaultPath
    addDialogQueueCombo.currentIndex = queueList.length > 0 ? Math.max(0, queueList.indexOf(appRoot.addDefaultQueue)) : -1
    addDialogCategoryCombo.currentIndex = categoryList.length > 0 ? Math.max(0, categoryList.indexOf(appRoot.addDefaultCategory)) : -1
    addDialogSegmentsSpin.value = appRoot.addDefaultSegments
    addDialogAdaptiveSwitch.checked = appRoot.addDefaultAdaptive
    addDialogPausedSwitch.checked = appRoot.addDefaultStartPaused
    addUrlPopup.open()
    addDialogUrlField.forceActiveFocus()
}

function isTorrentLikeInput(value) {
    const text = (value || "").trim().toLowerCase()
    return text.endsWith(".torrent") || text.startsWith("magnet:")
}

function loadQueueEditor() {
    if (!queueEditorName || queueEditorName.length === 0) {
        return
    }
    queueConcurrentSpin.value = downloadManager.queueMaxConcurrent(queueEditorName)
    queueSpeedSpin.value = Math.round(downloadManager.queueMaxSpeed(queueEditorName) / (1024 * 1024))
    queueScheduleSwitch.checked = downloadManager.queueScheduleEnabled(queueEditorName)
    queueStartTimeField.text = appRoot.minutesToClockText(downloadManager.queueScheduleStartMinutes(queueEditorName))
    queueEndTimeField.text = appRoot.minutesToClockText(downloadManager.queueScheduleEndMinutes(queueEditorName))
    queueQuotaSwitch.checked = downloadManager.queueQuotaEnabled(queueEditorName)
    queueQuotaSpin.value = Math.round(downloadManager.queueQuotaBytes(queueEditorName) / (1024 * 1024 * 1024))
    queuePostActionCombo.currentIndex = appRoot.queuePostActionIndex(downloadManager.queuePostCompletionAction(queueEditorName))
}

function applyQueueEditor() {
    if (!queueEditorName || queueEditorName.length === 0) {
        return
    }
    downloadManager.setQueueMaxConcurrent(queueEditorName, queueConcurrentSpin.value)
    downloadManager.setQueueMaxSpeed(queueEditorName, queueSpeedSpin.value * 1024 * 1024)
    downloadManager.setQueueScheduleEnabled(queueEditorName, queueScheduleSwitch.checked)
    downloadManager.setQueueScheduleStartMinutes(queueEditorName, appRoot.clockTextToMinutes(queueStartTimeField.text, downloadManager.queueScheduleStartMinutes(queueEditorName)))
    downloadManager.setQueueScheduleEndMinutes(queueEditorName, appRoot.clockTextToMinutes(queueEndTimeField.text, downloadManager.queueScheduleEndMinutes(queueEditorName)))
    downloadManager.setQueueQuotaEnabled(queueEditorName, queueQuotaSwitch.checked)
    downloadManager.setQueueQuotaBytes(queueEditorName, queueQuotaSpin.value * 1024 * 1024 * 1024)
    downloadManager.setQueuePostCompletionAction(queueEditorName, appRoot.queuePostActionIds[Math.max(0, queuePostActionCombo.currentIndex)])
}

function createQueueFromEditor(name) {
    const trimmed = (name || "").trim()
    if (trimmed.length === 0)
        return false
    if (downloadManager.queueNames.indexOf(trimmed) >= 0)
        return false
    downloadManager.createQueue(trimmed)
    queueEditorName = trimmed
    addDefaultQueue = trimmed
    selectedQueue = trimmed
    queueFilter = trimmed
    loadQueueEditor()
    return true
}

function renameCurrentQueueTo(name) {
    const trimmed = (name || "").trim()
    const previous = queueEditorName
    if (previous.length === 0 || trimmed.length === 0 || previous === trimmed)
        return false
    if (downloadManager.queueNames.indexOf(trimmed) >= 0)
        return false
    downloadManager.renameQueue(previous, trimmed)
    if (queueFilter === previous)
        queueFilter = trimmed
    if (addDefaultQueue === previous)
        addDefaultQueue = trimmed
    if (selectedQueue === previous)
        selectedQueue = trimmed
    queueEditorName = trimmed
    loadQueueEditor()
    return true
}

function removeCurrentQueue() {
    const target = queueEditorName
    if (!target || target.length === 0 || target === downloadManager.defaultQueueName())
        return false
    const fallback = downloadManager.defaultQueueName()
    downloadManager.removeQueue(target)
    if (queueFilter === target)
        queueFilter = "All Queues"
    if (addDefaultQueue === target)
        addDefaultQueue = fallback
    if (selectedQueue === target)
        selectedQueue = fallback
    queueEditorName = fallback
    loadQueueEditor()
    return true
}

function refreshDetailsSnapshot() {
    if (detailsRow >= 0) {
        detailsBytesReceived = Math.max(0, downloadManager.taskBytesReceived(detailsRow))
        detailsBytesTotal = Math.max(0, downloadManager.taskBytesTotal(detailsRow))
    } else {
        detailsBytesReceived = 0
        detailsBytesTotal = 0
    }
    detailsRevision += 1
}

function resetDetailsSamples() {
    detailsSpeedSamples = []
    detailsPeakSpeed = 1
}

function pushDetailsSpeedSample(v) {
    var arr = detailsSpeedSamples.slice(0)
    var sample = Number(v)
    if (!isFinite(sample) || sample < 0) {
        sample = 0
    }
    arr.push(sample)
    while (arr.length > 120) {
        arr.shift()
    }
    detailsSpeedSamples = arr

    if (arr.length > 0) {
        detailsPeakSpeed = Math.max(1, Math.max.apply(Math, arr))
    } else {
        detailsPeakSpeed = 1
    }
}

// ---------------------------------------------------------------------------
// Source type & verification classification
//
// Shared by the download list (DownloadDelegate) and the details dialog so the
// protocol/verification surface is consistent everywhere. These return semantic
// tokens only ({ tone: "success" | "warning" | "danger" | "accent" | "info" |
// "secondary" | "muted" }); QML resolves tokens to theme colors via toneColor().
// ---------------------------------------------------------------------------

// Classify a download task by where its content comes from.
// Returns { id, label, short, tone, glyph }.
//   id    : stable identifier ("http" | "torrent" | "ipfs" | "arweave" | "storage")
//   label : full human label for details/tooltips
//   short : compact badge text for the list
//   tone  : color token
//   glyph : Font Awesome code point (solid) for the protocol icon
function sourceTypeInfo(task) {
    if (!task) {
        return { id: "http", label: "Direct Download (HTTP/HTTPS)", short: "HTTP",
                 tone: "secondary", glyph: "" } // globe
    }
    if (task.isTorrent) {
        return { id: "torrent", label: "Torrent (BitTorrent)", short: "Torrent",
                 tone: "accent", glyph: "" } // sitemap / swarm
    }
    var net = task.storageNetwork ? String(task.storageNetwork) : ""
    if (net.length > 0) {
        var up = net.toUpperCase()
        if (up === "IPFS") {
            return { id: "ipfs", label: "Blockchain Storage (IPFS)", short: "IPFS",
                     tone: "info", glyph: "" } // cloud / distributed
        }
        if (up === "ARWEAVE") {
            return { id: "arweave", label: "Permanent Storage (Arweave)", short: "Arweave",
                     tone: "info", glyph: "" } // archive
        }
        return { id: "storage", label: "Blockchain Storage (" + net + ")", short: net,
                 tone: "info", glyph: "" }
    }
    return { id: "http", label: "Direct Download (HTTP/HTTPS)", short: "HTTP",
             tone: "secondary", glyph: "" }
}

// Whether a task matches a source-type filter token. Mirrors the C++
// DownloadModel::filteredCount sourcePasses() classification.
//   filter: "All" | "Direct" | "Torrent" | "Blockchain" | "IPFS" | "Arweave"
function sourceMatchesFilter(task, filter) {
    if (!filter || filter === "All") return true
    var id = sourceTypeInfo(task).id
    switch (filter) {
        case "Direct":     return id === "http"
        case "Torrent":    return id === "torrent"
        case "IPFS":       return id === "ipfs"
        case "Arweave":    return id === "arweave"
        case "Blockchain": return id === "ipfs" || id === "arweave" || id === "storage"
        default:           return true
    }
}

// "Downloaded Via" phrasing for a task's transport.
function deliveryChannel(task) {
    var info = sourceTypeInfo(task)
    if (info.id === "ipfs") return "IPFS Gateway Network"
    if (info.id === "arweave") return "Arweave Gateway"
    if (info.id === "torrent") return "BitTorrent Swarm"
    return "Direct HTTP Transfer"
}

// Verification descriptor for a task.
// Returns { state, label, tone, verified }.
//   state : "verified" | "mismatch" | "verifying" | "trusted" | "none"
function verificationInfo(task) {
    if (!task) return { state: "none", label: "", tone: "muted", verified: false }
    var cs = task.checksumState ? String(task.checksumState) : ""
    var contentAddressed = (task.contentId && String(task.contentId).length > 0)
    if (cs === "OK") {
        return { state: "verified",
                 label: contentAddressed ? "CID Match" : "Verified",
                 tone: "success", verified: true }
    }
    if (cs === "Mismatch" || cs === "Failed") {
        return { state: "mismatch", label: "Verification Failed", tone: "danger", verified: false }
    }
    if (cs === "Verifying") {
        return { state: "verifying", label: "Verifying…", tone: "accent", verified: false }
    }
    if (contentAddressed) {
        // Content-addressed but not byte-verifiable (e.g. UnixFS DAG): we do not
        // fake a green check; delivery is trusted to the gateway.
        return { state: "trusted", label: "Gateway-trusted", tone: "warning", verified: false }
    }
    return { state: "none", label: "", tone: "muted", verified: false }
}

// Extract the host from a full gateway URL.
function gatewayHostFromUrl(u) {
    if (!u) return ""
    var s = String(u)
    var m = s.match(/^[a-zA-Z][a-zA-Z0-9+.-]*:\/\/([^\/]+)/)
    return m ? m[1] : s
}

// The gateway that actually served (or is serving) an IPFS task, as a host.
// Derived from the task's current mirror selection.
function activeGatewayHost(task) {
    if (!task || !task.mirrorUrls) return ""
    var urls = task.mirrorUrls
    if (!urls || urls.length === 0) return ""
    var idx = task.mirrorIndex || 0
    if (idx < 0 || idx >= urls.length) idx = 0
    var host = gatewayHostFromUrl(urls[idx])
    return host === "127.0.0.1:8080" ? "Local node (127.0.0.1)" : host
}

// Number of fallback gateways still available behind the active one.
function gatewayFallbackCount(task) {
    if (!task || !task.mirrorUrls) return 0
    var urls = task.mirrorUrls
    if (!urls) return 0
    var idx = task.mirrorIndex || 0
    return Math.max(0, urls.length - 1 - idx)
}
