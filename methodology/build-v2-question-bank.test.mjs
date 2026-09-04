import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import vm from "node:vm";

import { buildQuestionBank } from "./build-v2-question-bank.mjs";

const sourceFacts = new URL("./v2-facts.json", import.meta.url);

test("buildQuestionBank creates a browser-safe public v2 bank", () => {
  const dir = mkdtempSync(join(tmpdir(), "ainoia-v2-bank-"));
  const input = join(dir, "v2-facts.json");
  const output = join(dir, "question-bank-v2.js");

  try {
    writeFileSync(input, readFileSync(sourceFacts, "utf8"));
    buildQuestionBank({ input, output });

    const script = readFileSync(output, "utf8");
    const context = { window: {} };
    vm.runInNewContext(script, context);
    const bank = context.window.AINOIA_V2_QUESTION_BANK;

    assert.equal(bank.version, "2.0");
    assert.equal(bank.questions.length, 35);
    assert.ok(bank.questions.every(question => question.facts.length === 4));
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("buildQuestionBank escapes a hostile closing script tag", () => {
  const dir = mkdtempSync(join(tmpdir(), "ainoia-v2-bank-"));
  const input = join(dir, "v2-facts.json");
  const output = join(dir, "question-bank-v2.js");

  try {
    const source = JSON.parse(readFileSync(sourceFacts, "utf8"));
    source.rule = "</script><script>window.compromised=true</script>";
    writeFileSync(input, JSON.stringify(source));
    buildQuestionBank({ input, output });

    const script = readFileSync(output, "utf8");
    assert.equal(script.includes("</script"), false);
    const context = { window: {} };
    vm.runInNewContext(script, context);
    assert.equal(context.window.AINOIA_V2_QUESTION_BANK.rule.includes("</script"), true);
    assert.equal(context.window.compromised, undefined);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("buildQuestionBank rejects non-v2 or incomplete source data", () => {
  const dir = mkdtempSync(join(tmpdir(), "ainoia-v2-bank-"));
  const input = join(dir, "v2-facts.json");
  const output = join(dir, "question-bank-v2.js");

  try {
    const incomplete = JSON.parse(readFileSync(sourceFacts, "utf8"));
    incomplete.questions.pop();
    writeFileSync(input, JSON.stringify(incomplete));
    assert.throws(() => buildQuestionBank({ input, output }), /відсутнє|35/);

    const wrongVersion = JSON.parse(readFileSync(sourceFacts, "utf8"));
    wrongVersion.version = "1.2";
    writeFileSync(input, JSON.stringify(wrongVersion));
    assert.throws(() => buildQuestionBank({ input, output }), /version/);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
