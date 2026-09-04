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
  const facts = [2, 3, 4, 5].map(level => ({ level, text: `Факт рівня ${level}` }));

  try {
    writeFileSync(input, JSON.stringify({
      version: "2.0",
      rule: "</script><script>window.compromised=true</script>",
      questions: [{ id: "q1", domain: "strategy", title: "Питання", facts }],
    }));
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
