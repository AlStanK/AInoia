-- AInoia AI Readiness Diagnostic — міграція P0 (2026-09-03)
-- Для бази, де schema.sql уже накочено до появи org_code / consent / contacts.
-- Свіжу базу створювати з schema.sql — цей файл там не потрібен.
--
--   psql "$POLL_URL" -v ON_ERROR_STOP=1 -f db/migrate-2026-09-03-p0.sql
--   psql "$POLL_URL" -v ON_ERROR_STOP=1 -f db/aggregate.sql
--   psql "$POLL_URL" -v ON_ERROR_STOP=1 -f db/gates.sql
--   psql "$POLL_URL" -v ON_ERROR_STOP=1 -f db/neon-grants.sql   # на Neon
--
-- Таблиця має бути порожньою або мати заповнені org_code/consent_at: колонки
-- додаються як NOT NULL без default, бо вигаданої згоди бути не може.

begin;

do $$
begin
  if exists (select 1 from diagnostic.responses) then
    raise exception 'diagnostic.responses не порожня: заповніть org_code і consent_at вручну перед міграцією';
  end if;
end $$;

-- Представлення залежать від org_key — знімаємо, aggregate.sql/gates.sql відтворять
drop view if exists diagnostic.v_org_result cascade;
drop view if exists diagnostic.v_org_duplicates cascade;
drop view if exists diagnostic.v_responses cascade;

alter table diagnostic.responses drop column org_key;
alter table diagnostic.responses
  add column org_code        text not null check (org_code ~ '^[A-Z0-9]{4,12}$'),
  add column org_key         text generated always as (lower(org_code)) stored,
  add column consent_at      timestamptz not null,
  add column consent_version text not null;
create index if not exists responses_org_key_idx on diagnostic.responses (org_key);

create table if not exists diagnostic.contacts (
  id              uuid primary key default gen_random_uuid(),
  created_at      timestamptz not null default now(),
  response_id     uuid        not null references diagnostic.responses (id) on delete cascade,
  org_code        text        not null check (org_code ~ '^[A-Z0-9]{4,12}$'),
  email           text        not null check (email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' and length(email) <= 254),
  name            text        check (length(name) <= 200),
  consent_version text        not null
);
create index if not exists contacts_response_id_idx on diagnostic.contacts (response_id);

grant insert on diagnostic.contacts to web_anon;
grant select on diagnostic.contacts to diagnostic_reader;
alter table diagnostic.contacts enable row level security;

drop policy if exists anon_insert on diagnostic.contacts;
create policy anon_insert on diagnostic.contacts
  for insert to web_anon with check (true);
drop policy if exists reader_select on diagnostic.contacts;
create policy reader_select on diagnostic.contacts
  for select to diagnostic_reader using (true);

commit;
