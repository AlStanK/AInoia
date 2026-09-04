# Методологія v2.0 — чеклист фактів: план реалізації (підпроєкт 1 з 4)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Перетворити 35 драбинних scoring-питань AI Maturity Assessment v1.2 на 140 спостережуваних фактів (4 на питання, рівні 2–5) у машинночитаному файлі, з валідатором, і зафіксувати це як методологію v2.0 у вольті, рішенні борду й скілі аналітика.

**Architecture:** Джерело істини для фактів — `methodology/v2-facts.json` у репо `ai-readiness-diagnostic`; сторінка (підпроєкт 2) читатиме його при збірці. Валідатор `methodology/validate-facts.mjs` (Node, без залежностей) перевіряє структуру, довжину, монотонність-маркери й заборонену лексику; запускається після кожного домену. Контент авторується по доменах, кожен домен проходить ревʼю Засновника до коміту. Вольт `board/` — окремий git-репо: playbook v2.0, рішення, raw-джерело (два аудити).

**Tech Stack:** Node ≥ 18 (`node --test`), JSON, Markdown/Obsidian. Без npm-залежностей.

**Спека:** `docs/superpowers/specs/2026-09-04-diagnostic-v2-design.md` (§1 п.1, §2, §5 «Вольт»).

---

## Файли

| Дія | Шлях | Відповідальність |
|---|---|---|
| Create | `methodology/extract-v1.mjs` | Витягує `Q` з `index.html`, пише `methodology/v1.2-ladders.md` — вхід для авторів фактів |
| Create | `methodology/v1.2-ladders.md` | Згенерований довідник: 35 питань × 5 варіантів v1.2 |
| Create | `methodology/v2-facts.json` | **Канон фактів v2.0** |
| Create | `methodology/validate-facts.mjs` | Валідатор + CLI |
| Create | `methodology/validate-facts.test.mjs` | Тести валідатора на мінімальних фікстурах |
| Create | `methodology/README.md` | Правила написання фактів, як запускати |
| Modify | `docs/superpowers/specs/2026-09-04-diagnostic-v2-design.md` | 38→35, 152→140 |
| Create (vault) | `board/04 Knowledge/raw/2026-09-04-intro-perception-audits.md` | Два аудити як immutable джерело |
| Create (vault) | `board/04 Knowledge/wiki/playbooks/ai-maturity-assessment-v2.0.md` | Методологія v2.0 |
| Create (vault) | `board/02 Decisions/2026-09-04 Diagnostic v2 facts checklist.md` | Рішення D4–D6 |
| Modify (vault) | `board/04 Knowledge/wiki/hot.md` | Стан продукту |
| Create (skill) | `skills/ainoia-maturity-analyst/references/methodology-v2-addendum.md` | Що змінилось для аналітика |

Шляхи вольту й скіла — відносно `/Users/aleksand/Work/AInoia/`. Репо коду — `/Users/aleksand/Work/AInoia/code/ai-readiness-diagnostic`, гілка `feat/deploy-neon-pages`. Push одразу після кожного коміту (правило Засновника).

---

## Правила написання факту (використовуються в Task 4–11, перевіряються валідатором у Task 2)

1. **Спостережувано.** Факт описує артефакт або практику, яку респондент бачив: «Є названий керівник, відповідальний за розвиток ШІ», а не «Відповідальність організована зріло».
2. **Теперішній час, стверджувальна форма.** Починається з «Є», «Існує», «Керівництво …», «Команди …», «Для …». Без «не», без «або/чи» між двома різними практиками (розбити або обрати головну).
3. **Одна практика на факт.** Якщо варіант v1.2 перелічує 3–4 речі («політики, безпека, приватність, закупівлі»), лишити ту, що відрізняє цей рівень від нижчого; решта — це інші питання або evidence.
4. **Монотонність.** Факт рівня k має бути правдивим завжди, коли правдивий факт k+1. Якщо у v1.2 варіанти не вкладені (напр. рівень 3 «KPI для use cases», рівень 4 «вимірюється для портфеля» — вкладені; рівень 2 «дивляться на кількість ліцензій» — **не** передумова 3), переформулювати нижній так, щоб він став передумовою: «Керівництво регулярно бачить хоча б базові показники використання ШІ».
5. **Довжина 45–110 символів**, у межах питання `max/min ≤ 1.6`. Найдовший факт не має бути найвищим за замовчуванням.
6. **Без англійських термінів у тексті.** Заборонено: owner, sponsor, use case(s), business value, operating model, accountability, pain point(s), capabilit(y|ies), stakeholder(s), governance (як слово в тексті), roadmap як єдина назва. Дозволено в дужках після українського: «дорожня карта (roadmap)», «показники (KPI)», «інтерфейси (API)», «MLOps», «Copilot».
7. **Без оцінних слів:** системно, зріло, ефективно, належно, повноцінно, справжній, реально. Замість «системно» — конкретна періодичність або охоплення: «щоквартально», «для всіх значущих ініціатив».
8. **Часова рамка** для подій: «за останні 12 місяців» (експерименти, навчання, перегляд, інциденти). Для станів («Є документ») — без рамки.
9. **`t` питання не міняти**, крім заміни англійського терміна за п.6.
10. Кількісні Q15, Q20, Q30 і evidence Q5, Q10, Q25, Q37, Q43 у файл фактів **не входять**.

---

### Task 0: Виправити числа у спеці

**Files:**
- Modify: `docs/superpowers/specs/2026-09-04-diagnostic-v2-design.md`

