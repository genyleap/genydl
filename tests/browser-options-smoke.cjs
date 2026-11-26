#!/usr/bin/env node
"use strict";
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const code = fs.readFileSync("browser-extension/options.js", "utf8");
const flush = async () => { for (let i = 0; i < 16; i++) await new Promise(r => setImmediate(r)); };

async function scenario({initialMode, initiallyGranted, grant, action, resultMode,
                         requests, removals, reloads}) {
  let saved = null;
  let granted = Boolean(initiallyGranted);
  const calls = {requests: 0, removals: 0, reloads: 0};
  const nodes = {};
  for (const id of ["mode", "scope", "excluded", "message"]) {
    nodes["#" + id] = {
      value: "", textContent: "", callbacks: {},
      addEventListener(event, fn) { this.callbacks[event] = fn; }
    };
  }
  const browser = {
    storage: {local: {
      get: async defaults => ({...defaults, mode: initialMode}),
      set: async values => {saved = values;}
    }},
    permissions: {
      contains: async () => granted,
      request: async () => {
        ++calls.requests;
        granted = Boolean(grant);
        return granted;
      },
      remove: async () => {
        ++calls.removals;
        granted = false;
        return true;
      }
    },
    runtime: {reload() {++calls.reloads;}}
  };
  vm.runInNewContext(code, {
    browser, document: {querySelector: selector => nodes[selector]},
    Set, String, Promise, Error, setTimeout, clearTimeout, console
  });
  await flush();
  if (action) {
    nodes["#mode"].value = action;
    nodes["#mode"].callbacks.change();
    await flush();
  }
  assert.equal(nodes["#mode"].value, resultMode);
  assert.equal(calls.requests, requests);
  assert.equal(calls.removals, removals);
  assert.equal(calls.reloads, reloads);
  if (saved) assert.equal(saved.mode, resultMode);
}

(async () => {
  await scenario({initialMode: "manual", resultMode: "manual",
    requests: 0, removals: 0, reloads: 0});
  await scenario({initialMode: "smart", resultMode: "manual",
    requests: 0, removals: 0, reloads: 0});
  await scenario({initialMode: "smart", initiallyGranted: true,
    resultMode: "manual", requests: 0, removals: 1, reloads: 0});
  await scenario({initialMode: "ask", initiallyGranted: false, resultMode: "manual",
    requests: 0, removals: 0, reloads: 0});
  await scenario({initialMode: "manual", action: "ask", grant: true,
    resultMode: "ask", requests: 1, removals: 0, reloads: 1});
  await scenario({initialMode: "manual", action: "always", grant: false,
    resultMode: "manual", requests: 1, removals: 0, reloads: 0});
  await scenario({initialMode: "ask", initiallyGranted: true, action: "manual",
    resultMode: "manual", requests: 0, removals: 1, reloads: 0});
  await scenario({initialMode: "manual", action: "off",
    resultMode: "off", requests: 0, removals: 1, reloads: 0});
  console.log("GenyDL permission and mode tests: 8/8 passed");
})().catch(error => {console.error(error); process.exitCode = 1;});
