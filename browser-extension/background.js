/* GenyDL Browser Integration v2.
 * User-controlled: Manual by default; Ask and Always require opt-in.
 * Each request has an isolated native Port to keep MV3 workers alive while
 * the desktop user reviews the Add Download dialog.
 */
const EXT = globalThis.browser ?? globalThis.chrome;
const HOST = "com.genyleap.genydl";
const MENU_ID = "genydl-download";
const FILE_EXTENSION = /\.(?:7z|apk|appimage|bz2|csv|deb|dmg|docx?|epub|exe|flac|gz|iso|m4a|mkv|mov|mp3|mp4|msi|pdf|pkg|pptx?|rar|rpm|tar|tgz|torrent|wav|webm|xlsx?|xz|zip)$/i;
const activeDownloads = new Set();
const PROTOCOL_VERSION = 2;

function validatedUrl(raw) {
  try {
    const url = new URL(raw);
    if (!["https:", "http:"].includes(url.protocol) || url.username || url.password)
      return null;
    if (url.hostname === "localhost" || url.hostname.endsWith(".localhost")) return null;
    return url;
  } catch { return null; }
}

function hostnameExcluded(host, rules) {
  return (rules || []).some(rule => {
    const suffix = String(rule).trim().toLowerCase().replace(/^\*\./, "");
    return suffix && (host === suffix || host.endsWith("." + suffix));
  });
}

function filenameHint(item) {
  const supplied = String(item.filename || "").replace(/\\/g, "/").split("/").pop().trim();
  if (supplied && FILE_EXTENSION.test(supplied)) return supplied;
  const original = validatedUrl(item.url);
  if (original) {
    let name = original.pathname.split("/").pop() || "";
    try { name = decodeURIComponent(name); } catch { /* retain encoded form */ }
    if (FILE_EXTENSION.test(name)) return name;
  }
  return supplied;
}

function newRequestId() {
  if (globalThis.crypto?.randomUUID) return globalThis.crypto.randomUUID();
  // The fallback still distinguishes simultaneous downloads; the native
  // bridge never relies on request IDs for authorization.
  return String(Date.now()) + "-" + Math.random().toString(36).slice(2);
}

function nativeHandoff(url, filename, type, browserCode = "") {
  return new Promise((resolve, reject) => {
    let port;
    try { port = EXT.runtime.connectNative(HOST); }
    catch (error) { reject(error); return; }

    let settled = false;
    const requestId = newRequestId();
    const timeout = setTimeout(() => finish(new Error("GenyDL response timed out")), 160000);
    function finish(error, message) {
      if (settled) return;
      settled = true;
      clearTimeout(timeout);
      try { port.disconnect(); } catch { /* already disconnected */ }
      if (error) reject(error);
      else resolve(message);
    }
    port.onMessage.addListener(reply => {
      if (reply?.requestId && reply.requestId !== requestId) {
        finish(new Error("Mismatched GenyDL request ID"));
        return;
      }
      finish(null, reply);
    });
    port.onDisconnect.addListener(() => {
      const message = EXT.runtime.lastError?.message || "GenyDL native host disconnected";
      finish(new Error(message));
    });
    try {
      port.postMessage({
        protocolVersion: PROTOCOL_VERSION, requestId, type,
        ...(url ? {url} : {}), ...(filename ? {filename} : {}),
        ...(browserCode ? {browser: browserCode} : {})
      });
    } catch (error) { finish(error); }
  });
}

function downloadAction(method, argument) {
  if (typeof globalThis.browser !== "undefined")
    return globalThis.browser.downloads[method](argument);
  return new Promise((resolve, reject) =>
    EXT.downloads[method](argument, value => {
      const error = EXT.runtime.lastError;
      if (error) reject(new Error(error.message));
      else resolve(value);
    }));
}

async function resumeIfPossible(id) {
  try { await downloadAction("resume", id); }
  catch (error) {
    console.warn("GenyDL could not resume browser download", String(error));
  }
}

function normalizedMode(value) {
  // Earlier releases defaulted to automatic capture. Do not silently carry
  // that behavior forward after introducing a user-controlled Manual default.
  if (["smart", "all", "automatic"].includes(value)) return "manual";
  if (value === "ask") return "ask";
  return ["manual", "always", "off"].includes(value) ? value : "manual";
}

async function readSettings() {
  const defaults = {mode: "manual", captureScope: "recognized", excludedHosts: []};
  const stored = typeof globalThis.browser !== "undefined"
    ? await globalThis.browser.storage.local.get(defaults)
    : await new Promise(resolve => EXT.storage.local.get(defaults, resolve));
  return {...defaults, ...stored, mode: normalizedMode(stored.mode)};
}

function supportedDownload(item, url, scope) {
  if (scope === "all") return true;
  const original = validatedUrl(item.url);
  const mime = String(item.mime || "").toLowerCase();
  return FILE_EXTENSION.test(url.pathname)
    || (original && FILE_EXTENSION.test(original.pathname))
    || FILE_EXTENSION.test(filenameHint(item))
    || ["application/octet-stream", "application/zip",
        "application/x-zip-compressed"].includes(mime);
}

