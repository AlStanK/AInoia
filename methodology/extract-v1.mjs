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
