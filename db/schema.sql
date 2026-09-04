-- AInoia AI Readiness Diagnostic — схема збору відповідей
-- База: poll · схема: diagnostic · методологія: AI Maturity Assessment v2.0
--
-- Застосування:
--   psql "$DIAGNOSTIC_DATABASE_URL" -f db/schema.sql
--   psql "$DIAGNOSTIC_DATABASE_URL" -f db/aggregate.sql

begin;

create extension if not exists pgcrypto;
create schema if not exists diagnostic;

-- ---------------------------------------------------------------------------
-- Нормалізація назви організації.
-- Респондент вводить назву вільним текстом, тому «ТОВ "Ромашка"», «Ромашка»
-- і «romashka» мають зійтися в один ключ. Ідеально це не вирішується —
-- лишається ручне злиття через responses.org_key_merge (див. v_org_duplicates).
-- ---------------------------------------------------------------------------
create or replace function diagnostic.org_key(name text)
returns text language sql immutable as $fn$
  select nullif(
    regexp_replace(
      regexp_replace(
        regexp_replace(
          -- lower() для кирилиці залежить від локалі БД, тому регістр
          -- знімаємо явно: інакше «Ромашка» і «ромашка» стають різними
          -- організаціями там, де база піднята в C-локалі.
          lower(translate(coalesce(name, ''),
            'АБВГҐДЕЄЖЗИІЇЙКЛМНОПРСТУФХЦЧШЩЬЮЯЫЪЭЁ',
            'абвгґдеєжзиіїйклмнопрстуфхцчшщьюяыъэё')),
          '[''"«»„“”`´]', '', 'g'),
        '(^|[^a-zа-яіїєґ0-9])(товариство з обмеженою відповідальністю|тзов|тов|пп|фоп|прат|пат|ват|зат|дп|кп|ат|llc|ltd|limited|inc|incorporated|corp|corporation|gmbh|plc|bv)([^a-zа-яіїєґ0-9]|$)',
        '\1 \3', 'g'),
      '[^a-z0-9а-яіїєґ]+', '', 'g'),
    '');
$fn$;

comment on function diagnostic.org_key(text) is
  'Канонічний ключ організації: нижній регістр, без лапок, юр. форм і роздільників.';

-- ---------------------------------------------------------------------------
-- Відповіді. Один рядок = один респондент.
--
-- answers   {"q1": 3, "q2": null, ...}   null = «не знаю» / «свій варіант»
-- facts     {"q1": {"checked": [2,3], "none": false, "unknown": false}, ...}
-- facts_flags {"q1": [5], ...}             пропуски у ланцюгу фактів v2
-- evidence  {"q5": {"selected": ["ai_strategy"], "unknown": false}, ...}
-- free_text {"q7": "текст свого варіанту", ...}
-- domains   індивідуальні бали, які показала сторінка; зберігаються лише
--           для звірки з серверним розрахунком, аналітика їх не використовує
-- ---------------------------------------------------------------------------
create table if not exists diagnostic.responses (
  id             uuid primary key default gen_random_uuid(),
  created_at     timestamptz not null default now(),
  version        text        not null default '2.0',

  org_name       text        not null check (length(btrim(org_name)) between 2 and 200),
  -- Код організації: з посилання-запрошення консультанта або згенерований
  -- сторінкою для першого респондента. Саме він зводить відповіді колег
  -- в одну картину; назва — лише для показу і підказки при злитті.
  org_code       text        not null check (org_code ~ '^[A-Z0-9]{4,12}$'),
  org_key        text        generated always as (lower(org_code)) stored,
  org_key_merge  text,                      -- ручне злиття дублів консультантом

  role_group     text        not null
                 check (role_group in ('executive','business','it_data','risk','people')),
  c1_role        text,
  c2_function    text,
  c3_scope       smallint    check (c3_scope between 1 and 5),
  c4_awareness   smallint    check (c4_awareness between 1 and 5),
  c5_types       jsonb       not null default '[]'::jsonb,

  answers        jsonb       not null,
  facts          jsonb       not null default '{}'::jsonb,
  facts_flags    jsonb       not null default '{}'::jsonb,
  evidence       jsonb       not null default '{}'::jsonb,
  free_text      jsonb       not null default '{}'::jsonb,
  domains        jsonb       not null default '{}'::jsonb,
  score          numeric(4,2),
  agentic_shown  boolean     not null default false,

  email          text,                      -- не використовується: контакти в diagnostic.contacts
  duration_sec   integer,

  -- Згода на обробку відповідей: момент і версія тексту повідомлення
  consent_at      timestamptz not null,
  consent_version text        not null,

  constraint answers_is_object  check (jsonb_typeof(answers)  = 'object'),
  constraint facts_is_object    check (jsonb_typeof(facts) = 'object'),
  constraint facts_flags_is_object check (jsonb_typeof(facts_flags) = 'object'),
  constraint evidence_is_object check (jsonb_typeof(evidence) = 'object')
);

create index if not exists responses_org_key_idx    on diagnostic.responses (org_key);
create index if not exists responses_created_at_idx on diagnostic.responses (created_at desc);