async function capture(item) {
  if (!item || activeDownloads.has(item.id) || item.state === "complete") return;
  const url = validatedUrl(item.finalUrl || item.url);
  if (!url) return;
  const config = await readSettings();
  if (config.mode === "manual" || config.mode === "off") return;
  if (hostnameExcluded(url.hostname.toLowerCase(), config.excludedHosts)) return;
  if (!supportedDownload(item, url, config.captureScope)) return;

  activeDownloads.add(item.id);
  let paused = false;
  let cancelled = false;
  try {
    await downloadAction("pause", item.id);
    paused = true;
    const response = await nativeHandoff(url.href, filenameHint(item),
      config.mode === "always" ? "download.request" : "download.prompt");
    if (response?.ok !== true) return;

    await downloadAction("cancel", item.id);
    cancelled = true;
    paused = false;
    // This is optional UI cleanup. It must never affect the accepted transfer.
    try { await downloadAction("erase", {id: item.id}); }
    catch (error) { console.debug("GenyDL could not clear download history", String(error)); }
  } catch (error) {
    console.warn("GenyDL handoff failed; keeping browser download", String(error));
  } finally {
    if (paused && !cancelled) await resumeIfPossible(item.id);
    activeDownloads.delete(item.id);
  }
}

async function offerContextLink(info) {
  if (info.menuItemId !== MENU_ID) return;
  if ((await readSettings()).mode === "off") return;
  const url = validatedUrl(info.linkUrl || info.srcUrl);
  if (!url) return;
  try { await nativeHandoff(url.href, "", "download.prompt"); }
  catch (error) { console.warn("GenyDL is unavailable", String(error)); }
}

if (EXT.downloads?.onCreated)
  EXT.downloads.onCreated.addListener(item => { capture(item).catch(console.warn); });

function registerMenu() {
  if (!EXT.contextMenus?.create) return;
  const create = () => EXT.contextMenus.create({
    id: MENU_ID, title: "Download with GenyDL", contexts: ["link", "image", "video", "audio"]
  }, () => { void EXT.runtime.lastError; });
  // AMO 0.1.1 used a different menu ID. Remove only this extension's menus
  // before recreating the current entry, including during an update.
  if (!EXT.contextMenus.removeAll) { create(); return; }
  if (typeof globalThis.browser !== "undefined")
    EXT.contextMenus.removeAll().then(create).catch(console.warn);
  else EXT.contextMenus.removeAll(create);
}
async function browserCode() {
  if (typeof globalThis.browser !== "undefined"
      && typeof globalThis.browser.runtime.getBrowserInfo === "function")
    return "firefox";
  const nav = globalThis.navigator;
  try {
    if (await nav?.brave?.isBrave?.()) return "brave";
  } catch { /* detection can be disabled by browser settings */ }
  const ua = nav?.userAgent || "";
  if (ua.includes("Edg/")) return "edge";
  if (ua.includes("Vivaldi/")) return "vivaldi";
  const brands = nav?.userAgentData?.brands || [];
  if (brands.some(b => b.brand === "Microsoft Edge")) return "edge";
  if (brands.some(b => b.brand === "Google Chrome")) return "chrome";
  if (brands.some(b => b.brand === "Chromium")) return "chromium";
  // The currently shipped Chromium package targets Google Chrome.
  // Future browser adapters can override this code when they ship.
  if (ua.includes("Chrome/")) return "chrome";
  return "chrome";
}

async function handlePopup(message) {
  try {
    if (message.kind === "ping") {
      const reply = await nativeHandoff(null, "", "integration.ping", await browserCode());
      return {ok: reply?.ok === true, message: reply?.message || ""};
    }
    if ((await readSettings()).mode === "off")
      return {ok: false, message: "Enable a capture mode in Settings first."};
    const url = validatedUrl(message.url);
    if (!url) return {ok: false, message: "Enter a valid direct HTTP(S) link."};
    const reply = await nativeHandoff(url.href, "", "download.prompt");
    return {ok: reply?.ok === true, message: reply?.message || ""};
  } catch {
    return {ok: false, message: "GenyDL is unavailable. Open the desktop app and check browser integration."};
  }
}

if (EXT.runtime?.onMessage) EXT.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message?.source !== "genydl-popup" || !["ping", "download"].includes(message.kind)
      || sender.id !== EXT.runtime.id) return false;
  const task = handlePopup(message);
  if (typeof globalThis.browser !== "undefined") return task;
  task.then(sendResponse);
  return true;
});

async function reportConnection() {
  // A verified round trip is the only basis for the desktop's
  // 'Connected' label. It does not grant download permissions.
  try {
    await nativeHandoff(null, "", "integration.ping", await browserCode());
  } catch { /* GenyDL may not be running; retry using a browser alarm */ }
}

function scheduleHeartbeat() {
  if (EXT.alarms?.create) EXT.alarms.create("genydl-heartbeat", {periodInMinutes: 1});
  void reportConnection();
}

if (EXT.runtime?.onInstalled) EXT.runtime.onInstalled.addListener(() => {
  registerMenu();
  scheduleHeartbeat();
});
if (EXT.runtime?.onStartup) EXT.runtime.onStartup.addListener(() => {
  registerMenu();
  scheduleHeartbeat();
});
if (EXT.alarms?.onAlarm) EXT.alarms.onAlarm.addListener(alarm => {
  if (alarm.name === "genydl-heartbeat") void reportConnection();
});
if (EXT.contextMenus?.onClicked)
  EXT.contextMenus.onClicked.addListener(info => { offerContextLink(info).catch(console.warn); });
