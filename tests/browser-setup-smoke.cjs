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
  "download-links@genydl.genyleap.com");
for (const manifest of [chrome, firefox]) {
  assert.ok(manifest.permissions.includes("nativeMessaging"));
  assert.ok(manifest.permissions.includes("contextMenus"));
  assert.ok(!manifest.permissions.includes("downloads"));
  assert.ok(manifest.optional_permissions.includes("downloads"));
}
const registry = fs.readFileSync("src/core/browser_host_registration.cpp", "utf8");
assert.ok(registry.includes(id), "Native host must include the unpacked extension ID");
assert.ok(registry.includes("browserIntegration/enabled/"),
  "Per-browser connection switches must affect native host registration");
console.log("GenyDL browser setup package checks: passed (" + id + ")");
