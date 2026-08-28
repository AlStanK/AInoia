-- Роль, під якою підключається PostgREST. Виконати один раз, до schema.sql.
-- Пароль підставити зі сховища секретів, у git не комітити.
--
--   psql "$SUPERUSER_URL" -v pw="'...'" -f deploy/roles.sql

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'authenticator') then
    execute format('create role authenticator login password %L', current_setting('pw', true));
  end if;
end $$;

-- authenticator не має власних прав на дані: він лише перемикається в ролі нижче
grant web_anon, diagnostic_reader to authenticator;