- [ ] **Step 1: Замінити 38→35 і 152→140 у трьох місцях**

```bash
cd /Users/aleksand/Work/AInoia/code/ai-readiness-diagnostic
sed -i '' -e 's/38 scoring-питань → 152 факти/35 драбинних scoring-питань → 140 фактів/' \
          -e 's/38 scoring-питань у 152 факти/35 драбинних scoring-питань у 140 фактів/' \
          -e 's/Scoring-питання: замість/Драбинні scoring-питання (35; кількісні Q15\/Q20\/Q30 не входять): замість/' \
          docs/superpowers/specs/2026-09-04-diagnostic-v2-design.md
grep -n "152\|38 scoring" docs/superpowers/specs/2026-09-04-diagnostic-v2-design.md
```
Expected: grep нічого не виводить.

- [ ] **Step 2: Коміт і push**

```bash
git add docs/superpowers/specs/2026-09-04-diagnostic-v2-design.md
git commit -m "docs(spec v2): 35 драбинних питань → 140 фактів (кількісні не входять)

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
git push origin feat/deploy-neon-pages
```

---

### Task 1: Витяг драбин v1.2 у довідник

**Files:**
- Create: `methodology/extract-v1.mjs`
- Create: `methodology/v1.2-ladders.md` (згенерований)

- [ ] **Step 1: Написати скрипт**

```js
// methodology/extract-v1.mjs
// Витягує масив Q з index.html і пише v1.2-ladders.md — вхід для авторів фактів v2.
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const src = readFileSync(join(here, "..", "index.html"), "utf8");
const m = src.match(/const Q = \[([\s\S]*?)\n\];/);
if (!m) throw new Error("const Q = [...] не знайдено в index.html");
const Q = eval("[" + m[1] + "]");                 // довірений локальний файл

const ladders = Q.filter(q => !q.ev && !q.quant);
const byDomain = {};
for (const q of ladders) (byDomain[q.d] ??= []).push(q);

let out = `# Драбини v1.2 — довідник для авторів фактів v2.0\n\n`;
out += `Згенеровано \`node methodology/extract-v1.mjs\`. Не редагувати руками.\n`;
out += `Питань: ${ladders.length}. Кожен варіант A–E = рівень 1–5.\n\n`;
for (const [d, qs] of Object.entries(byDomain)) {
  out += `## ${d}\n\n`;
  for (const q of qs) {
    out += `### ${q.id} — ${q.t}\n\n`;
    q.o.forEach((o, i) => { out += `${i + 1}. ${o}\n`; });
    out += `\n`;
  }
}
writeFileSync(join(here, "v1.2-ladders.md"), out);
console.log(`ok: ${ladders.length} питань → methodology/v1.2-ladders.md`);
```

- [ ] **Step 2: Запустити**

```bash
cd /Users/aleksand/Work/AInoia/code/ai-readiness-diagnostic
node methodology/extract-v1.mjs && grep -c "^### q" methodology/v1.2-ladders.md
```
Expected: `ok: 35 питань → methodology/v1.2-ladders.md` і `35`.

- [ ] **Step 3: Коміт і push**

```bash
git add methodology/extract-v1.mjs methodology/v1.2-ladders.md
git commit -m "methodology: витяг 35 драбин v1.2 у довідник для авторів фактів v2

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
git push origin feat/deploy-neon-pages
```

---

### Task 2: Валідатор фактів (TDD)

**Files:**
- Create: `methodology/validate-facts.test.mjs`
- Create: `methodology/validate-facts.mjs`

- [ ] **Step 1: Написати тести**

```js
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
```

- [ ] **Step 2: Запустити — має впасти**

```bash
cd /Users/aleksand/Work/AInoia/code/ai-readiness-diagnostic && node --test methodology/
```
Expected: FAIL, `Cannot find module './validate-facts.mjs'`.

- [ ] **Step 3: Написати валідатор**

```js
// methodology/validate-facts.mjs
// Перевіряє methodology/v2-facts.json за правилами methodology/README.md.
// Використання: node methodology/validate-facts.mjs [шлях до json]
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

export const BANNED_EN = [
  "owner", "owners", "sponsor", "use case", "use cases", "business value",
  "operating model", "accountability", "pain point", "pain points",
  "capability", "capabilities", "stakeholder", "stakeholders", "governance",
];
export const BANNED_EVAL = ["системно", "зріло", "ефективно", "належно", "повноцінно", "справжній", "справжня", "реально"];
export const MIN_LEN = 45, MAX_LEN = 110, MAX_SPREAD = 1.6;

const stripParens = s => s.replace(/\([^)]*\)/g, "");

