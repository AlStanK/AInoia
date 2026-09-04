-- AInoia AI Readiness Diagnostic — міграція v2.0 (2026-09-04)
-- Для бази, де вже є schema.sql v1.2 / P0. Ідемпотентна: v1.2-рядки і їх
-- числова агрегація не змінюються; нові v2-рядки додають facts/facts_flags.
--
--   psql "$POLL_URL" -v ON_ERROR_STOP=1 -f db/migrate-v2.sql
--   psql "$POLL_URL" -v ON_ERROR_STOP=1 -f db/aggregate.sql
--   psql "$POLL_URL" -v ON_ERROR_STOP=1 -f db/gates.sql
--   psql "$POLL_URL" -v ON_ERROR_STOP=1 -f db/neon-grants.sql   # якщо є Neon Data API

begin;

-- r.* у v_responses змінює порядок вихідних колонок після додавання facts.
-- Залежні view відтворюються командами aggregate.sql/gates.sql нижче в
-- інструкції; так само працює P0-міграція.
drop view if exists diagnostic.v_org_result cascade;
drop view if exists diagnostic.v_org_duplicates cascade;
drop view if exists diagnostic.v_responses cascade;

alter table diagnostic.responses
  add column if not exists facts jsonb not null default '{}'::jsonb,
  add column if not exists facts_flags jsonb not null default '{}'::jsonb;

alter table diagnostic.responses
  alter column facts set default '{}'::jsonb,
  alter column facts_flags set default '{}'::jsonb,
  alter column version set default '2.0';

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'diagnostic.responses'::regclass
      and conname = 'facts_is_object'
  ) then
    alter table diagnostic.responses
      add constraint facts_is_object check (jsonb_typeof(facts) = 'object');
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'diagnostic.responses'::regclass
      and conname = 'facts_flags_is_object'
  ) then
    alter table diagnostic.responses
      add constraint facts_flags_is_object check (jsonb_typeof(facts_flags) = 'object');
  end if;
end $$;

-- Прибираємо старий зв'язок contact -> response тільки коли відповідний
-- об'єкт існує. Після цього join контакту з роллю/відповіддю неможливий.
do $$
declare fk_name text;
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'diagnostic' and table_name = 'contacts'
      and column_name = 'response_id'
  ) then
    select c.conname into fk_name
    from pg_constraint c
    join pg_attribute a
      on a.attrelid = c.conrelid and a.attnum = any (c.conkey)
    where c.conrelid = 'diagnostic.contacts'::regclass
      and c.contype = 'f'
      and c.confrelid = 'diagnostic.responses'::regclass
      and a.attname = 'response_id'
    limit 1;

    if fk_name is not null then
      execute format('alter table diagnostic.contacts drop constraint if exists %I', fk_name);
    end if;

    if to_regclass('diagnostic.contacts_response_id_idx') is not null then
      drop index diagnostic.contacts_response_id_idx;
    end if;

    alter table diagnostic.contacts drop column response_id;
  end if;
end $$;

alter table diagnostic.contacts
  add column if not exists kind text not null default 'coordinator';
alter table diagnostic.contacts
  alter column kind set default 'coordinator',
  alter column kind set not null;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'diagnostic.contacts'::regclass
      and conname = 'contacts_kind_is_coordinator'
  ) then
    alter table diagnostic.contacts
      add constraint contacts_kind_is_coordinator
      check (kind in ('coordinator')) not valid;
  end if;
end $$;
alter table diagnostic.contacts validate constraint contacts_kind_is_coordinator;

create index if not exists contacts_org_code_idx on diagnostic.contacts (org_code);

-- Відновлюємо модель найменших привілеїв: анонімні ролі можуть лише вставити
-- рядок; читання залишається за diagnostic_reader.
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
revoke all privileges on diagnostic.responses, diagnostic.contacts from web_anon;
grant insert on diagnostic.responses, diagnostic.contacts to web_anon;
grant select on diagnostic.responses, diagnostic.contacts, diagnostic.domains, diagnostic.levels
  to diagnostic_reader;

alter table diagnostic.responses enable row level security;
alter table diagnostic.contacts enable row level security;

drop policy if exists anon_insert on diagnostic.responses;
create policy anon_insert on diagnostic.responses
  for insert to web_anon with check (true);
drop policy if exists anon_insert on diagnostic.contacts;
create policy anon_insert on diagnostic.contacts
  for insert to web_anon with check (true);

drop policy if exists reader_select on diagnostic.responses;
create policy reader_select on diagnostic.responses
  for select to diagnostic_reader using (true);
drop policy if exists reader_select on diagnostic.contacts;
create policy reader_select on diagnostic.contacts
  for select to diagnostic_reader using (true);

-- Якщо Neon Data API вже створила anonymous, синхронізуємо і її без SELECT.
do $$
begin
  if exists (select 1 from pg_roles where rolname = 'anonymous') then
    revoke all privileges on diagnostic.responses, diagnostic.contacts from anonymous;
    grant usage on schema diagnostic to anonymous;
    grant insert on diagnostic.responses, diagnostic.contacts to anonymous;

    drop policy if exists anonymous_insert on diagnostic.responses;
    create policy anonymous_insert on diagnostic.responses
      for insert to anonymous with check (true);
    drop policy if exists anonymous_insert on diagnostic.contacts;
    create policy anonymous_insert on diagnostic.contacts
      for insert to anonymous with check (true);
  end if;
end $$;

commit;
