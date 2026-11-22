#!/usr/bin/env node
"use strict";
const fs = require("node:fs");
const vm = require("node:vm");
const assert = require("node:assert/strict");
const source = fs.readFileSync("browser-extension/background.js", "utf8");

const flush = async () => {
  for (let i = 0; i < 20; ++i) await new Promise(resolve => setImmediate(resolve));
};

let count = 0;
async function runCase({
  ack = true, mode = "smart", url = "https://example.org/a.zip",
  finalUrl, filename, mime = "application/zip", deferred = false,
  failPause = false, expected = {},
  contextMenu = false
}) {
  let listener;
  let menuListener;
  let replyNative;
  const calls = {paused: [], resumed: [], cancelled: [], erased: [], native: []};
  const chrome = {
    downloads: {
      onCreated: {addListener: fn => { listener = fn; }},
      pause: (id, cb) => {
        calls.paused.push(id);
        if (failPause) chrome.runtime.lastError = {message: "pause unavailable"};
        cb();
        chrome.runtime.lastError = null;
      },
      resume: (id, cb) => { calls.resumed.push(id); cb(); },
      cancel: (id, cb) => { calls.cancelled.push(id); cb(); },
      erase: (query, cb) => { calls.erased.push(query.id); cb([query.id]); }
    },
    runtime: {
      lastError: null,
      onInstalled: {addListener: () => {}},
      sendNativeMessage: (name, message, cb) => {
        calls.native.push({name, message});
        if (deferred) replyNative = cb;
        else if (ack === "error") {
          chrome.runtime.lastError = {message: "native host unavailable"};
          cb();
          chrome.runtime.lastError = null;
        } else cb({ok: ack});
      }
    },
    storage: {local: {get: (_defaults, cb) => cb({mode, excludedHosts: []})}},
    contextMenus: {
      create: (_opts, cb) => cb(),
      onClicked: {addListener: fn => {menuListener = fn;}}
    },
    tabs: {create: () => {throw new Error("unwanted protocol fallback");}}
  };
  const logs = {debug: () => {}, warn: () => {}};
  vm.runInNewContext(source, {
    chrome, console: logs, URL, Set, Promise, String, Error,
    decodeURIComponent
  });
  if (contextMenu) {
    assert.equal(typeof menuListener, "function");
    menuListener({menuItemId: "genydl-download", linkUrl: url});
  } else {
    assert.equal(typeof listener, "function");
    listener({id: 42, url, finalUrl, filename, state: "in_progress", mime});
  }
  await flush();

  if (deferred) {
    assert.equal(calls.native.length, 1, "prompt sent");
    assert.deepEqual(calls.cancelled, [], "never cancel while user reviews dialog");
    assert.deepEqual(calls.erased, [], "never erase before user approves");
    assert.deepEqual(calls.resumed, [], "remain paused while waiting for decision");
    replyNative({ok: ack});
    await flush();
  }

  assert.equal(calls.native.length, expected.native ?? (contextMenu ? 1 : 1));
  for (const key of ["paused", "resumed", "cancelled", "erased"]) {
    if (expected[key] !== undefined)
      assert.equal(calls[key].length, expected[key], key + " count");
  }
  for (const {name, message} of calls.native) {
    assert.equal(name, "com.genyleap.genydl");
    assert.equal(message.type, "download.prompt");
    if (expected.filename !== undefined)
      assert.equal(message.filename, expected.filename);
    if (expected.url !== undefined)
      assert.equal(message.url, expected.url);
  }
  ++count;
}

(async () => {
  await runCase({expected: {paused: 1, resumed: 0, cancelled: 1, erased: 1}});
  await runCase({ack: false, expected: {paused: 1, resumed: 1, cancelled: 0, erased: 0}});
  await runCase({mode: "manual", expected: {native: 0, paused: 0, resumed: 0, cancelled: 0, erased: 0}});
  await runCase({url: "https://example.org/download", mime: "text/html",
    expected: {native: 0, paused: 0, cancelled: 0, erased: 0}});
  await runCase({mode: "automatic", url: "https://example.org/download",
    expected: {native: 1, paused: 1, cancelled: 1, erased: 1}});
  await runCase({mode: "automatic", url: "file:///tmp/local.zip",
    expected: {native: 0, paused: 0, cancelled: 0, erased: 0}});
  await runCase({
    url: "https://github.com/genyleap/genydl/archive/refs/heads/main.zip",
    finalUrl: "https://codeload.github.com/genyleap/genydl/zip/refs/heads/main",
    filename: "/Users/example/Downloads/genydl-main.zip",
    expected: {native: 1, paused: 1, cancelled: 1, erased: 1,
      filename: "genydl-main.zip",
      url: "https://codeload.github.com/genyleap/genydl/zip/refs/heads/main"}
  });
  await runCase({
    url: "https://github.com/genyleap/genydl/archive/refs/heads/main.zip",
    finalUrl: "https://codeload.github.com/genyleap/genydl/zip/refs/heads/main",
    expected: {native: 1, paused: 1, cancelled: 1, erased: 1, filename: "main.zip"}
  });
  await runCase({deferred: true,
    expected: {native: 1, paused: 1, resumed: 0, cancelled: 1, erased: 1}});
  await runCase({deferred: true, ack: false,
    expected: {native: 1, paused: 1, resumed: 1, cancelled: 0, erased: 0}});
  await runCase({failPause: true,
    expected: {native: 0, paused: 1, resumed: 0, cancelled: 0, erased: 0}});
  await runCase({ack: "error",
    expected: {native: 1, paused: 1, resumed: 1, cancelled: 0, erased: 0}});
  await runCase({contextMenu: true,
    expected: {native: 1, paused: 0, resumed: 0, cancelled: 0, erased: 0}});
  console.log(`GenyDL browser extension smoke: ${count}/${count} passed`);
})().catch(error => {console.error(error); process.exitCode = 1;});