export function validate(doc, expectedIds) {
  const errs = [];
  if (doc.version !== "2.0") errs.push(`version має бути "2.0", є ${JSON.stringify(doc.version)}`);
  const qs = Array.isArray(doc.questions) ? doc.questions : [];
  const seen = new Set(qs.map(q => q.id));
  for (const id of expectedIds) if (!seen.has(id)) errs.push(`${id}: відсутнє у файлі`);
  for (const q of qs) {
    if (!expectedIds.includes(q.id)) errs.push(`${q.id}: зайве — нема серед драбинних питань v1.2`);
    const f = Array.isArray(q.facts) ? q.facts : [];
    if (f.length !== 4) { errs.push(`${q.id}: має бути 4 факти, є ${f.length}`); continue; }
    const levels = f.map(x => x.level);
    if (levels.join() !== "2,3,4,5") errs.push(`${q.id}: рівні мають бути 2,3,4,5 по порядку, є ${levels.join()}`);
    const lens = f.map(x => (x.text || "").length);
    f.forEach((x, i) => {
      const t = x.text || "";
      if (t.length < MIN_LEN || t.length > MAX_LEN) errs.push(`${q.id} рівень ${x.level}: довжина ${t.length}, треба ${MIN_LEN}–${MAX_LEN}`);
      const bare = stripParens(t).toLowerCase();
      for (const w of BANNED_EN) if (new RegExp(`(^|[^a-z])${w}([^a-z]|$)`).test(bare)) errs.push(`${q.id} рівень ${x.level}: англійський термін «${w}» поза дужками`);
      for (const w of BANNED_EVAL) if (bare.includes(w)) errs.push(`${q.id} рівень ${x.level}: оцінне слово «${w}»`);
      if (/^(не |немає|нема |жодн|відсутн)/i.test(t.trim())) errs.push(`${q.id} рівень ${x.level}: починається із заперечення`);
    });
    if (Math.max(...lens) / Math.min(...lens) > MAX_SPREAD) errs.push(`${q.id}: розкид довжин ${Math.min(...lens)}–${Math.max(...lens)} > ×${MAX_SPREAD}`);
  }
  return errs;
}

// Очікувані id — з index.html, щоб файл фактів не розʼїхався з анкетою.
export function expectedIdsFromIndex(indexPath) {
  const src = readFileSync(indexPath, "utf8");
  const Q = eval("[" + src.match(/const Q = \[([\s\S]*?)\n\];/)[1] + "]");
  return Q.filter(q => !q.ev && !q.quant).map(q => q.id);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const here = dirname(fileURLToPath(import.meta.url));
  const file = process.argv[2] || join(here, "v2-facts.json");
  const doc = JSON.parse(readFileSync(file, "utf8"));
  const errs = validate(doc, expectedIdsFromIndex(join(here, "..", "index.html")));
  if (errs.length) { console.error(errs.join("\n")); console.error(`\n${errs.length} помилок`); process.exit(1); }
  const n = doc.questions.length;
  console.log(`ok: ${n} питань, ${n * 4} фактів`);
}
```

- [ ] **Step 4: Тести мають пройти**

```bash
node --test methodology/
```
Expected: `# pass 10`, `# fail 0`.

- [ ] **Step 5: Коміт і push**

```bash
git add methodology/validate-facts.mjs methodology/validate-facts.test.mjs
git commit -m "methodology: валідатор фактів v2 (структура, довжина, лексика, монотонність-маркери)

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
git push origin feat/deploy-neon-pages
```

---

### Task 3: Скелет `v2-facts.json` і README правил

**Files:**
- Create: `methodology/v2-facts.json`
- Create: `methodology/README.md`

- [ ] **Step 1: Згенерувати скелет з порожніми фактами**

```bash
cd /Users/aleksand/Work/AInoia/code/ai-readiness-diagnostic
node -e '
const fs=require("fs");
const src=fs.readFileSync("index.html","utf8");
const Q=eval("["+src.match(/const Q = \[([\s\S]*?)\n\];/)[1]+"]");
const questions=Q.filter(q=>!q.ev&&!q.quant).map(q=>({id:q.id,domain:q.d,title:q.t,facts:[]}));
fs.writeFileSync("methodology/v2-facts.json", JSON.stringify({
  version:"2.0",
  rule:"Рівень питання = 1 + довжина неперервного ланцюга відмічених фактів від рівня 2. Факт вищого рівня без нижчого → facts_flags (inconsistent). «Нічого з цього» → 1. «Не знаю» → null.",
  questions
},null,1)+"\n");
console.log(questions.length);'
```
Expected: `35`.

- [ ] **Step 2: Валідатор має падати на порожніх фактах**

```bash
node methodology/validate-facts.mjs; echo "exit=$?"
```
Expected: 35 рядків `qN: має бути 4 факти, є 0`, `exit=1`.

- [ ] **Step 3: Написати README правил**

```markdown
<!-- methodology/README.md -->
# Методологія у репо

- `v2-facts.json` — канон фактів AI Maturity Assessment v2.0: 35 драбинних питань × 4 факти (рівні 2–5). Сторінка читає його при збірці (підпроєкт 2).
- `v1.2-ladders.md` — згенерований довідник драбин v1.2 (`node methodology/extract-v1.mjs`). Не редагувати.
- `validate-facts.mjs` — валідатор: `node methodology/validate-facts.mjs`. Тести: `node --test methodology/`.

## Правило виведення рівня

Рівень = 1 + довжина неперервного ланцюга відмічених фактів від рівня 2.
Відмічено {2,3} → 3. Відмічено {2,3,5} → 3, факт 5 → `facts_flags.qN = [5]` (inconsistent — у звіті читається як Claimed).
«Нічого з цього» → 1. «Не знаю» → null (як у v1.2).

## Правила написання факту

1. Спостережувано: артефакт або практика, яку респондент бачив.
2. Теперішній час, стверджувальна форма; без заперечень і без «або» між різними практиками.
3. Одна практика на факт.
4. Монотонність: факт k правдивий завжди, коли правдивий k+1.
5. 45–110 символів; у межах питання max/min ≤ 1.6.
6. Без англійських термінів у тексті (owner, sponsor, use case, business value, operating model, accountability, pain point, capability, stakeholder, governance). У дужках після українського — дозволено.
7. Без оцінних слів: системно, зріло, ефективно, належно, повноцінно, справжній, реально.
8. Події — з рамкою «за останні 12 місяців». Стани — без.
9. `title` не міняти, крім заміни англійського терміна.
10. Кількісні Q15/Q20/Q30 і evidence Q5/Q10/Q25/Q37/Q43 сюди не входять.

Повний дизайн: `docs/superpowers/specs/2026-09-04-diagnostic-v2-design.md`.
```

