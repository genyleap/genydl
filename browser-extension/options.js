const api = globalThis.browser ?? globalThis.chrome;
const mode = document.querySelector("#mode");
const excluded = document.querySelector("#excluded");
const status = document.querySelector("#message");

async function load() {
  const options = await api.storage.local.get({mode: "smart", excludedHosts: []});
  mode.value = options.mode;
  excluded.value = (options.excludedHosts || []).join("\n");
}

let pending;
async function save() {
  const hosts = [...new Set(excluded.value.split(/\r?\n/).map(s => s.trim().toLowerCase())
    .filter(s => /^[a-z0-9.-]+$/.test(s) && s.includes(".") && !s.startsWith(".")))];
  await api.storage.local.set({mode: mode.value, excludedHosts: hosts});
  status.textContent = "Saved locally in this browser.";
}
mode.addEventListener("change", save);
excluded.addEventListener("input", () => {
  clearTimeout(pending);
  pending = setTimeout(save, 400);
});
load().catch(err => { status.textContent = String(err); });
