#!/usr/bin/env node
"use strict";

// Promise-based Firefox WebExtension behavior differs from the callback-based
// Chrome API. Run both regressions whenever the shared background changes.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const code = fs.readFileSync("browser-extension/background.js", "utf8");

async function tick() {
  for (let i = 0; i < 16; ++i) await new Promise(resolve => setImmediate(resolve));
}

async function scenario(mode, action, approved = true) {
  const calls = {native: [], pause: [], resume: [], cancel: [], erase: [], menu: []};
  let onCreated, onMenu, onStartup;
  const browser = {
    runtime: {
      getBrowserInfo: async () => ({name: "Firefox"}),
      onInstalled: {addListener() {}},
      onStartup: {addListener(fn) {onStartup = fn;}},
      connectNative(host) {
        assert.equal(host, "com.genyleap.genydl");
        let onMessage;
        return {
          onMessage: {addListener(fn) {onMessage = fn;}},
          onDisconnect: {addListener() {}},
          disconnect() {},
          postMessage(message) {
            calls.native.push(message);
            queueMicrotask(() => onMessage({
              ok: approved, requestId: message.requestId,
              protocolVersion: message.protocolVersion
            }));
          }
        };
      }
    },
    downloads: {
      onCreated: {addListener(fn) {onCreated = fn;}},
      pause: async id => {calls.pause.push(id);},
      resume: async id => {calls.resume.push(id);},
      cancel: async id => {calls.cancel.push(id);},
      erase: async q => {calls.erase.push(q.id);}
    },
    storage: {local: {get: async defaults => ({...defaults, mode})}},
    contextMenus: {
      create: (item) => {calls.menu.push(item);},
      onClicked: {addListener(fn) {onMenu = fn;}}
    },
    alarms: {create() {}, onAlarm: {addListener() {}}}
  };
  vm.runInNewContext(code, {
    browser, URL, Set, Promise, String, Date, Math, Error, decodeURIComponent,
    console, setTimeout, clearTimeout, queueMicrotask
  });
  if (action === "startup") onStartup();
  else if (action === "menu")
    onMenu({menuItemId: "genydl-download", linkUrl: "https://example.org/test.zip"});
  else onCreated({id: 21, url: "https://example.org/test.zip",
                  mime: "application/zip", state: "in_progress"});
  await tick();
  if (action === "startup") {
    assert.equal(calls.native.length, 1);
    assert.equal(calls.native[0].type, "integration.ping");
    assert.equal(calls.native[0].browser, "firefox");
    assert.equal(calls.pause.length, 0);
  } else if (action === "menu") {
    assert.equal(calls.native.length, mode === "off" ? 0 : 1);
    if (calls.native.length) assert.equal(calls.native[0].type, "download.prompt");
    assert.equal(calls.pause.length, 0);
  } else if (mode === "manual" || mode === "off") {
    assert.equal(calls.native.length, 0);
    assert.equal(calls.pause.length, 0);
  } else {
    assert.equal(calls.native.length, 1);
    assert.equal(calls.pause.length, 1);
    assert.equal(calls.cancel.length, approved ? 1 : 0);
    assert.equal(calls.resume.length, approved ? 0 : 1);
    assert.equal(calls.native[0].type, mode === "always"
      ? "download.request" : "download.prompt");
  }
}

(async () => {
  await scenario("manual", "download");
  await scenario("manual", "menu");
  await scenario("off", "menu");
  await scenario("manual", "startup");
  await scenario("ask", "download", true);
  await scenario("ask", "download", false);
  await scenario("always", "download", true);
  console.log("Firefox WebExtension native handshake and download mode tests: 7/7 passed");
})().catch(error => {console.error(error); process.exitCode = 1;});
