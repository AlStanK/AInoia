import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));

function validateQuestion(question) {
  if (!question || typeof question !== "object") throw new Error("question має бути об'єктом");
  if (!Array.isArray(question.facts) || question.facts.length !== 4) {
    throw new Error(`${question.id || "question"}: має бути рівно 4 факти`);
  }
  const levels = question.facts.map(fact => fact && fact.level);
  if (levels.join(",") !== "2,3,4,5") {
    throw new Error(`${question.id || "question"}: рівні мають бути 2,3,4,5 по порядку`);
  }
}

export function buildQuestionBank({
  input = join(here, "v2-facts.json"),
  output = join(here, "..", "assets", "question-bank-v2.js"),
} = {}) {
  const doc = JSON.parse(readFileSync(input, "utf8"));
  if (!Array.isArray(doc.questions)) throw new Error("questions має бути масивом");
  doc.questions.forEach(validateQuestion);

  const bank = { version: doc.version, rule: doc.rule, questions: doc.questions };
  const json = JSON.stringify(bank).replace(/<\/script/gi, "<\\/script");
  const contents = `(() => { window.AINOIA_V2_QUESTION_BANK = ${json}; })();\n`;

  try {
    if (readFileSync(output, "utf8") === contents) return false;
  } catch (error) {
    if (error.code !== "ENOENT") throw error;
  }
  mkdirSync(dirname(output), { recursive: true });
  writeFileSync(output, contents);
  return true;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const changed = buildQuestionBank();
  console.log(changed ? "generated assets/question-bank-v2.js" : "assets/question-bank-v2.js is current");
}
