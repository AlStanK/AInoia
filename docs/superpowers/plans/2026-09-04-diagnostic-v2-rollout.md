# AI Readiness Diagnostic v2.0 Rollout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the published v1.2 ladder questionnaire with the approved v2.0 fact checklist while preserving the server score contract and making v2 responses analyzable without exposing individual responses.

**Architecture:** `methodology/v2-facts.json` remains the only authored source for the 35 checklist questions. A deterministic Node generator emits the public question-bank asset consumed by `index.html`; the page derives numeric `answers` and non-contiguous `facts_flags` locally. The database persists those two v2 audit fields, keeps all aggregates and gates based on numeric `answers`, and provides a reader-only view for inconsistent facts. The dashboard displays version composition and those inconsistencies without reading data as an anonymous user.

**Tech Stack:** static HTML/CSS/vanilla JavaScript, Node 24 built-ins (`node --test`), PostgreSQL/Neon SQL, GitHub Pages.

**Spec:** `docs/superpowers/specs/2026-09-04-diagnostic-v2-design.md`

## Global Constraints

- Payload is `version: "2.0"`, `answers.qN` is a number or `null`, `facts.qN` is `{checked:number[], none:boolean, unknown:boolean}`, and `facts_flags.qN` contains only the checked levels above the first chain gap.
- The level for a fact question is `1 +` the consecutive checked levels beginning at 2; `none` returns 1 and `unknown` returns `null`.
- The five evidence questions and quantitative Q15/Q20/Q30 retain their v1.2 controls and scoring.
- Every respondent sees the same questions; the agentic block is no longer conditionally hidden.
- A respondent never sees an invitation card or coordinator contact form. Only a coordinator (a visit without `?org=`) sees them.
- Anonymous database roles retain insert-only permissions; contacts are connected only by `org_code`, never by `responses.id`.
- Do not run a production migration, deploy Pages, push, or alter the existing untracked `assets/Copy of AInoia Design System.zip` and `.claude/launch.json` during implementation.

---

## File structure and parallel boundaries

| Workstream | Files owned | Contract produced |
|---|---|---|
| Question-bank + frontend | `methodology/build-v2-question-bank.mjs`, `methodology/build-v2-question-bank.test.mjs`, `assets/question-bank-v2.js`, `index.html`, `.github/workflows/pages.yml` | browser global `window.AINOIA_V2_QUESTION_BANK` and v2 payload |
| Database | `db/schema.sql`, `db/migrate-v2.sql`, `db/neon-grants.sql`, `db/fixture.sql`, `db/aggregate.sql`, `db/gates.sql` | persisted `facts`, `facts_flags`, contact-by-code schema, `v_fact_flags` |
| Dashboard + documentation | `dashboard/results-dashboard.html`, `README.md` | version composition and inconsistency rendering from reader export |
| Integration + QA | `methodology/*.test.mjs`, `docs/superpowers/plans/...` | contract checks and manual browser evidence |

### Task 1: Generate the public v2 question bank

**Files:**
- Create: `methodology/build-v2-question-bank.mjs`
- Create: `methodology/build-v2-question-bank.test.mjs`
- Create: `assets/question-bank-v2.js`
- Modify: `.github/workflows/pages.yml`

**Consumes:** `methodology/v2-facts.json` with `{version, rule, questions:[{id,domain,title,facts:[{level,text}]}]}`.

**Produces:** `assets/question-bank-v2.js`, an IIFE that assigns exactly `{version, rule, questions}` to `window.AINOIA_V2_QUESTION_BANK`, preserving question order and escaping `</script` as `<\\/script`.

