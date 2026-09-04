import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

function runWithSavedCoordinator(url) {
  const html = readFileSync(new URL("../index.html", import.meta.url), "utf8");
  const bankScript = readFileSync(new URL("../assets/question-bank-v2.js", import.meta.url), "utf8");
  const script = html.match(/<script src="assets\/question-bank-v2\.js"><\/script>\s*<script>([\s\S]*?)<\/script>/)[1];
  let appHtml = "";
  const elements = new Map();
  const element = id => elements.get(id) || elements.set(id, { hidden:false, innerHTML:"", onclick:null }).get(id);
  const saved = JSON.stringify({
    S: {org:"Coordinator Org", code:"OLD12345", codeFromLink:false, consentAt:"2026-09-04T00:00:00.000Z",
      id:"response-id", c1:"Менеджер", c2:"ops", c3:1, c4:1, c5:["copilots"], ans:{}, facts:{}, ev:{},
      free:{}, started:0, sent:"ok", email:"coordinator@example.test", name:"Coordinator", lead:null},
    step: 9,
  });
  const context = {
    URLSearchParams, console, crypto: { getRandomValues: a => a.fill(1), randomUUID: () => "uuid" },
    location: new URL(url), window: { scrollTo(){} }, navigator: {},
    localStorage: { getItem: () => saved, setItem(){}, removeItem(){} },
    document: {
      querySelector(selector) {
        if (selector === "#app") return { get innerHTML(){ return appHtml; }, set innerHTML(value){ appHtml = value; } };
        return element(selector);
      },
      querySelectorAll: () => [],
      createElement: () => ({ click(){} }),
    },
    URL: { createObjectURL: () => "blob:test", revokeObjectURL(){} }, Blob,
  };
  vm.runInNewContext(bankScript, context);
  vm.runInNewContext(script, context);
  return appHtml;
}

test("valid respondent URL overrides a completed saved coordinator session", () => {
  const html = runWithSavedCoordinator("https://diagnostic.test/?org=ABCD1234&from=%D0%9E%D0%BB%D0%B5%D0%BD%D0%B0");
  assert.match(html, /Вас запросив\(ла\).*Олена/s);
  assert.doesNotMatch(html, /id="invite"/);
  assert.doesNotMatch(html, /id="name"/);
  assert.doesNotMatch(html, /id="email"/);
});

test("coordinator resume without org keeps coordinator controls", () => {
  const html = runWithSavedCoordinator("https://diagnostic.test/");
  assert.match(html, /id="invite"/);
  assert.match(html, /id="name"/);
  assert.match(html, /id="email"/);
});
