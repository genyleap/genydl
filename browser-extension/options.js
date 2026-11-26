const api = globalThis.browser ?? globalThis.chrome;
const mode = document.querySelector("#mode");
const excluded = document.querySelector("#excluded");
const scope = document.querySelector("#scope");
const status = document.querySelector("#message");

function filteredHosts() {
  return [...new Set(excluded.value.split(/\r?\n/).map(s => s.trim().toLowerCase())
    .filter(s => /^[a-z0-9.-]+$/.test(s) && s.includes(".") && !s.startsWith(".")))];
}

async function store() {
  await api.storage.local.set({
    mode: mode.value, captureScope: scope.value, excludedHosts: filteredHosts()
  });
  status.textContent = "Saved in this browser.";
}

async function load() {
  const options = await api.storage.local.get({
    mode: "manual", captureScope: "recognized", excludedHosts: []
  });
  // Previous versions defaulted to capture. Force a fresh opt-in and
  // release the old Downloads permission if it was already granted.
  const legacyCapture = ["smart", "all", "automatic"].includes(options.mode);
  mode.value = legacyCapture
    ? "manual" : (["manual", "ask", "always", "off"].includes(options.mode)
      ? options.mode : "manual");
  scope.value = options.captureScope === "all" ? "all" : "recognized";
  excluded.value = (options.excludedHosts || []).join("\n");
  if (legacyCapture) {
    await store();
    try {
      if (await api.permissions.contains({permissions: ["downloads"]}))
        await api.permissions.remove({permissions: ["downloads"]});
    } catch { /* Browser policy may disallow permission changes. */ }
    status.textContent = "Updated to Manual mode. Automatic capture now requires opt-in.";
  }
  if (["ask", "always"].includes(mode.value)) {
    const granted = await api.permissions.contains({permissions: ["downloads"]});
    if (!granted) {
      mode.value = "manual";
      await store();
      status.textContent = "Downloads permission is missing; Manual mode restored.";
    }
  }
}

async function chooseMode() {
  const chosen = mode.value;
  if (chosen === "ask" || chosen === "always") {
    // Called directly from a user gesture. Browser displays the permission
    // prompt; never try to enable interception without approval.
    let granted = false;
    try {
      granted = await api.permissions.request({permissions: ["downloads"]});
    } catch (error) {
      status.textContent = "Permission request failed: " + String(error);
    }
    if (!granted) {
      mode.value = "manual";
      await store();
      status.textContent = "Downloads permission declined. Manual mode remains active.";
      return;
    }
    await store();
    status.textContent = "Downloads permission granted. Browser integration enabled.";
    // Re-register background listeners after an optional permission grant.
    // The browser closes this popup while restarting the extension.
    if (api.runtime?.reload) api.runtime.reload();
    return;
  }

  await store();
  // Drop privileged download access when switching back to Manual or Off.
  try { await api.permissions.remove({permissions: ["downloads"]}); }
  catch (error) {
    status.textContent = "Mode saved; remove Downloads permission in browser settings if needed.";
  }
}

let pending;
mode.addEventListener("change", () => { chooseMode().catch(
  error => { status.textContent = String(error); }
); });
scope.addEventListener("change", () => { store().catch(
  error => { status.textContent = String(error); }
); });
excluded.addEventListener("input", () => {
  clearTimeout(pending);
  pending = setTimeout(() => { store().catch(
    error => { status.textContent = String(error); }
  ); }, 400);
});
load().catch(error => { status.textContent = String(error); });
