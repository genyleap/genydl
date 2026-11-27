#!/usr/bin/env node
"use strict";
const assert = require("node:assert/strict");
const fs = require("node:fs");
const crypto = require("node:crypto");

const chrome = JSON.parse(fs.readFileSync("browser-extension/manifest.chromium.json", "utf8"));
const firefox = JSON.parse(fs.readFileSync("browser-extension/manifest.json", "utf8"));
const publicKey = Buffer.from(chrome.key, "base64");
assert.ok(publicKey.length > 200, "Chromium public key missing");
const hex = crypto.createHash("sha256").update(publicKey).digest("hex").slice(0, 32);
const id = [...hex].map(nibble => String.fromCharCode(97 + Number.parseInt(nibble, 16))).join("");
assert.match(id, /^[a-p]{32}$/, "Chromium ID must be valid");
assert.equal(id, "dhmfclimdfgeemdecnghagiodcmiafdb",
  "Unpacked Chromium ID changed; existing native registrations would break");
assert.equal(chrome.manifest_version, 3);
assert.equal(firefox.manifest_version, 3);
assert.equal(chrome.background.service_worker, "background.js");
assert.deepEqual(firefox.background.scripts, ["background.js"]);
assert.equal(firefox.browser_specific_settings.gecko.id,
  "browser@genyleap.com");
assert.ok(firefox.browser_specific_settings.gecko.data_collection_permissions.required
  .includes("websiteActivity"),
  "New Firefox releases must disclose URL transfer to the local desktop app");
for (const manifest of [chrome, firefox]) {
  assert.equal(manifest.action.default_popup, "popup.html");
  assert.equal(manifest.options_ui.page, "options.html");
  for (const [size, icon] of Object.entries(manifest.icons)) {
    assert.equal(manifest.action.default_icon[size], icon);
    assert.ok(fs.existsSync("browser-extension/" + icon));
  }
  assert.ok(manifest.permissions.includes("nativeMessaging"));
  assert.ok(manifest.permissions.includes("contextMenus"));
  assert.ok(!manifest.permissions.includes("downloads"));
  assert.ok(manifest.optional_permissions.includes("downloads"));
}
const identity = fs.readFileSync("src/core/browser_identity.h", "utf8");
assert.ok(identity.includes(`QStringLiteral("${firefox.browser_specific_settings.gecko.id}")`),
  "Firefox signed add-on ID must match the desktop native host identity");
for (const file of ["browser_host_registration.cpp", "browser_integration_manager.cpp", "native_messaging_host.cpp"]) {
  assert.ok(fs.readFileSync("src/core/" + file, "utf8").includes("genydl::browser::firefoxExtensionId()"),
    file + " must use the shared Firefox identity");
}
const registry = fs.readFileSync("src/core/browser_host_registration.cpp", "utf8");
assert.ok(registry.includes(id), "Native host must include the unpacked extension ID");
assert.ok(registry.includes("browserIntegration/enabled/"),
  "Per-browser connection switches must affect native host registration");
console.log("GenyDL browser setup package checks: passed (" + id + ")");
