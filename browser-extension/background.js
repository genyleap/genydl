/* GenyDL WebExtension — Chrome, Edge, Firefox.
 * Pause a browser download while the user reviews the GenyDL Add dialog.
 * Cancel and erase the browser history entry ONLY after explicit user approval.
 * On rejection or native communication failure, resume the browser download.
 */
const EXT = globalThis.browser ?? globalThis.chrome;
const NATIVE_HOST = "com.genyleap.genydl";
const MENU_ID = "genydl-download";
const FILE_EXTENSION = /\.(?:7z|apk|appimage|bz2|csv|deb|dmg|docx?|epub|exe|flac|gz|iso|m4a|mkv|mov|mp3|mp4|msi|pdf|pkg|pptx?|rar|rpm|tar|tgz|torrent|wav|webm|xlsx?|xz|zip)$/i;
const activeRequests = new Set();

function checkUrl(raw) {
  try {
    const url = new URL(raw);
    if (!["http:", "https:"].includes(url.protocol) || url.username || url.password) return null;
    if (url.hostname === "localhost" || url.hostname.endsWith(".localhost")) return null;
    return url;
  } catch { return null; }
}

function excluded(hostname, excludedHosts) {
  return excludedHosts.some(rule => {
    const host = String(rule).trim().toLowerCase().replace(/^\*\./, "");
    return host && (hostname === host || hostname.endsWith("." + host));
  });
}

function sendNative(url, filename = "") {
  const message = {type: "download.prompt", url};
  if (filename) message.filename = filename;
  if (typeof globalThis.browser !== "undefined")
    return globalThis.browser.runtime.sendNativeMessage(NATIVE_HOST, message);
  return new Promise((resolve, reject) => {
    EXT.runtime.sendNativeMessage(NATIVE_HOST, message, response => {
      const error = EXT.runtime.lastError;
      if (error) reject(new Error(error.message));
      else resolve(response);
    });
  });
}

// Browser download metadata may contain the real filename even when the
// redirected final URL has no extension (e.g. GitHub codeload/.../main).
function filenameHint(item) {
  const provided = String(item.filename || "").replace(/\\/g, "/").split("/").pop().trim();
  if (provided && FILE_EXTENSION.test(provided)) return provided;
  const original = checkUrl(item.url);
  if (original) {
    let name = original.pathname.split("/").pop() || "";
    try { name = decodeURIComponent(name); } catch { /* Keep encoded form. */ }
    if (FILE_EXTENSION.test(name)) return name;
  }
  return provided;
}

// Firefox exposes Promise-based downloads methods. Chromium callback APIs
// are normalized to Promises for a single fail-open transfer state machine.
function downloadAction(method, argument) {
  if (typeof globalThis.browser !== "undefined")
    return globalThis.browser.downloads[method](argument);
  return new Promise((resolve, reject) => {
    EXT.downloads[method](argument, value => {
      const error = EXT.runtime.lastError;
      if (error) reject(new Error(error.message));
      else resolve(value);
    });
  });
}

async function resumeBrowserDownload(id) {
  try { await downloadAction("resume", id); }
  catch (err) {
    console.warn("GenyDL could not resume browser download", String(err));
  }
}

async function settings() {
  const defaults = {mode: "smart", excludedHosts: []};
  if (typeof globalThis.browser !== "undefined")
    return globalThis.browser.storage.local.get(defaults);
  return new Promise(resolve => EXT.storage.local.get(defaults, resolve));
}

async function capture(item) {
  if (!item || activeRequests.has(item.id) || item.state === "complete") return;
  const url = checkUrl(item.finalUrl || item.url);
  if (!url) return;

  const config = await settings();
  if (config.mode === "off" || config.mode === "manual") return;
  if (excluded(url.hostname.toLowerCase(), config.excludedHosts || [])) return;
  // Smart mode does not claim to intercept arbitrary POST/blob/streaming flows.
  const mime = String(item.mime || "").toLowerCase();
  const filename = filenameHint(item);
  const original = checkUrl(item.url);
  const directLink = FILE_EXTENSION.test(url.pathname)
    || (original && FILE_EXTENSION.test(original.pathname))
    || FILE_EXTENSION.test(filename)
    || ["application/octet-stream", "application/zip",
        "application/x-zip-compressed"].includes(mime);
  if (config.mode === "smart" && !directLink) return;

  activeRequests.add(item.id);
  let paused = false;
  let cancelled = false;
  try {
    // Do not ask GenyDL to take over a transfer that cannot be paused:
    // it might already be complete or cannot safely be interrupted.
    await downloadAction("pause", item.id);
    paused = true;

    // This response is held open by the native host until the desktop
    // user presses Add or dismisses the dialog (or the request times out).
    const ack = await sendNative(url.href, filename);
    if (!ack || ack.ok !== true) return;

    await downloadAction("cancel", item.id);
    cancelled = true;
    paused = false;
    // Erase just this cancelled record; never clear other download history.
    await downloadAction("erase", {id: item.id});
  } catch (err) {
    console.warn("GenyDL download handoff incomplete", String(err));
  } finally {
    if (paused && !cancelled) await resumeBrowserDownload(item.id);
    activeRequests.delete(item.id);
  }
}

if (EXT.downloads?.onCreated) {
  EXT.downloads.onCreated.addListener(item => { capture(item).catch(console.warn); });
}

if (EXT.runtime?.onInstalled) {
  EXT.runtime.onInstalled.addListener(() => {
    if (EXT.contextMenus?.create) {
      EXT.contextMenus.create({id: MENU_ID, title: "Download with GenyDL",
        contexts: ["link"]}, () => void EXT.runtime.lastError);
    }
  });
}

if (EXT.contextMenus?.onClicked) {
  EXT.contextMenus.onClicked.addListener(async (info) => {
    if (info.menuItemId !== MENU_ID) return;
    const url = checkUrl(info.linkUrl);
    if (!url) return;
    try {
      // Context-menu handoffs show the same review dialog, but there is no
      // existing browser download to pause, cancel or erase.
      await sendNative(url.href);
    } catch (err) {
      console.warn("GenyDL is unavailable; no browser download was modified", String(err));
    }
  });
}
