#!/usr/bin/env node
"use strict";
const fs = require("node:fs");
const vm = require("node:vm");
const assert = require("node:assert/strict");
const source = fs.readFileSync("browser-extension/background.js", "utf8");

async function runCase({ack, mode, url, expected}) {
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
  listener({id: 42, url, state: "in_progress", mime: "application/zip"});
  for (let i = 0; i < 20; i++) await new Promise(resolve => setImmediate(resolve));
  assert.equal(native.length, expected.native, "native request count");
  assert.equal(cancelled.length, expected.cancelled, "browser cancellation count");
  if (native.length) {
    assert.equal(native[0].name, "com.genyleap.genydl");
    assert.equal(native[0].message.type, "download.request");
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
    url: "https://example.org/download", expected: {native: 0, cancelled: 0}});
  await runCase({ack: true, mode: "all",
    url: "https://example.org/download", expected: {native: 1, cancelled: 1}});
  await runCase({ack: true, mode: "all",
    url: "file:///tmp/local.zip", expected: {native: 0, cancelled: 0}});
  console.log("GenyDL browser extension smoke: 6/6 passed");
})().catch(error => { console.error(error); process.exitCode = 1; });
