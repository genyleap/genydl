#!/usr/bin/env node
"use strict";
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const script = fs.readFileSync("browser-extension/background.js", "utf8");
const popup = fs.readFileSync("browser-extension/popup.js", "utf8");
const tick = async () => { for (let i=0;i<12;i++) await new Promise(r=>setImmediate(r)); };
async function background(firefox,mode,kind,url,approved=true,sender="genydl",opera=false) {
  let handler, packets=[];
  const runtime = {id:opera?"dfhcknlghpfenoedpjajifdihnokkpbh":"genydl", onMessage:{addListener(f){handler=f;}},
    ...(firefox?{getBrowserInfo:async()=>({name:"Firefox"})}:{}),
    connectNative(host) {
      assert.equal(host,"com.genyleap.genydl");
      let response;
      return {onMessage:{addListener(f){response=f;}},onDisconnect:{addListener(){}},disconnect(){},
        postMessage(msg){packets.push(msg);queueMicrotask(()=>response({ok:approved,requestId:msg.requestId}));}};
    }};
  const api = {runtime, storage:{local:{get:firefox?async defaults=>({...defaults,mode}):(defaults,cb)=>cb({...defaults,mode})}}};
  vm.runInNewContext(script,{[firefox?"browser":"chrome"]:api,URL,Set,Promise,String,Date,Math,Error,console,setTimeout,clearTimeout,queueMicrotask});
  const reply=await new Promise(resolve=>{
    const result=handler({source:"genydl-popup",kind,url},{id:sender},resolve);
    if(result===false) resolve(false);
    else if(result!==true) resolve(result);
  });
  return {reply,packets};
}
async function ui(mode,approved) {
  const elements={};
  for(const id of ["download-form","url","send","check","feedback","indicator","connection","connection-detail","mode-label","settings","version"]) {
    elements[id]={value:"",dataset:{},events:{},addEventListener(k,f){this.events[k]=f;}};
  }
  const calls=[];
  const api={runtime:{getManifest:()=>({version:"1.3.3"}),sendMessage:async m=>{
    calls.push(m);return {ok:m.kind==="ping"||approved,message:approved?"Accepted":"Declined"};
  },openOptionsPage:async()=>{calls.push("settings");}},
  storage:{local:{get:async()=>({mode})}}};
  vm.runInNewContext(popup,{browser:api,document:{getElementById:id=>elements[id]},URL,Promise});
  await tick();
  assert.equal(elements.connection.textContent,"Connected");
  assert.equal(elements.send.disabled,mode==="off");
  assert.equal(elements["mode-label"].textContent,mode==="off"?"Disabled":"Manual");
  elements.url.value="https://example.org/test.zip";
  await elements["download-form"].events.submit({preventDefault(){}});
  assert.equal(calls.filter(x=>x.kind==="download").length,mode==="off"?0:1);
  if(mode!=="off") assert.equal(elements.feedback.dataset.state,approved?"success":"error");
  elements.settings.events.click();
  await tick();
  assert.ok(calls.includes("settings"));
}
(async()=>{
  let count=0;
  for(const firefox of [true,false]) {
    let r=await background(firefox,"manual","ping");
    assert.equal(r.reply.ok,true);assert.equal(r.packets[0].type,"integration.ping");assert.equal(r.packets[0].browser,firefox?"firefox":"chrome");count++;
    r=await background(firefox,"manual","download","https://example.org/file.zip");
    assert.equal(r.reply.ok,true);assert.equal(r.packets[0].type,"download.prompt");count++;
    r=await background(firefox,"always","download","https://example.org/file.zip",false);
    assert.equal(r.reply.ok,false);assert.equal(r.packets[0].type,"download.prompt");count++;
    r=await background(firefox,"off","download","https://example.org/file.zip");
    assert.equal(r.reply.ok,false);assert.equal(r.packets.length,0);count++;
    r=await background(firefox,"manual","download","file:///tmp/private");
    assert.equal(r.reply.ok,false);assert.equal(r.packets.length,0);count++;
    r=await background(firefox,"manual","ping",undefined,true,"other");
    assert.equal(r.reply,false);assert.equal(r.packets.length,0);count++;
  }
  const opera = await background(false,"manual","ping",undefined,true,"dfhcknlghpfenoedpjajifdihnokkpbh",true);
  assert.equal(opera.reply.ok,true);assert.equal(opera.packets[0].browser,"opera");count++;
  await ui("manual",true);count++;
  await ui("manual",false);count++;
  await ui("off",true);count++;
  console.log("GenyDL popup and bridge tests: "+count+"/"+count+" passed");
})().catch(e=>{console.error(e);process.exitCode=1;});