- [ ] **Step 4: Коміт і push**

```bash
git add methodology/v2-facts.json methodology/README.md
git commit -m "methodology: скелет v2-facts.json (35 питань) і правила написання фактів

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
git push origin feat/deploy-neon-pages
```

---

### Task 4: Домен `strategy` — q1–q4 (еталон)

**Files:**
- Modify: `methodology/v2-facts.json` (обʼєкти `q1`…`q4`)

Це еталонний домен: факти написані тут повністю, решта доменів пишуться за тим самим зразком.

- [ ] **Step 1: Прочитати драбини q1–q4**

```bash
sed -n '/^## strategy/,/^## value/p' methodology/v1.2-ladders.md
```

- [ ] **Step 2: Вписати факти**

Замінити `"facts": []` у q1–q4 на:

```json
"q1": [
 {"level":2,"text":"Керівництво за останні 12 місяців обговорювало ШІ як окрему тему і підтримує окремі експерименти."},
 {"level":3,"text":"Визначено конкретні бізнес-напрями, де організація планує застосовувати ШІ."},
 {"level":4,"text":"Пріоритети щодо ШІ записані в бізнес- або цифровій стратегії та в портфелі змін."},
 {"level":5,"text":"Керівництво розглядає ШІ як чинник конкурентної позиції і переглядає стратегію з огляду на це."}
],
"q2": [
 {"level":2,"text":"Є названа особа або група, яка неформально просуває ШІ в організації."},
 {"level":3,"text":"Є призначений керівник або підрозділ, відповідальний за розвиток ШІ."},
 {"level":4,"text":"Відповідальність за ШІ розподілена між керівництвом, бізнесом, IT/даними та іншими функціями і є форум координації."},
 {"level":5,"text":"Керівництво регулярно розглядає стан управління ШІ як частину моделі управління організацією."}
],
"q3": [
 {"level":2,"text":"За останні 12 місяців окремі команди витрачали власні кошти на інструменти або пілоти ШІ."},
 {"level":3,"text":"Є окремо виділений бюджет на ініціативи ШІ хоча б на поточний рік."},
 {"level":4,"text":"Фінансування ініціатив ШІ планується як портфель із пріоритетами й очікуваним ефектом."},
 {"level":5,"text":"Рішення про фінансування ШІ переглядаються за фактичними результатами попередніх ініціатив."}
],
"q4": [
 {"level":2,"text":"Керівництво регулярно бачить хоча б базові показники використання ШІ: кількість користувачів або пілотів."},
 {"level":3,"text":"Для значущих ініціатив ШІ визначено бізнес-показники (KPI) успіху."},
 {"level":4,"text":"Бізнес-ефект вимірюється для портфеля ініціатив ШІ за єдиним підходом."},
 {"level":5,"text":"Результати ШІ впливають на пріоритети, бюджет і рішення про трансформацію."}
]
```

Точні тексти q3 треба звірити з драбиною v1.2 у Step 1 і за потреби підправити — драбина q3 не наведена в цьому плані повністю; зберігати зміст рівнів v1.2, форму — за правилами.

- [ ] **Step 3: Валідатор — домен має проходити, решта падати**

```bash
node methodology/validate-facts.mjs 2>&1 | grep -c "^q[1-4]:"; node methodology/validate-facts.mjs 2>&1 | grep -c "має бути 4 факти"
```
Expected: `0` і `31`.

- [ ] **Step 4: Ревʼю Засновника**

Показати Засновнику таблицю «v1.2 варіант → v2 факт» для q1–q4 (4 питання × 4 рядки) і спитати: «Затверджуєш strategy?». Правки внести й повторити Step 3. Без «так» до Step 5 не переходити.

- [ ] **Step 5: Коміт і push**

```bash
git add methodology/v2-facts.json
git commit -m "methodology(v2): факти домену strategy q1–q4 (затверджено Засновником)

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
git push origin feat/deploy-neon-pages
```

---

### Task 5: Домен `value` — q6–q9

**Files:**
- Modify: `methodology/v2-facts.json` (`q6`…`q9`)

- [ ] **Step 1: Прочитати драбини**

```bash
sed -n '/^## value/,/^## adoption/p' methodology/v1.2-ladders.md
```

- [ ] **Step 2: Написати 16 фактів за правилами README** (зразок — Task 4). Особлива увага: q9 рівень 2 «перехід залежить від команди» → переформулювати як передумову: «За останні 12 місяців хоча б один пілот ШІ перейшов у постійне використання». q8 «business value» → «бізнес-ефект».

- [ ] **Step 3: Валідатор**

```bash
node methodology/validate-facts.mjs 2>&1 | grep -E "^q[6-9]( |:)" ; echo "---"; node methodology/validate-facts.mjs 2>&1 | grep -c "має бути 4 факти"
```
Expected: порожньо до `---`, потім `27`.

- [ ] **Step 4: Ревʼю Засновника** — таблиця v1.2→v2 для q6–q9, чекати «так».

- [ ] **Step 5: Коміт і push**

```bash
git add methodology/v2-facts.json
git commit -m "methodology(v2): факти домену value q6–q9 (затверджено Засновником)

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
git push origin feat/deploy-neon-pages
```

---

