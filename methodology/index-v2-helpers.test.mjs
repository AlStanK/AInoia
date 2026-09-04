import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

test("v2 fact helpers derive answers and detect gaps", () => {
  const html = readFileSync(new URL("../index.html", import.meta.url), "utf8");
  const match = html.match(/\/\* --- v2 fact helpers --- \*\/([\s\S]*?)\/\* --- end v2 fact helpers --- \*\//);
  assert.ok(match, "index.html must expose the v2 fact helpers for browser tests");

  const context = {};
  vm.runInNewContext(`${match[1]}\nglobalThis.helpers = { deriveFactAnswer, factFlags, isFactAnswered };`, context);
  const { deriveFactAnswer, factFlags, isFactAnswered } = context.helpers;

  assert.equal(deriveFactAnswer({ checked: [2, 3], none: false, unknown: false }), 3);
  assert.deepEqual(Array.from(factFlags({ checked: [2, 3], none: false, unknown: false })), []);
  assert.equal(deriveFactAnswer({ checked: [2, 3, 5], none: false, unknown: false }), 3);
  assert.deepEqual(Array.from(factFlags({ checked: [2, 3, 5], none: false, unknown: false })), [5]);
  assert.equal(deriveFactAnswer({ checked: [], none: true, unknown: false }), 1);
  assert.equal(deriveFactAnswer({ checked: [], none: false, unknown: true }), null);
  assert.equal(isFactAnswered({ checked: [], none: false, unknown: false }), false);
  assert.equal(isFactAnswered({ checked: [2], none: false, unknown: false }), true);
});
