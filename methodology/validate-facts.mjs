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
export const BANNED_EVAL = ["системно", "зріло", "ефективно", "належно", "повноцінно", "справжній", "справжня", "справжнє", "справжні", "реально"];
export const MIN_LEN = 45, MAX_LEN = 110, MAX_SPREAD = 1.6;

const stripParens = s => s.replace(/\([^)]*\)/g, "");

export function validate(doc, expectedIds) {
  const errs = [];
  if (doc.version !== "2.0") errs.push(`version має бути "2.0", є ${JSON.stringify(doc.version)}`);
  const qs = Array.isArray(doc.questions) ? doc.questions : [];
  const seen = new Set(qs.map(q => q.id));
  for (const id of expectedIds) if (!seen.has(id)) errs.push(`${id}: відсутнє у файлі`);
  const idCounts = new Map();
  for (const q of qs) idCounts.set(q.id, (idCounts.get(q.id) || 0) + 1);
  for (const [id, count] of idCounts) if (count > 1) errs.push(`${id}: дубльоване id`);
  for (const q of qs) {
    if (!expectedIds.includes(q.id)) errs.push(`${q.id}: зайве — нема серед драбинних питань v1.2`);
    const f = Array.isArray(q.facts) ? q.facts : [];
    if (f.length !== 4) { errs.push(`${q.id}: має бути 4 факти, є ${f.length}`); continue; }
    const levels = f.map(x => x.level);
    if (levels.join() !== "2,3,4,5") errs.push(`${q.id}: рівні мають бути 2,3,4,5 по порядку, є ${levels.join()}`);
    const lens = f.map(x => (x.text || "").length);
    f.forEach((x, i) => {
      const t = x.text || "";
      if (!t) { errs.push(`${q.id} рівень ${x.level}: немає тексту`); return; }
      if (t.length < MIN_LEN || t.length > MAX_LEN) errs.push(`${q.id} рівень ${x.level}: довжина ${t.length}, треба ${MIN_LEN}–${MAX_LEN}`);
      const full = t.toLowerCase();
      const bare = stripParens(t).toLowerCase();
      for (const w of BANNED_EN) {
        const pattern = w.replace(/ /g, "[\\s_-]");
        if (new RegExp(`(^|[^a-z])${pattern}([^a-z]|$)`).test(bare)) errs.push(`${q.id} рівень ${x.level}: англійський термін «${w}» поза дужками`);
      }
      for (const w of BANNED_EVAL) if (full.includes(w)) errs.push(`${q.id} рівень ${x.level}: оцінне слово «${w}»`);
      if (/^(не |немає|нема |жодн|відсутн)/i.test(t.trim())) errs.push(`${q.id} рівень ${x.level}: починається із заперечення`);
    });
    if (Math.max(...lens) / Math.min(...lens) > MAX_SPREAD) errs.push(`${q.id}: розкид довжин ${Math.min(...lens)}–${Math.max(...lens)} > ×${MAX_SPREAD}`);
  }
  return errs;
}

// Очікувані id — з index.html, щоб файл фактів не розʼїхався з анкетою.
export function expectedIdsFromIndex(indexPath) {
  const src = readFileSync(indexPath, "utf8");
  const match = src.match(/const SCORING_IDS = (\[[^\n]+\]);/);
  if (!match) throw new Error("Не знайдено SCORING_IDS в index.html");
  return JSON.parse(match[1]);
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