### Task 6: Домен `adoption` — q11–q14

**Files:**
- Modify: `methodology/v2-facts.json` (`q11`…`q14`; q15 кількісне — пропустити)

- [ ] **Step 1:** `sed -n '/^## adoption/,/^## data/p' methodology/v1.2-ladders.md`
- [ ] **Step 2:** 16 фактів за правилами. q11 — важливо для `agenticShown()` (поріг ≥3 лишається: ланцюг {2,3} = «ШІ використовується в кількох підрозділах у щоденній роботі»).
- [ ] **Step 3:** `node methodology/validate-facts.mjs 2>&1 | grep -E "^q1[1-4]( |:)"; node methodology/validate-facts.mjs 2>&1 | grep -c "має бути 4 факти"` → порожньо і `23`.
- [ ] **Step 4:** Ревʼю Засновника, чекати «так».
- [ ] **Step 5:** Коміт `methodology(v2): факти домену adoption q11–q14 (затверджено Засновником)` + push.

---

### Task 7: Домен `data` — q16–q19

**Files:**
- Modify: `methodology/v2-facts.json` (`q16`…`q19`; q20 кількісне — пропустити)

- [ ] **Step 1:** `sed -n '/^## data/,/^## tech/p' methodology/v1.2-ladders.md`
- [ ] **Step 2:** 16 фактів. q18 «data governance» → «правила та відповідальні за дані».
- [ ] **Step 3:** `node methodology/validate-facts.mjs 2>&1 | grep -E "^q1[6-9]( |:)"; node methodology/validate-facts.mjs 2>&1 | grep -c "має бути 4 факти"` → порожньо і `19`.
- [ ] **Step 4:** Ревʼю Засновника, чекати «так».
- [ ] **Step 5:** Коміт `methodology(v2): факти домену data q16–q19 (затверджено Засновником)` + push.

---

### Task 8: Домен `tech` — q21–q24

**Files:**
- Modify: `methodology/v2-facts.json` (`q21`…`q24`)

- [ ] **Step 1:** `sed -n '/^## tech/,/^## people/p' methodology/v1.2-ladders.md`
- [ ] **Step 2:** 16 фактів. Технічні терміни, які лишаються в дужках: API, MLOps, SSO.
- [ ] **Step 3:** `node methodology/validate-facts.mjs 2>&1 | grep -E "^q2[1-4]( |:)"; node methodology/validate-facts.mjs 2>&1 | grep -c "має бути 4 факти"` → порожньо і `15`.
- [ ] **Step 4:** Ревʼю Засновника, чекати «так».
- [ ] **Step 5:** Коміт `methodology(v2): факти домену tech q21–q24 (затверджено Засновником)` + push.

---

### Task 9: Домен `people` — q26–q29, q31, q32

**Files:**
- Modify: `methodology/v2-facts.json` (6 питань; q30 кількісне — пропустити)

- [ ] **Step 1:** `sed -n '/^## people/,/^## governance/p' methodology/v1.2-ladders.md`
- [ ] **Step 2:** 24 факти. q31/q32 — культурні питання про сприйняття й безпеку: факти формулювати як спостережувану поведінку («Працівники відкрито розповідають про невдалі спроби з ШІ на командних зустрічах»), не як почуття.
- [ ] **Step 3:** `node methodology/validate-facts.mjs 2>&1 | grep -E "^q(2[6-9]|3[12])( |:)"; node methodology/validate-facts.mjs 2>&1 | grep -c "має бути 4 факти"` → порожньо і `9`.
- [ ] **Step 4:** Ревʼю Засновника, чекати «так».
- [ ] **Step 5:** Коміт `methodology(v2): факти домену people q26–q32 (затверджено Засновником)` + push.

---

### Task 10: Домен `governance` — q33–q36

**Files:**
- Modify: `methodology/v2-facts.json` (`q33`…`q36`)

- [ ] **Step 1:** `sed -n '/^## governance/,/^## agentic/p' methodology/v1.2-ladders.md`
- [ ] **Step 2:** 16 фактів. Не дублювати evidence Q37 (політика, реєстр) — факти тут про практику (перегляд, оцінка ризиків, моніторинг), а не про наявність документа.
- [ ] **Step 3:** `node methodology/validate-facts.mjs 2>&1 | grep -E "^q3[3-6]( |:)"; node methodology/validate-facts.mjs 2>&1 | grep -c "має бути 4 факти"` → порожньо і `5`.
- [ ] **Step 4:** Ревʼю Засновника, чекати «так».
- [ ] **Step 5:** Коміт `methodology(v2): факти домену governance q33–q36 (затверджено Засновником)` + push.

---

### Task 11: Домен `agentic` — q38–q42

**Files:**
- Modify: `methodology/v2-facts.json` (`q38`…`q42`)

- [ ] **Step 1:** `sed -n '/^## agentic/,$p' methodology/v1.2-ladders.md`
- [ ] **Step 2:** 20 фактів. Пороги гейтів рівня 4 читають q38 ≥ 3 і q41 ≥ 3 — ланцюг {2,3} у цих питаннях має означати саме «агенти виконують визначені задачі під контролем людини» і «є людина, що затверджує результати агента» відповідно.
- [ ] **Step 3: Повна валідація**

```bash
node methodology/validate-facts.mjs && node --test methodology/
```
Expected: `ok: 35 питань, 140 фактів`, тести `# fail 0`.

- [ ] **Step 4:** Ревʼю Засновника, чекати «так».
- [ ] **Step 5:** Коміт `methodology(v2): факти домену agentic q38–q42 — усі 140 фактів затверджено` + push.

