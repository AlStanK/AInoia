-- DEV-ONLY фікстура: синтетична організація для перевірки аналітики.
-- У продакшн-базу не застосовувати.
--
-- Сценарій навмисне відтворює типову картину: керівництво оцінює стан
-- вище, ніж контрольні функції; агентного контуру фактично немає.

begin;

create or replace function diagnostic.__seed(
  p_org text, p_group text, p_bias numeric, p_agentic boolean,
  p_ev5 text[], p_ev10 text[], p_ev25 text[], p_ev37 text[], p_ev43 text[])
returns void language plpgsql as $fn$
declare
  base jsonb := '{}'::jsonb;
  it   text;
  v    numeric;
  d    record;
begin
  for d in select key, items from diagnostic.domains loop
    if d.key = 'agentic' and not p_agentic then continue; end if;
    foreach it in array d.items loop
      v := round(least(5, greatest(1,
             case d.key
               when 'strategy'   then 3.0 when 'value'    then 2.6
               when 'adoption'   then 2.8 when 'data'     then 2.4
               when 'tech'       then 2.9 when 'people'   then 2.5
               when 'governance' then 2.3 else 1.8 end + p_bias)));
      base := base || jsonb_build_object(it, v);
    end loop;
  end loop;

  insert into diagnostic.responses
    (version, org_name, org_code, consent_at, consent_version,
     role_group, c1_role, c2_function, c3_scope, c4_awareness,
     c5_types, answers, evidence, agentic_shown, score)
  values ('1.2', p_org, upper(left(md5(diagnostic.org_key(p_org)), 8)), now(), 'fixture',
     p_group, 'Керівник підрозділу', p_group,
     case when p_group = 'executive' then 5 else 3 end,
     case when p_group = 'executive' then 4 else 3 end,
     '["public_genai","copilots"]'::jsonb, base,
     jsonb_build_object(
       'q5',  jsonb_build_object('selected', to_jsonb(p_ev5),  'unknown', false),
       'q10', jsonb_build_object('selected', to_jsonb(p_ev10), 'unknown', false),
       'q25', jsonb_build_object('selected', to_jsonb(p_ev25), 'unknown', false),
       'q37', jsonb_build_object('selected', to_jsonb(p_ev37), 'unknown', false),
       'q43', jsonb_build_object('selected', to_jsonb(p_ev43), 'unknown', not p_agentic)),
     p_agentic, null);
end;
$fn$;

-- Executive: оптимісти, бачать стратегію і власника
select diagnostic.__seed('ТОВ «Ромашка»', 'executive', 0.9, true,
  '{ai_strategy,roadmap,exec_owner,usecase_owner,budget}', '{personal,support_functions,core_business}',
  '{approved_models,iam}', '{owner,policy}', '{registry}');
select diagnostic.__seed('Ромашка', 'executive', 0.7, true,
  '{ai_strategy,exec_owner,usecase_owner}', '{personal,core_business}',
  '{approved_models}', '{owner,policy,inventory}', '{}');

-- Business: реалісти
select diagnostic.__seed('ТОВ "Ромашка"', 'business', 0.0, false,
  '{exec_owner,usecase_owner}', '{personal,support_functions}', '{approved_models}', '{policy}', '{}');
select diagnostic.__seed('ромашка', 'business', -0.1, false,
  '{exec_owner}', '{personal}', '{approved_models}', '{policy}', '{}');
select diagnostic.__seed('ТОВ Ромашка', 'business', 0.1, false,
  '{ai_strategy,exec_owner,usecase_owner}', '{personal,support_functions}', '{}', '{policy,inventory}', '{}');

-- IT/Data: бачать технічний борг
select diagnostic.__seed('ТОВ «Ромашка»', 'it_data', -0.3, true,
  '{exec_owner,budget}', '{personal,support_functions}', '{approved_models,iam,pipelines}', '{policy,inventory}', '{registry,audit_trail}');
select diagnostic.__seed('ТОВ «Ромашка»', 'it_data', -0.2, true,
  '{exec_owner}', '{personal}', '{approved_models,iam}', '{policy}', '{registry}');

-- Risk: песимісти
select diagnostic.__seed('ТОВ «Ромашка»', 'risk', -0.6, false,
  '{}', '{personal}', '{}', '{policy}', '{}');
select diagnostic.__seed('ТОВ «Ромашка»', 'risk', -0.5, false,
  '{exec_owner}', '{personal}', '{}', '{policy,inventory}', '{}');

-- People
select diagnostic.__seed('ТОВ «Ромашка»', 'people', -0.2, false,
  '{exec_owner,usecase_owner}', '{personal,support_functions}', '{}', '{policy}', '{}');

-- v2: неперервний ланцюг, розрив, «нічого з цього» та «не знаю».
insert into diagnostic.responses
  (version, org_name, org_code, consent_at, consent_version,
   role_group, c1_role, c2_function, c3_scope, c4_awareness, c5_types,
   answers, facts, facts_flags, agentic_shown)
values
  ('2.0', 'ТОВ «Факти»', 'FACTS2', now(), 'fixture',
   'business', 'Керівник підрозділу', 'business', 3, 3,
   '["public_genai"]'::jsonb,
   '{"q1":3,"q2":3,"q3":1,"q4":null}'::jsonb,
   '{"q1":{"checked":[2,3],"none":false,"unknown":false},
     "q2":{"checked":[2,3,5],"none":false,"unknown":false},
     "q3":{"checked":[],"none":true,"unknown":false},
     "q4":{"checked":[],"none":false,"unknown":true}}'::jsonb,
   '{"q2":[5]}'::jsonb,
   false);

do $$
declare r diagnostic.responses%rowtype;
begin
  select * into r from diagnostic.responses
  where org_code = 'FACTS2' and version = '2.0'
  order by created_at desc limit 1;

  if r.id is null
     or r.answers ->> 'q1' <> '3'
     or r.answers ->> 'q2' <> '3'
     or r.answers ->> 'q3' <> '1'
     or jsonb_typeof(r.answers -> 'q4') <> 'null' then
    raise exception 'v2 fixture must store answers q1=3, q2=3, q3=1, q4=json null';
  end if;
end $$;

drop function diagnostic.__seed(text, text, numeric, boolean, text[], text[], text[], text[], text[]);

commit;