- [ ] **Step 1: Write generator tests.** Assert that a generated temporary asset parses after evaluating in a Node VM, contains version `2.0`, 35 questions, four facts per question, and does not contain a literal closing script tag from a hostile fixture.
- [ ] **Step 2: Run `node --test methodology/build-v2-question-bank.test.mjs` and confirm the missing generator fails.**
- [ ] **Step 3: Implement the zero-dependency generator.** Read the JSON from the script directory, validate each question has four sequential levels 2–5, stringify the full object into a narrow IIFE, and write the generated file only when its contents differ.
- [ ] **Step 4: Add `node methodology/build-v2-question-bank.mjs` before the Pages copy step.** The workflow must copy only `index.html` and `assets/` to `_site`; `methodology/` must remain absent from the deployed artifact.
- [ ] **Step 5: Generate the checked-in asset and run both `node methodology/validate-facts.mjs` and the new generator test.**

### Task 2: Replace ladder UI and coordinate the v2 respondent flow

**Files:**
- Modify: `index.html`
- Consumes: `assets/question-bank-v2.js` and the v2 payload contract from Global Constraints.

**Produces:** fact checklist rendering, non-contiguous-answer detection, `version: "2.0"` payload, and coordinator-only contacts.

- [ ] **Step 1: Add pure, browser-testable helpers inside `index.html`: `deriveFactAnswer(state)`, `factFlags(state)`, and `isFactAnswered(state)`.** Cover four cases through a small Node VM test fixture: `[2,3] → 3`, `[2,3,5] → answer 3 and flags [5]`, `none → 1`, and `unknown → null`.
- [ ] **Step 2: Load `assets/question-bank-v2.js` before the inline application script and build the 35 scoring question objects from it.** Keep Q5/Q10/Q15/Q20/Q25/Q30/Q37/Q43 from the existing question metadata; remove all `o:[...]` scoring ladders from the runtime question bank.
- [ ] **Step 3: Render each scoring question as four labeled checkboxes plus mutually exclusive `Нічого з цього` and `Не знаю`.** Changing `none` or `unknown` clears and disables facts; changing any fact clears `none` and `unknown`. The error text must request either a fact, `Нічого з цього`, or `Не знаю`.
- [ ] **Step 4: Make all eight domain steps unconditional and show the exact counter `Питання N із 43`.** Retain the six context questions and all eight evidence/quantitative questions; remove the v1.2 `agenticShown()` routing rule.
- [ ] **Step 5: Implement the approved copy.** Use the approved hook, the employer-specific privacy promise, the evidence hint on every scoring step, the new “Перед початком” card, `CONSENT_VERSION = "2026-09-04-v2"`, and the approved neutral individual-result labels.
- [ ] **Step 6: Implement coordinator separation.** A visit lacking `?org=` is coordinator; after it saves, show the name, optional email, and link `?org=<code>&from=<name>`. A visit with a valid `?org=` is a respondent: retain the privacy context but render no invitation, name, or email controls.
- [ ] **Step 7: Emit the complete v2 payload.** Include numeric `answers`, `facts`, and only non-empty `facts_flags`; retain evidence/free text, role metadata, domains, score, consent, duration, and generated response ID. In the contact POST, send `{org_code,email,name,kind:"coordinator",consent_version}` without `response_id`.
- [ ] **Step 8: Run the narrow helper test, generator test, facts validator, and a static syntax check.** Start a local static server and verify the three browser scenarios: coordinator, `?org=ABCD1234&from=Олена`, and `?org=ABCD1234`.

### Task 3: Make storage and reader views v2-aware without changing score computation

**Files:**
- Modify: `db/schema.sql`, `db/aggregate.sql`, `db/gates.sql`, `db/fixture.sql`, `db/neon-grants.sql`
- Create: `db/migrate-v2.sql`

**Consumes:** v2 payload from Task 2. **Produces:** migration-safe columns and reader-only `diagnostic.v_fact_flags` rows `{org,response_id,question,checked,flags,created_at,role_group}`.