---

### Task 12: Raw-джерело у вольті — два аудити

**Files:**
- Create: `/Users/aleksand/Work/AInoia/board/04 Knowledge/raw/2026-09-04-intro-perception-audits.md`

- [ ] **Step 1: Створити файл**

Заголовок і frontmatter:

```markdown
---
type: raw
source_kind: internal-analysis
date: 2026-09-03
captured: 2026-09-04
confidential: internal
tags: [raw, diagnostic, ux, psychology]
---

# Аудити сприйняття інтро-екрану AI Readiness Diagnostic (03–04.09.2026)

Два тексти, отримані Засновником від AI-аналітика (marketing-psychology, потім аналіз «керівник vs працівник»). Збережені дослівно як джерело для рішень щодо v2.0. Не редагувати.

## Аудит 1 — «Як людина читає цю сторінку» (03.09.2026)

<дослівний текст першого аудиту з сесії — вставити повністю>

## Аудит 2 — «Керівник vs працівник» (04.09.2026)

<дослівний текст другого аудиту з сесії — вставити повністю>
```

Тексти аудитів — у транскрипті сесії 2026-09-04 (перше й третє повідомлення Засновника); виконавець копіює їх дослівно, без скорочень.

- [ ] **Step 2: Коміт у вольті**

```bash
cd /Users/aleksand/Work/AInoia/board
git add "04 Knowledge/raw/2026-09-04-intro-perception-audits.md"
git commit -m "raw: два аудити сприйняття інтро-екрану діагностики (03–04.09.2026)

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
git remote get-url origin >/dev/null 2>&1 && git push || echo "no remote — локальний vault"
```

---

### Task 13: Playbook v2.0 у вольті

**Files:**
- Create: `/Users/aleksand/Work/AInoia/board/04 Knowledge/wiki/playbooks/ai-maturity-assessment-v2.0.md`
- Modify: `/Users/aleksand/Work/AInoia/board/04 Knowledge/wiki/playbooks/ai-maturity-assessment-v1.2.md` (лише frontmatter `status: superseded` + рядок «Замінено v2.0»)

- [ ] **Step 1: Скопіювати v1.2 як основу**

```bash
cd "/Users/aleksand/Work/AInoia/board/04 Knowledge/wiki/playbooks"
cp ai-maturity-assessment-v1.2.md ai-maturity-assessment-v2.0.md
```

- [ ] **Step 2: Внести зміни у v2.0**

Frontmatter: `sources: ["[[strategic-session-2026-08-21]]", "[[2026-09-04-intro-perception-audits]]", "[[2026-09-04 Diagnostic v2 facts checklist]]"]`, `status: draft  # ратифіковано D4–D6 (Засновник, 2026-09-04); потребує 3–5 пілотів`, `updated: 2026-09-04`.

Заголовок: `# AI Maturity Assessment v2.0 — методологія`. Під цитатою-статусом додати: `> Замінює v1.2. Причина — рішення D4 (чеклист фактів замість драбини).`

§0 «Рішення» — додати рядки:

```markdown
| D4 | Формат scoring-питання | **Чеклист із 4 спостережуваних фактів (рівні 2–5)** замість драбини з 5 варіантів. Рівень = 1 + неперервний ланцюг відмічених фактів; розрив → inconsistent. Джерело: [[2026-09-04-intro-perception-audits]] | 2026-09-04 |
| D5 | Модель запуску | **Координатор**: перший респондент генерує код і розсилає посилання; решта колег не запрошують і email не лишають | 2026-09-04 |
| D6 | Пілоти | v2.0 запускається до першого пілота свідомо; відповіді v1.2 (1 org, 2 респонденти) з v2 напряму не зіставляються | 2026-09-04 |
```

§1 «Що змінено» — нова таблиця зверху:

```markdown
### v1.2 → v2.0 (чеклист фактів)

| # | Зміна | Причина |
|---|---|---|
| 15 | **35 драбинних питань → 140 фактів** (4 на питання, рівні 2–5); підписи «Рівень 1–5» прибрано з інтерфейсу | Аудит сприйняття: драбина показує «правильну» відповідь → social desirability, anchoring; керівники системно завищують |
| 16 | **Правило ланцюга**: рівень = 1 + довжина неперервного ланцюга від рівня 2; факт вищого рівня без нижчого → статус **inconsistent** | Захист від «поставлю верхню»; розрив сам є знахідкою для звіту (аналог Claimed) |
| 17 | Явний пункт «Нічого з цього» → рівень 1 | Відрізняти «рівень 1» від «пропустив» |
| 18 | Правило для респондента: «галочка лише там, де можете назвати приклад або документ» | Фактологічний критерій вибору замість самооцінки |
| 19 | Кількісні Q15/Q20/Q30 і evidence Q5/Q10/Q25/Q37/Q43 — без змін | Уже є фактами |
| 20 | Шкала вимірювання 1–5, смуги §4.4, гейти §9, Alignment §6, Confidence §7 — **без змін** | Виведений рівень 1–5 зберігає контракт; зміна порогів — лише після пілотів |
```

§2 «Рамка»: «49 питань (6 контекстних + 35 фактологічних + 3 кількісних + 5 evidence)».

§4.1 замінити на:

