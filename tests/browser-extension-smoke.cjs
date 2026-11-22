#!/usr/bin/env node
"use strict";
const fs = require("node:fs");
const vm = require("node:vm");
const assert = require("node:assert/strict");
const script = fs.readFileSync("browser-extension/background.js", "utf8");

const tick = async () => {
  for (let i = 0; i < 15; i++) await new Promise(r => setImmediate(r));
};
let passed = 0;

async function scenario({
  mode, scope, url = "https://example.org/dl.zip",
  finalUrl, filename, mime = "application/zip", contextLink = false,
  deferred = false, approve = true, failPause = false,
  nativeDisconnect = false, failErase = false, expected = {},
}) {
  let onDownload, onMenu, reply, failNative;
  const calls = {pause: [], resume: [], cancel: [], erase: [], native: []};
  let lastError = null;
  const runtime = {
    get lastError() { return lastError; },
    onInstalled: {addListener() {}},
    onStartup: {addListener() {}},
    connectNative(host) {
      assert.equal(host, "com.genyleap.genydl");
      let onMessage, onDisconnect;
      const port = {
        onMessage: {addListener(fn) {onMessage = fn;}},
        onDisconnect: {addListener(fn) {onDisconnect = fn;}},
        postMessage(message) {
          calls.native.push(message);
          reply = (ok = approve) => onMessage({
            requestId: message.requestId, protocolVersion: 2, ok
          });
          failNative = () => {
            lastError = {message: "Host terminated"};
            onDisconnect();
            lastError = null;
          };
          if (!deferred && !nativeDisconnect)
            queueMicrotask(() => reply());
          if (!deferred && nativeDisconnect)
            queueMicrotask(() => failNative());
        },
        disconnect() {}
      };
      return port;
    }
  };
  function call(name, cb, arg) {
    calls[name].push(arg);
    if (name === "pause" && failPause) lastError = {message: "Cannot pause"};
    if (name === "erase" && failErase) lastError = {message: "Cannot erase"};
    cb(name === "erase" ? [42] : undefined);
    lastError = null;
  }
  const chrome = {
    runtime,
    downloads: {
      onCreated: {addListener(fn) {onDownload = fn;}},
      pause: (id, cb) => call("pause", cb, id),
      resume: (id, cb) => call("resume", cb, id),
      cancel: (id, cb) => call("cancel", cb, id),
      erase: (query, cb) => call("erase", cb, query.id),
    },
    contextMenus: {
      create(_opts, cb) {cb();},
      onClicked: {addListener(fn) {onMenu = fn;}}
    },
    storage: {local: {get(_defaults, cb) {
      cb({mode, captureScope: scope || "recognized", excludedHosts: []});
    }}}
  };
  vm.runInNewContext(script, {
    chrome, console: {warn() {}, debug() {}}, URL, Set, Promise, String, Error,
    Date, Math, decodeURIComponent, setTimeout, clearTimeout, queueMicrotask
  });
  if (contextLink)
    onMenu({menuItemId: "genydl-download", linkUrl: url});
  else
    onDownload({id: 42, state: "in_progress", url, finalUrl, filename, mime});
  await tick();

  if (deferred) {
    assert.equal(calls.cancel.length, 0, "no cancellation before user decision");
    assert.equal(calls.erase.length, 0, "no erasure before user decision");
    assert.equal(calls.native.length, 1, "one live native request");
    if (nativeDisconnect) failNative();
    else reply(approve);
    await tick();
  }
  for (const [key, value] of Object.entries(expected)) {
    if (["pause", "resume", "cancel", "erase", "native"].includes(key))
      assert.equal(calls[key].length, value, key + " count");
  }
  if (calls.native.length) {
    const message = calls.native[0];
    assert.equal(message.type, mode === "always" && !contextLink
      ? "download.request" : "download.prompt");
    assert.equal(message.protocolVersion, 2);
    assert.ok(message.requestId, "request ID present");
    if (expected.filename !== undefined)
      assert.equal(message.filename, expected.filename);
    if (expected.url !== undefined)
      assert.equal(message.url, expected.url);
  }
  ++passed;
}

(async () => {
  await scenario({expected: {native: 0, pause: 0, cancel: 0}}); // default Manual
  await scenario({mode: "manual", expected: {native: 0, pause: 0, cancel: 0}});
  await scenario({mode: "off", expected: {native: 0, pause: 0, cancel: 0}});
  await scenario({mode: "ask", expected: {native: 1, pause: 1, cancel: 1, erase: 1}});
  await scenario({mode: "ask", approve: false,
    expected: {native: 1, pause: 1, resume: 1, cancel: 0, erase: 0}});
  await scenario({mode: "always",
    expected: {native: 1, pause: 1, cancel: 1, erase: 1}});
  await scenario({mode: "ask", deferred: true,
    expected: {native: 1, pause: 1, cancel: 1, erase: 1}});
  await scenario({mode: "ask", deferred: true, approve: false,
    expected: {native: 1, resume: 1, cancel: 0, erase: 0}});
  await scenario({mode: "ask", deferred: true, nativeDisconnect: true,
    expected: {native: 1, resume: 1, cancel: 0, erase: 0}});
  await scenario({mode: "ask", failPause: true,
    expected: {native: 0, pause: 1, cancel: 0, erase: 0}});
  await scenario({mode: "ask", failErase: true,
    expected: {native: 1, pause: 1, cancel: 1, erase: 1}});
  await scenario({mode: "smart",
    expected: {native: 0, pause: 0, cancel: 0}});
  await scenario({mode: "automatic",
    expected: {native: 0, pause: 0, cancel: 0}});
  await scenario({mode: "ask", url: "https://example.org/page", mime: "text/html",
    expected: {native: 0, pause: 0, cancel: 0}});
  await scenario({mode: "ask", scope: "all",
    url: "https://example.org/page", mime: "text/html",
    expected: {native: 1, pause: 1, cancel: 1}});
  await scenario({mode: "always", url: "file:///etc/passwd",
    expected: {native: 0, pause: 0, cancel: 0}});
  await scenario({mode: "manual", contextLink: true,
    expected: {native: 1, pause: 0, cancel: 0}});
  await scenario({mode: "off", contextLink: true,
    expected: {native: 0, pause: 0, cancel: 0}});
  await scenario({
    mode: "ask",
    url: "https://github.com/genyleap/genydl/archive/refs/heads/main.zip",
    finalUrl: "https://codeload.github.com/genyleap/genydl/zip/refs/heads/main",
    filename: "/Users/example/Downloads/genydl-main.zip",
    expected: {native: 1, cancel: 1,
      filename: "genydl-main.zip",
      url: "https://codeload.github.com/genyleap/genydl/zip/refs/heads/main"}
  });
  console.log("GenyDL browser integration tests: " + passed + "/" + passed + " passed");
})().catch(error => {console.error(error); process.exitCode = 1;});
