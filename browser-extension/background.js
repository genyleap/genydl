/* GenyDL WebExtension — Chrome, Edge, Firefox; Safari where supported.
 * A download is cancelled ONLY after the native host acknowledges acceptance.
 * Keep browser downloads intact when the desktop app or host is unavailable.
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
  const message = {type: "download.request", url};
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

function cancelDownload(id) {
  if (typeof globalThis.browser !== "undefined")
    return globalThis.browser.downloads.cancel(id);
  return new Promise((resolve, reject) =>
    EXT.downloads.cancel(id, () => {
      const error = EXT.runtime.lastError;
      if (error) reject(new Error(error.message));
      else resolve();
    }));
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
  try {
    const ack = await sendNative(url.href, filename);
    if (ack && ack.ok === true) {
      // Browser cancellation is deliberately after the GenyDL enqueue ACK.
      // If cancellation fails, the browser keeps its own download.
      await cancelDownload(item.id);
    }
  } catch (err) {
    console.debug("GenyDL native handoff unavailable; browser download kept", String(err));
  } finally {
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
      const ack = await sendNative(url.href);
      if (ack?.ok === true) return;
    } catch { /* Explicit user action may use the protocol fallback. */ }
    const external = "genydl://download/?url=" + encodeURIComponent(url.href);
    if (EXT.tabs?.create) EXT.tabs.create({url: external});
  });
}