```markdown
### 4.1 Рівень питання
Фактологічне питання: 4 факти, рівні 2–5. `Рівень = 1 + k`, де k — довжина неперервного ланцюга відмічених фактів від рівня 2. Відмічені факти поза ланцюгом → `inconsistent` (§8). «Нічого з цього» → 1. «Не знаю» → **NULL**. Кількісні Q15, Q20, Q30 — власні anchor-діапазони, як у v1.2.
Канон фактів: `code/ai-readiness-diagnostic/methodology/v2-facts.json`.
```

§8 — додати після таблиці статусів:

```markdown
**Inconsistent** (новий, v2.0): факт рівня k відмічено без факту k−1. У score не входить (рівень рахує лише ланцюг). У звіті — окремий блок «непослідовні відповіді»: читається як Claimed — заявлено вище, ніж підтверджує база.
```

§12 — додати п.11: «монотонність фактів: частка inconsistent на питання; >20% → факти не вкладені, переписати».

- [ ] **Step 3: Позначити v1.2 як замінену**

У `ai-maturity-assessment-v1.2.md` frontmatter `status: superseded  # замінено v2.0, 2026-09-04`, під заголовком: `> **Замінено** [[ai-maturity-assessment-v2.0]] (D4, 2026-09-04). Лишається для зіставлення 2 відповідей org codislab.`

- [ ] **Step 4: Коміт у вольті**

```bash
cd /Users/aleksand/Work/AInoia/board
git add "04 Knowledge/wiki/playbooks/ai-maturity-assessment-v2.0.md" "04 Knowledge/wiki/playbooks/ai-maturity-assessment-v1.2.md"
git commit -m "playbook: AI Maturity Assessment v2.0 — чеклист фактів (D4–D6); v1.2 superseded

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
git remote get-url origin >/dev/null 2>&1 && git push || true
```

---

### Task 14: Рішення борду

**Files:**
- Create: `/Users/aleksand/Work/AInoia/board/02 Decisions/2026-09-04 Diagnostic v2 facts checklist.md`

- [ ] **Step 1: Написати рішення за форматом `02 Decisions`**

```markdown
---
type: decision
status: ratified
owner: "[[AInoia-CAIO]]"
date: 2026-09-04
updated: 2026-09-04
due: 2026-09-30
review_date: 2026-12-01
success_metric: "На першому пілоті v2.0: частка inconsistent ≤20% на питання; частка «не знаю» у не-executive ролей нижча, ніж у 2 відповідях v1.2; жодна скарга респондента на «правильну відповідь видно»"
outcome: ""
redteam_verdict: "not requested — зворотна зміна формату, гейти й ваги не чіпаються"
tags: [decision, product, diagnostic, methodology, privacy]
---

# Decision: AI Readiness Diagnostic v2.0 — чеклист фактів, координатор, обіцянка конфіденційності

**Context:** Два аудити сприйняття інтро-екрану ([[2026-09-04-intro-perception-audits]]) показали три системні викривлення анкети v1.2: драбина варіантів з підписами «Рівень 1–5» показує бажану відповідь (social desirability, anchoring, особливо в керівників); обіцянка конфіденційності не називає роботодавця, а email технічно привʼязаний до відповіді; вірусна модель запрошення розмиває відповідальність за вибірку. Пілотів v1.2 ще не було (1 org, 2 респонденти).

**Decision:**

- D4. Формат scoring-питання — чеклист із 4 спостережуваних фактів (рівні 2–5); рівень = 1 + неперервний ланцюг; розрив → inconsistent. Канон — `methodology/v2-facts.json` у репо. Шкала 1–5, смуги, гейти, Alignment, Confidence — без змін.
- D5. Модель запуску — координатор. Респонденти колег не запрошують і email не лишають; `contacts` втрачає звʼязок із `responses`.
- D6. v2.0 іде на перший пілот без пілотування v1.2. Дві відповіді v1.2 зберігаються з `version='1.2'` і в зведення v2 не входять.
- Обіцянка респонденту на титульній і в privacy: «Керівництво отримає лише зведений звіт. Індивідуальні відповіді, ролі й імена бачить обмежене коло консультантів AInoia — і ніхто у вашій організації». Зріз функції показується при ≥3 респондентах.
- Всім респондентам — однаковий набір питань (роутинг за роллю відхилено: розбіжність між функціями і є продукт).

## Accountability

- **Owner:** [[AInoia-CAIO]] · **Due:** 2026-09-30 — v2.0 на проді · **Review:** 2026-12-01 після першого пілота
- **Responsible:** Засновник (контент фактів затверджує подоменно), AInoia-CTO (сторінка, міграція), AInoia-CISO (обіцянка конфіденційності відповідає схемі)
- **Consulted:** AInoia-CPO, AInoia-CMO (копі), AInoia-CoS (вольт)
- **Approver:** Засновник, робоча сесія 2026-09-04
- **Success metric:** див. frontmatter
- **Next physical action:** виконати план `code/ai-readiness-diagnostic/docs/superpowers/plans/2026-09-04-methodology-v2-facts.md`; далі підпроєкти 2–4 за спекою `2026-09-04-diagnostic-v2-design.md`

## Governance

- **Red-Team verdict:** не запитувався: зміна зворотна (v1.2 лишається в репо й вольті), гейти/ваги не чіпаються. Червона команда — після першого пілота разом із калібруванням §12.
- **Пов'язано:** [[ai-maturity-assessment-v2.0]] · [[ai-maturity-assessment-v1.2]] · [[2026-08-22 Product naming]]
```

- [ ] **Step 2: Коміт у вольті**

