-- AInoia AI Readiness Diagnostic — права для Neon Data API
--
-- Neon Data API — це керований PostgREST. Запит без JWT виконується роллю,
-- заданою в налаштуваннях Data API як anon role (--db-anon-role). Використовуємо
-- вбудовану роль Neon `anonymous`: вона зʼявляється в базі в момент увімкнення
-- Data API, тому цей файл застосовувати ПІСЛЯ `neon data-api create`.
--
-- Права дзеркалять web_anon зі schema.sql: рівно одна дія — вставити рядок.
-- Читати анонім не може нічого: ані чужі відповіді, ані перелік організацій.
--
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f db/neon-grants.sql

begin;

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anonymous') then
    raise exception 'Роль anonymous відсутня: спершу увімкнути Neon Data API (neon data-api create)';
  end if;
end $$;

grant usage  on schema diagnostic     to anonymous;
revoke all privileges on diagnostic.responses, diagnostic.contacts from anonymous;
grant insert on diagnostic.responses  to anonymous;
grant insert on diagnostic.contacts   to anonymous;

-- RLS увімкнено в schema.sql; політика для anonymous — така сама, як anon_insert для web_anon.
drop policy if exists anonymous_insert on diagnostic.responses;
create policy anonymous_insert on diagnostic.responses
  for insert to anonymous with check (true);

drop policy if exists anonymous_insert on diagnostic.contacts;
create policy anonymous_insert on diagnostic.contacts
  for insert to anonymous with check (true);

-- Роль authenticated (JWT-користувачі Neon Auth) тут не використовується:
-- консультант читає результати через psql роллю власника або diagnostic_reader.

commit;