-- ---------------------------------------------------------------------------
-- Контакти. Email лишає лише координатор після збереження відповіді. Зв'язок
-- тільки через org_code: технічно неможливо поєднати контакт з роллю чи
-- індивідуальною відповіддю.
-- ---------------------------------------------------------------------------
create table if not exists diagnostic.contacts (
  id              uuid primary key default gen_random_uuid(),
  created_at      timestamptz not null default now(),
  org_code        text        not null check (org_code ~ '^[A-Z0-9]{4,12}$'),
  kind            text        not null default 'coordinator',
  email           text        not null check (email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' and length(email) <= 254),
  name            text        check (length(name) <= 200),
  consent_version text        not null,
  constraint contacts_kind_is_coordinator check (kind in ('coordinator'))
);

create index if not exists contacts_org_code_idx on diagnostic.contacts (org_code);

-- ---------------------------------------------------------------------------
-- Довідник доменів. Ваги і склад питань — з методології v1.2 §3.
-- min_valid = max(2, ceil(items/2)) — правило достатності §4.2.
-- ---------------------------------------------------------------------------
create table if not exists diagnostic.domains (
  key       text primary key,
  ord       smallint not null,
  title     text     not null,
  weight    numeric(4,3) not null check (weight > 0),
  items     text[]   not null,
  min_valid smallint not null
);

insert into diagnostic.domains (key, ord, title, weight, items, min_valid) values
  ('strategy',   1, 'Strategy & Leadership',              0.13, '{q1,q2,q3,q4}',                     2),
  ('value',      2, 'Business Value & Use Cases',         0.18, '{q6,q7,q8,q9}',                     2),
  ('adoption',   3, 'Adoption & Process Transformation',  0.13, '{q11,q12,q13,q14,q15}',             3),
  ('data',       4, 'Data Readiness',                     0.11, '{q16,q17,q18,q19,q20}',             3),
  ('tech',       5, 'Technology & Architecture',          0.07, '{q21,q22,q23,q24}',                 2),
  ('people',     6, 'People, Culture & Operating Model',  0.14, '{q26,q27,q28,q29,q30,q31,q32}',     4),
  ('governance', 7, 'Governance, Risk & Security',        0.14, '{q33,q34,q35,q36}',                 2),
  ('agentic',    8, 'Agentic Operating Model',            0.10, '{q38,q39,q40,q41,q42}',             3)
on conflict (key) do update
  set ord = excluded.ord, title = excluded.title, weight = excluded.weight,
      items = excluded.items, min_valid = excluded.min_valid;

-- Ваги мусять давати рівно 1.000
do $$
declare s numeric;
begin
  select sum(weight) into s from diagnostic.domains;
  if s <> 1.000 then
    raise exception 'Сума ваг доменів = %, має бути 1.000', s;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Рівні AInoia Evolution Path
-- ---------------------------------------------------------------------------
create table if not exists diagnostic.levels (
  level     smallint primary key check (level between 0 and 6),
  title     text not null,
  band_low  numeric(3,2) not null,
  band_high numeric(3,2) not null
);

insert into diagnostic.levels (level, title, band_low, band_high) values
  (0, 'AI-хаос і перевантаження',        1.00, 1.49),
  (1, 'Безпечний перший досвід',         1.50, 1.99),
  (2, 'AI-узгодження',                   2.00, 2.49),
  (3, 'AI-грамотність і базове посилення',2.50, 3.19),
  (4, 'Керовані агенти',                 3.20, 3.79),
  (5, 'Гібридна організація',            3.80, 4.39),
  (6, 'Самокерована еволюція',           4.40, 5.00)
on conflict (level) do update
  set title = excluded.title, band_low = excluded.band_low, band_high = excluded.band_high;

-- ---------------------------------------------------------------------------
-- Доступи.
--
-- web_anon має рівно одне право: вставити рядок. Читати не може нічого —
-- ані чужі відповіді, ані перелік організацій. Індивідуальний результат
-- сторінка рахує у браузері й на сервер по нього не ходить.
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'web_anon') then
    create role web_anon nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'diagnostic_reader') then
    create role diagnostic_reader nologin;
  end if;
end $$;

grant usage on schema diagnostic to web_anon, diagnostic_reader;
grant insert on diagnostic.responses, diagnostic.contacts to web_anon;
grant select on diagnostic.responses, diagnostic.contacts, diagnostic.domains, diagnostic.levels
  to diagnostic_reader;

alter table diagnostic.responses enable row level security;
alter table diagnostic.contacts  enable row level security;

drop policy if exists anon_insert on diagnostic.responses;
create policy anon_insert on diagnostic.responses
  for insert to web_anon with check (true);

drop policy if exists reader_select on diagnostic.responses;
create policy reader_select on diagnostic.responses
  for select to diagnostic_reader using (true);

drop policy if exists anon_insert on diagnostic.contacts;
create policy anon_insert on diagnostic.contacts
  for insert to web_anon with check (true);

drop policy if exists reader_select on diagnostic.contacts;
create policy reader_select on diagnostic.contacts
  for select to diagnostic_reader using (true);

commit;