```bash
cd /Users/aleksand/Work/AInoia/board
git add "02 Decisions/2026-09-04 Diagnostic v2 facts checklist.md"
git commit -m "decision: Diagnostic v2.0 — чеклист фактів, координатор, конфіденційність (D4–D6)

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
git remote get-url origin >/dev/null 2>&1 && git push || true
```

---

### Task 15: `hot.md` і addendum у скілі аналітика

**Files:**
- Modify: `/Users/aleksand/Work/AInoia/board/04 Knowledge/wiki/hot.md`
- Create: `/Users/aleksand/Work/AInoia/skills/ainoia-maturity-analyst/references/methodology-v2-addendum.md`
- Modify: `/Users/aleksand/Work/AInoia/skills/ainoia-maturity-analyst/SKILL.md` (один рядок-посилання на addendum)

- [ ] **Step 1: hot.md**

Знайти блок про AI Readiness Diagnostic (`grep -n "Diagnostic\|Maturity" hot.md`) і додати рядок:

```markdown
- **AI Maturity Assessment v2.0** (D4–D6, 2026-09-04): чеклист фактів замість драбини, координаторна модель, обіцянка конфіденційності. Канон фактів — `code/ai-readiness-diagnostic/methodology/v2-facts.json`. v1.2 superseded; 2 відповіді codislab лишаються v1.2. Статус: методологія затверджена, сторінка/БД — у роботі (спека `docs/superpowers/specs/2026-09-04-diagnostic-v2-design.md`).
```

- [ ] **Step 2: Addendum для аналітика**

```markdown
# Addendum v2.0 для аналітика (чинний з 2026-09-04)

Читати разом із `methodology.md` (витяг v1.2). Що змінюється для інтерпретації:

1. **`responses.version`**: `'1.2'` — драбина, `'2.0'` — факти. В одній org змішувати не можна: зведення будувати лише по одній версії; при змішаних — ⚠️ у звіті, старшу версію відкинути.
2. **`answers.qN`** у v2.0 — виведене число (1 + ланцюг). Читається так само, як у v1.2; score/gates/Alignment/Confidence не перераховувати.
3. **`facts.qN = {checked:[...], none, unknown}`** — які саме факти відмічено. Використовувати у звіті для конкретизації: замість «Strategy 2.4» — «є названий керівник за ШІ, немає виділеного бюджету».
4. **`facts_flags.qN = [k, ...]`** — inconsistent: факт k без k−1. Читати як **Claimed**: заявлено вище, ніж підтверджує база. Окремий блок звіту «Непослідовні відповіді». Якщо >20% питань респондента з флагами — питання до формулювань, не до респондента (передати в калібрування §12 п.11).
5. **Мінімальний зріз**: профіль функції показувати лише при ≥3 респондентах у role_group; інакше зливати у два зрізи «бізнес (executive+business+people) / не-бізнес (it_data+risk)». Це правило конфіденційності, не статистики.
6. **Координатор**: `contacts` містить лише координатора (`kind='coordinator'`), без `response_id`. Зведення надсилається йому.

Джерела: [[ai-maturity-assessment-v2.0]], [[2026-09-04 Diagnostic v2 facts checklist]].
```

- [ ] **Step 3: Посилання у SKILL.md**

У розділі, де перелічено `references/methodology.md`, додати рядок: `- references/methodology-v2-addendum.md — зміни v2.0 (факти, inconsistent, мінімальний зріз). Читати першим для org з version='2.0'.`

- [ ] **Step 4: Коміти**

```bash
cd /Users/aleksand/Work/AInoia/board
git add "04 Knowledge/wiki/hot.md"
git commit -m "hot: стан AI Maturity Assessment v2.0

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
git remote get-url origin >/dev/null 2>&1 && git push || true

cd /Users/aleksand/Work/AInoia/skills
git status --short . 2>/dev/null | head -3   # skills/ може бути в іншому репо або без git
```

Якщо `skills/` під git — закомітити `ainoia-maturity-analyst/references/methodology-v2-addendum.md` і `SKILL.md` з повідомленням `skill(maturity-analyst): addendum v2.0`. Якщо ні — файли лишаються на диску, зазначити у звіті виконання.

---

## Самоперевірка плану

**Покриття спеки (§1 п.1, §2, §5 «Вольт», §5 «Скіл» частково):** 35→140 фактів — Task 3–11; правило ланцюга і флаги — Task 3 (`rule`), 13 (§4.1, §8), 15 (addendum); playbook v2.0 — Task 13; рішення — Task 14; raw-джерело — Task 12; hot.md — Task 15; мін. зріз ≥3 і inconsistent-блок для аналітика — Task 15 п.4–5 (виконання в самих правилах скіла — підпроєкт 4). Модель питання у `index.html`, payload `facts`, флоу координатора, копі, міграція БД, дашборд — **підпроєкти 2–4, окремі плани.**

**Плейсхолдери:** у Task 12 текст аудитів навмисно не дублюється у плані (є в транскрипті сесії й буде вставлений дослівно) — це вказівка на джерело, не TBD. Task 4 містить повний еталон 16 фактів; Task 5–11 дають правила, зразок і специфічні застереження на домен, а контент авторується виконавцем і затверджується Засновником — це і є робота підпроєкту.

**Узгодженість імен:** `v2-facts.json` → поля `version`, `rule`, `questions[].{id,domain,title,facts[].{level,text}}` однакові в Task 3, 4, валідаторі (Task 2) і addendum (Task 15). `facts` / `facts_flags` / `none` / `unknown` — як у спеці §2. `validate(doc, expectedIds)` і `expectedIdsFromIndex()` — Task 2, використані в CLI тієї ж задачі.
