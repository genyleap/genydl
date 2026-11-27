"use strict";
const api = globalThis.browser ?? globalThis.chrome;
const $ = id => document.getElementById(id);
const form = $("download-form");
const input = $("url");
const send = $("send");
const check = $("check");
const feedback = $("feedback");
let mode = "manual";
let checking = false;
let sending = false;

function message(kind, url) {
  return api.runtime.sendMessage({source: "genydl-popup", kind, ...(url ? {url} : {})});
}

function showFeedback(text, state = "") {
  feedback.hidden = !text;
  feedback.textContent = text;
  feedback.dataset.state = state;
}

function setConnection(state, title, detail) {
  $("indicator").dataset.state = state;
  $("connection").textContent = title;
  $("connection-detail").textContent = detail;
}

function updateControls() {
  input.disabled = mode === "off" || sending;
  send.disabled = mode === "off" || sending;
  check.disabled = checking;
}

async function checkConnection() {
  if (checking) return;
  checking = true;
  updateControls();
  setConnection("checking", "Checking connection…", "Looking for the GenyDL desktop app.");
  try {
    const reply = await message("ping");
    if (reply?.ok === true) setConnection("connected", "Connected", "Desktop app is responding.");
    else setConnection("offline", "Not connected", reply?.message || "Open GenyDL and enable this browser.");
  } catch {
    setConnection("offline", "Not connected", "Open GenyDL, enable browser integration and check again.");
  } finally {
    checking = false;
    updateControls();
  }
}

async function loadMode() {
  const stored = await api.storage.local.get({mode: "manual"});
  mode = ["manual", "ask", "always", "off"].includes(stored.mode) ? stored.mode : "manual";
  $("mode-label").textContent = {manual: "Manual", ask: "Ask first", always: "Automatic", off: "Disabled"}[mode];
  updateControls();
  if (mode === "off") showFeedback("Enable a capture mode in Settings to send links.", "error");
}

form.addEventListener("submit", async event => {
  event.preventDefault();
  if (sending || mode === "off") return;
  const url = input.value.trim();
  let parsed;
  try { parsed = new URL(url); } catch { /* invalid */ }
  if (!parsed || !["http:", "https:"].includes(parsed.protocol) || parsed.username || parsed.password) {
    showFeedback("Enter a direct HTTP or HTTPS link without credentials.", "error");
    return;
  }
  sending = true;
  updateControls();
  showFeedback("Opening the review dialog in GenyDL. Confirm or cancel there.");
  try {
    const reply = await message("download", parsed.href);
    if (reply?.ok === true) {
      input.value = "";
      showFeedback("Download accepted by GenyDL.", "success");
    } else showFeedback(reply?.message || "Download was not accepted.", "error");
  } catch {
    showFeedback("Could not send the link. Check the desktop connection and try again.", "error");
  } finally {
    sending = false;
    updateControls();
  }
});
check.addEventListener("click", checkConnection);
$("settings").addEventListener("click", () => {
  Promise.resolve(api.runtime.openOptionsPage()).catch(() => showFeedback("Could not open extension settings.", "error"));
});
$("version").textContent = "v" + api.runtime.getManifest().version;
api.storage.onChanged?.addListener((changes, area) => {
  if (area === "local" && changes.mode) void loadMode().catch(() => {});
});
void loadMode().catch(() => showFeedback("Could not read extension settings.", "error"));
void checkConnection();
