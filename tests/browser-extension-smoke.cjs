#!/usr/bin/env node
"use strict";
const fs = require("node:fs");
const vm = require("node:vm");
const assert = require("node:assert/strict");
const source = fs.readFileSync("browser-extension/background.js", "utf8");

async function runCase({ack, mode, url, filename, finalUrl, mime = "application/zip", expected}) {
  let listener;
  const cancelled = [];
  const native = [];
  const chrome = {
    downloads: {
      onCreated: {addListener: fn => { listener = fn; }},
      cancel: (id, callback) => { cancelled.push(id); callback(); }
    },
    runtime: {
      lastError: null,
      onInstalled: {addListener: () => {}},
      sendNativeMessage: (name, message, callback) => {
        native.push({name, message});
        callback({ok: ack});
      }
    },
    storage: {local: {get: (_defaults, callback) => callback({
      mode, excludedHosts: []
    })}},
    contextMenus: {create: (_opts, callback) => callback(),
      onClicked: {addListener: () => {}}},
    tabs: {create: () => { throw new Error("unexpected fallback"); }}
  };
  const logs = {debug: () => {}, warn: () => {}};
  vm.runInNewContext(source, {chrome, console: logs, URL, Set, Promise, String, Error});
  assert.equal(typeof listener, "function", "downloads listener registered");
  listener({id: 42, url, finalUrl, filename, state: "in_progress", mime});
  for (let i = 0; i < 20; i++) await new Promise(resolve => setImmediate(resolve));
  assert.equal(native.length, expected.native, "native request count");
  assert.equal(cancelled.length, expected.cancelled, "browser cancellation count");
  if (native.length) {
    assert.equal(native[0].name, "com.genyleap.genydl");
    assert.equal(native[0].message.type, "download.request");
    if (expected.filename !== undefined)
      assert.equal(native[0].message.filename, expected.filename, "suggested filename");
    if (expected.url !== undefined)
      assert.equal(native[0].message.url, expected.url, "final download URL");
  }
}
(async () => {
  await runCase({ack: true, mode: "smart",
    url: "https://example.org/a.zip", expected: {native: 1, cancelled: 1}});
  await runCase({ack: false, mode: "smart",
    url: "https://example.org/a.zip", expected: {native: 1, cancelled: 0}});
  await runCase({ack: true, mode: "manual",
    url: "https://example.org/a.zip", expected: {native: 0, cancelled: 0}});
  await runCase({ack: true, mode: "smart",
    url: "https://example.org/download", mime: "text/html", expected: {native: 0, cancelled: 0}});
  await runCase({ack: true, mode: "automatic",
    url: "https://example.org/download", expected: {native: 1, cancelled: 1}});
  await runCase({ack: true, mode: "automatic",
    url: "file:///tmp/local.zip", expected: {native: 0, cancelled: 0}});
  await runCase({ack: true, mode: "smart",
    url: "https://github.com/genyleap/genydl/archive/refs/heads/main.zip",
    finalUrl: "https://codeload.github.com/genyleap/genydl/zip/refs/heads/main",
    filename: "/Users/example/Downloads/genydl-main.zip",
    expected: {native: 1, cancelled: 1, filename: "genydl-main.zip",
      url: "https://codeload.github.com/genyleap/genydl/zip/refs/heads/main"}});
  await runCase({ack: true, mode: "smart",
    url: "https://github.com/genyleap/genydl/archive/refs/heads/main.zip",
    finalUrl: "https://codeload.github.com/genyleap/genydl/zip/refs/heads/main",
    expected: {native: 1, cancelled: 1, filename: "main.zip"}});
  console.log("GenyDL browser extension smoke: 8/8 passed");
})().catch(error => { console.error(error); process.exitCode = 1; });