- [ ] **Step 1: Extend the fresh schema.** Set `responses.version` default to `2.0`; add `facts jsonb not null default '{}'` and `facts_flags jsonb not null default '{}'`, each constrained to JSON objects. Change `contacts` to omit `response_id`, add `kind text not null default 'coordinator' check (kind in ('coordinator'))`, and index `contacts.org_code`.
- [ ] **Step 2: Write `db/migrate-v2.sql` as an idempotent migration.** Add the two response columns and their constraints only if missing; set the default for future rows to `2.0`; drop the old response foreign-key/index/column only after checking each object exists; add and validate `contacts.kind`; recreate least-privilege grants and insert policies without granting reads.
- [ ] **Step 3: Add `diagnostic.v_fact_flags`.** It must return only v2 rows with non-empty flags by expanding `facts_flags`; it must not influence `v_domain_*`, `v_org_result`, Confidence, evidence statuses, or gates, which continue to derive from numeric `answers`.
- [ ] **Step 4: Seed one v1.2 fixture and one v2 fixture.** The v2 fixture must include a continuous chain, an inconsistent chain, `none`, and `unknown`; assert the stored numeric answers are respectively `3`, `3`, `1`, and JSON null.
- [ ] **Step 5: Run fresh-schema and migration-path checks in a disposable local PostgreSQL database.** Capture `v_org_result` for v1.2 fixture rows before/after migration and assert identical JSON. Confirm anonymous role has `INSERT` but no `SELECT` on both tables.

### Task 4: Surface version and inconsistent facts in the consultant dashboard

**Files:**
- Modify: `dashboard/results-dashboard.html`
- Consumes: the offline reader export arrays `versions` and `fact_flags` produced from `responses` and `v_fact_flags`.

**Produces:** an organisation-level version badge and a “Непослідовні відповіді” section that identifies facts as claimed, not as achieved maturity.

- [ ] **Step 1: Extend the embedded fixture `DATA` with empty `versions` and `fact_flags` arrays and make the renderer tolerate an old export that lacks both fields.**
- [ ] **Step 2: Add a compact version-composition card per selected organisation.** It displays `v1.2: n` and `v2.0: n`; if both are nonzero, show the approved warning that versions are not combined into one maturity result.
- [ ] **Step 3: Add a facts section from `fact_flags`.** Group by question, display the selected higher-level facts as “заявлено, потребує верифікації”, and do not increase a score, level, or gate status.
- [ ] **Step 4: Verify the dashboard manually with fixture data containing one mixed-version organisation and one fact flag, then with the current old export.**

### Task 5: Update operations documentation and execute integration verification

**Files:**
- Modify: `README.md`
- Modify only when necessary: `docs/superpowers/specs/2026-09-04-diagnostic-v2-design.md`

- [ ] **Step 1: Update README terminology and inventory.** Describe 43 scoring/evidence questions plus six context questions, fact payload fields, coordinator-only contact flow, v1.2/v2 non-comparability, `db/migrate-v2.sql`, and the reader queries for `v_fact_flags`.
- [ ] **Step 2: Document the exact local validation order.** Generate public asset → facts/generator/helper tests → fresh schema → fixture → migration regression → static browser scenarios → dashboard fixture.
- [ ] **Step 3: Run all Node tests with `node --test 'methodology/*.test.mjs'` and `node methodology/validate-facts.mjs`.**
- [ ] **Step 4: Perform the three browser checks from Task 2 and inspect POST bodies locally.** Confirm that a respondent request contains no email/name and its `facts_flags` is present only for a broken chain.
- [ ] **Step 5: Produce an integration summary listing every automated command and the exact unperformed human actions: production database backup/migration and merge/deploy to Pages.**

## Plan self-review

- **Spec coverage:** checklist questions/chain semantics: Tasks 1–2; coordinator/copy/result: Task 2; schema/privacy: Task 3; analyst/dashboard handling: Task 4; documentation and verification: Task 5.
- **Scope:** no role routing, random ordering, weight/band/gate changes, or production actions are included.
- **Compatibility:** scoring, aggregates, Confidence and gates remain based on `answers`, so v1.2 rows retain their existing numeric results.

