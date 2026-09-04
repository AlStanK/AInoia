// methodology/validate-facts.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { validate } from "./validate-facts.mjs";

const ok4 = [
  { level: 2, text: "Керівництво за останні 12 місяців обговорювало ШІ як окрему тему." },
  { level: 3, text: "Визначено кілька бізнес-напрямів, де організація планує застосовувати ШІ." },
  { level: 4, text: "Пріоритети щодо ШІ записані в бізнес- або цифровій стратегії." },
  { level: 5, text: "Керівництво щороку переглядає стратегію з урахуванням змін у ШІ." },
];
const base = (facts, over = {}) => ({
  version: "2.0",
  questions: [{ id: "q1", domain: "strategy", title: "Яку роль ШІ відіграє у стратегії?", facts, ...over }],
});
const expectedIds = ["q1"];

test("валідний файл проходить", () => {
  assert.deepEqual(validate(base(ok4), expectedIds), []);
});

test("бракує питання зі списку очікуваних", () => {
  const errs = validate({ version: "2.0", questions: [] }, ["q1"]);
  assert.ok(errs.some(e => e.includes("q1") && e.includes("відсутн")));
});

test("не 4 факти", () => {
  const errs = validate(base(ok4.slice(0, 3)), expectedIds);
  assert.ok(errs.some(e => e.includes("q1") && e.includes("4 факт")));
});

test("рівні мають бути 2,3,4,5 по порядку", () => {
  const bad = ok4.map((f, i) => ({ ...f, level: [2, 3, 5, 4][i] }));
  assert.ok(validate(base(bad), expectedIds).some(e => e.includes("рівн")));
});

test("довжина поза 45–110", () => {
  const bad = [...ok4]; bad[0] = { level: 2, text: "Коротко." };
  assert.ok(validate(base(bad), expectedIds).some(e => e.includes("довжин")));
});

test("розкид довжин max/min > 1.6", () => {
  const bad = [...ok4];
  bad[3] = { level: 5, text: "Керівництво щороку переглядає стратегію з урахуванням змін у ШІ, а результати перегляду доводяться до всіх керівників підрозділів." };
  assert.ok(validate(base(bad), expectedIds).some(e => e.includes("розкид")));
});

test("заборонений англійський термін поза дужками", () => {
  const bad = [...ok4]; bad[1] = { level: 3, text: "Для кожного use case визначено відповідального керівника в бізнесі." };
  assert.ok(validate(base(bad), expectedIds).some(e => e.includes("use case")));
});

test("англійський термін у дужках дозволений", () => {
  const good = [...ok4]; good[1] = { level: 3, text: "Є дорожня карта (roadmap) розвитку ШІ на найближчий рік для кількох напрямів." };
  assert.deepEqual(validate(base(good), expectedIds), []);
});

test("оцінне слово заборонене", () => {
  const bad = [...ok4]; bad[2] = { level: 4, text: "Пріоритети щодо ШІ системно інтегровані в бізнес-стратегію організації." };
  assert.ok(validate(base(bad), expectedIds).some(e => e.includes("системно")));
});

test("факт не має починатись із заперечення", () => {
  const bad = [...ok4]; bad[0] = { level: 2, text: "Немає жодного обговорення ШІ на рівні керівництва за останній рік." };
  assert.ok(validate(base(bad), expectedIds).some(e => e.includes("запереч")));
});
