-- AInoia AI Readiness Diagnostic — maturity gates (методологія v1.2 §9)
--
-- Джерело критеріїв — колонка «Умова переходу» моделі AInoia Evolution Path.
-- Принцип: перехід визначається доказом готовності, не календарем.
-- Гейти НЕ впливають на raw score; вони обмежують Achieved level.
-- Факти та facts_flags v2 тут навмисно не читаються: гейти використовують
-- ті самі числові answers, що й для v1.2.

begin;

-- Мінімальний бал серед доменів, що мають оцінку
create or replace function diagnostic.min_domain(p_org text)
returns numeric language sql stable as $fn$
  select min(score) from diagnostic.v_domain_org where org = p_org and score is not null;
$fn$;

-- Скільки доменів лишилися без оцінки
create or replace function diagnostic.unscored_domains(p_org text)
returns integer language sql stable as $fn$
  select count(*)::int from diagnostic.v_domain_org where org = p_org and score is null;
$fn$;

-- ---------------------------------------------------------------------------
-- Гейти по рівнях. Повертає рядок на кожен рівень 0–6 з переліком того,
-- що саме не виконано — це і є зміст розділу «умови переходу» у звіті.
--
-- NULL завжди означає «не виконано»: недостатньо даних ≠ пройдено.
-- ---------------------------------------------------------------------------
create or replace function diagnostic.gates(p_org text)
returns table (level smallint, passed boolean, failed text[])
language plpgsql stable as $fn$
declare
  f      text[];
  align  integer;
  conf   text;
begin
  select alignment  into align from diagnostic.v_alignment  where org = p_org;
  select confidence into conf  from diagnostic.v_confidence where org = p_org;

  -- Рівень 0 — базовий стан, гейтів немає
  level := 0; passed := true; failed := '{}'::text[]; return next;

  -- Рівень 1 — Безпечний перший досвід
  -- «є спонсор і готовність до малого кроку → отримано практичний результат»
  f := '{}'::text[];
  if diagnostic.ev(p_org, 'q5', 'exec_owner') = 'absent' then
    f := array_append(f, 'немає навіть заявленого AI-owner або спонсора (Q5)'); end if;
  if coalesce(diagnostic.item(p_org, 'q9'), -1) < 2 then
    f := array_append(f, 'пілоти не доходять до практичного результату (Q9 < 2)'); end if;
  if diagnostic.ev_count(p_org, 'q10', 'confirmed') + diagnostic.ev_count(p_org, 'q10', 'claimed') = 0 then
    f := array_append(f, 'немає жодного рівня з підтвердженою користю від AI (Q10)'); end if;
  level := 1; passed := cardinality(f) = 0; failed := f; return next;

  -- Рівень 2 — AI-узгодження
  -- «керівництво погодило цілі, власників і межі ризику»
  f := '{}'::text[];
  if not (diagnostic.ev_confirmed(p_org, 'q5', 'ai_strategy')
       or diagnostic.ev_confirmed(p_org, 'q5', 'roadmap')) then
    f := array_append(f, 'немає підтвердженої AI-стратегії або дорожньої карти (Q5)'); end if;
  if not diagnostic.ev_confirmed(p_org, 'q5', 'exec_owner') then
    f := array_append(f, 'Executive AI owner не підтверджений іншими функціями (Q5)'); end if;
  if not diagnostic.ev_confirmed(p_org, 'q37', 'policy') then
    f := array_append(f, 'немає підтверджених правил використання AI (Q37)'); end if;
  if coalesce(diagnostic.dom(p_org, 'strategy'), -1) < 2.5 then
    f := array_append(f, 'Strategy & Leadership < 2.5'); end if;
  level := 2; passed := cardinality(f) = 0; failed := f; return next;

  -- Рівень 3 — AI-грамотність і базове посилення
  -- «є стабільне використання і відповідальність за результат»
  f := '{}'::text[];
  if coalesce(diagnostic.dom(p_org, 'adoption'), -1) < 3.0 then
    f := array_append(f, 'Adoption < 3.0'); end if;
  if coalesce(diagnostic.item(p_org, 'q15'), -1) < 3 then
    f := array_append(f, 'менш ніж 20% релевантних користувачів працюють з AI регулярно (Q15)'); end if;
  if coalesce(diagnostic.item(p_org, 'q30'), -1) < 2 then
    f := array_append(f, 'організоване навчання пройшли менш ніж 10% релевантних працівників (Q30)'); end if;
  if not diagnostic.ev_confirmed(p_org, 'q5', 'usecase_owner') then
    f := array_append(f, 'у значущих use cases немає підтверджених власників (Q5)'); end if;
  if coalesce(diagnostic.min_domain(p_org), -1) < 2.0 then
    f := array_append(f, 'є домен нижче 2.0'); end if;
  level := 3; passed := cardinality(f) = 0; failed := f; return next;

  -- Рівень 4 — Керовані агенти
  -- «пілотні агенти дають контрольований і вимірюваний результат»
  f := '{}'::text[];
  if diagnostic.dom(p_org, 'agentic') is null then
    f := array_append(f, 'домен Agentic Operating Model не оцінений — рівні 4+ недосяжні за визначенням');
  elsif diagnostic.dom(p_org, 'agentic') < 3.0 then
    f := array_append(f, 'Agentic Operating Model < 3.0'); end if;
  if coalesce(diagnostic.item(p_org, 'q38'), -1) < 3 then
    f := array_append(f, 'агенти не виконують визначені задачі під контролем людини (Q38 < 3)'); end if;
  if coalesce(diagnostic.item(p_org, 'q41'), -1) < 3 then
    f := array_append(f, 'не визначено, де потрібне підтвердження людини (Q41 < 3)'); end if;
  if coalesce(diagnostic.item(p_org, 'q40'), -1) < 3 then
    f := array_append(f, 'немає записів дій і результатів агентів (Q40 < 3)'); end if;
  if not diagnostic.ev_confirmed(p_org, 'q43', 'registry') then
    f := array_append(f, 'немає підтвердженого реєстру агентів і власників (Q43)'); end if;
  if not diagnostic.ev_confirmed(p_org, 'q43', 'escalation') then
    f := array_append(f, 'немає підтверджених правил ескалації до людини (Q43)'); end if;
  if not diagnostic.ev_confirmed(p_org, 'q5', 'kpi') then
    f := array_append(f, 'business value системно не вимірюється (Q5: AI KPI)'); end if;
  if coalesce(diagnostic.item(p_org, 'q8'), -1) < 3 then
    f := array_append(f, 'бізнес-ефект use cases не вимірюється (Q8 < 3)'); end if;
  if not diagnostic.ev_confirmed(p_org, 'q25', 'iam') then
    f := array_append(f, 'немає підтвердженого IAM / access control для AI (Q25)'); end if;
  if not diagnostic.ev_confirmed(p_org, 'q25', 'monitoring') then
    f := array_append(f, 'немає підтвердженого logging / monitoring для AI (Q25)'); end if;
  if coalesce(diagnostic.dom(p_org, 'data'), -1) < 3.0 then
    f := array_append(f, 'Data Readiness < 3.0'); end if;
  if coalesce(diagnostic.dom(p_org, 'governance'), -1) < 3.0 then
    f := array_append(f, 'Governance, Risk & Security < 3.0'); end if;
  if diagnostic.unscored_domains(p_org) > 0 then
    f := array_append(f, 'не всі домени оцінені'); end if;
  if coalesce(diagnostic.min_domain(p_org), -1) < 2.5 then
    f := array_append(f, 'є домен нижче 2.5'); end if;
  level := 4; passed := cardinality(f) = 0; failed := f; return next;

  -- Рівень 5 — Гібридна організація
  -- «внутрішня команда здатна підтримувати модель разом з AInoia»
  f := '{}'::text[];
  if coalesce(diagnostic.dom(p_org, 'agentic'), -1) < 3.8 then
    f := array_append(f, 'Agentic Operating Model < 3.8'); end if;
  if coalesce(diagnostic.item(p_org, 'q39'), -1) < 4 then
    f := array_append(f, 'ролі агентів не формалізовані (Q39 < 4)'); end if;
  if coalesce(diagnostic.item(p_org, 'q42'), -1) < 4 then
    f := array_append(f, 'внутрішня команда не створює агентні ролі самостійно (Q42 < 4)'); end if;
  if not diagnostic.ev_confirmed(p_org, 'q43', 'owner_role') then
    f := array_append(f, 'немає підтвердженої внутрішньої ролі AI Transformation Owner (Q43)'); end if;
  if coalesce(diagnostic.item(p_org, 'q12'), -1) < 4 then
    f := array_append(f, 'end-to-end workflows не перепроєктовуються під AI (Q12 < 4)'); end if;
  if coalesce(diagnostic.item(p_org, 'q13'), -1) < 4 then
    f := array_append(f, 'немає повторюваного механізму масштабування (Q13 < 4)'); end if;
  if coalesce(diagnostic.dom(p_org, 'people'), -1) < 3.5 then
    f := array_append(f, 'People, Culture & Operating Model < 3.5'); end if;
  if diagnostic.unscored_domains(p_org) > 0 or coalesce(diagnostic.min_domain(p_org), -1) < 3.0 then
    f := array_append(f, 'не всі домени ≥ 3.0'); end if;
  if coalesce(align, -1) < 70 then
    f := array_append(f, 'Alignment < 70: функції розходяться в оцінці власного стану'); end if;
  level := 5; passed := cardinality(f) = 0; failed := f; return next;

  -- Рівень 6 — Самокерована еволюція
  -- «клієнт управляє системою без постійного ручного втручання AInoia»
  f := '{}'::text[];
  if coalesce(diagnostic.item(p_org, 'q42'), -1) < 4.5 then
    f := array_append(f, 'власники процесів не проєктують агентні ролі самостійно (Q42 < 4.5)'); end if;
  if coalesce(diagnostic.dom(p_org, 'agentic'), -1) < 4.3 then
    f := array_append(f, 'Agentic Operating Model < 4.3'); end if;
  if coalesce(diagnostic.item(p_org, 'q41'), -1) < 4 then
    f := array_append(f, 'автономія агентів не змінюється на основі доказів якості (Q41 < 4)'); end if;
  if coalesce(diagnostic.item(p_org, 'q36'), -1) < 4 then
    f := array_append(f, 'lifecycle governance не працює enterprise-wide (Q36 < 4)'); end if;
  if diagnostic.ev_count(p_org, 'q37', 'confirmed') < 8 then
    f := array_append(f, 'менше 8 підтверджених governance controls (Q37)'); end if;
  if diagnostic.unscored_domains(p_org) > 0 or coalesce(diagnostic.min_domain(p_org), -1) < 3.5 then
    f := array_append(f, 'не всі домени ≥ 3.5'); end if;
  if coalesce(diagnostic.dom(p_org, 'value'), -1) < 4.0 then
    f := array_append(f, 'Business Value < 4.0'); end if;
  if coalesce(diagnostic.dom(p_org, 'adoption'), -1) < 4.0 then
    f := array_append(f, 'Adoption < 4.0'); end if;
  if coalesce(align, -1) < 80 then
    f := array_append(f, 'Alignment < 80'); end if;
  if coalesce(conf, 'Low') <> 'High' then
    f := array_append(f, 'Assessment Confidence не High — даних недостатньо для такого твердження'); end if;
  level := 6; passed := cardinality(f) = 0; failed := f; return next;
end;
$fn$;

-- ---------------------------------------------------------------------------
-- Підсумок по організації. Головне представлення для консультанта.
--
-- Achieved level кумулятивний: найвищий рівень, для якого пройдено гейти
-- цього рівня І всіх нижчих, але не вище за Calculated level.
-- ---------------------------------------------------------------------------
create or replace view diagnostic.v_org_result as
with s as (select * from diagnostic.v_org_score),
g as (
  select o.org, gt.level, gt.passed, gt.failed
  from (select distinct org from diagnostic.v_responses) o,
       lateral diagnostic.gates(o.org) gt),
cumulative as (
  select org, level, passed,
         bool_and(passed) over (partition by org order by level
                                rows between unbounded preceding and current row) as chain
  from g),
achieved as (
  select org, max(level) filter (where chain) as gate_level from cumulative group by org)
select s.org,
       min(r.org_name)                                     as org_name,
       s.score,
       round((s.score - 1) / 4 * 100)::int                 as index_100,
       diagnostic.level_of(s.score)                        as calculated_level,
       least(diagnostic.level_of(s.score), a.gate_level)   as achieved_level,
       l.title                                             as calculated_title,
       (select title from diagnostic.levels
         where level = least(diagnostic.level_of(s.score), a.gate_level)) as achieved_title,
       c.confidence,
       c.respondents,
       c.groups_n,
       c.unknown_share,
       al.alignment,
       al.avg_gap,
       s.insufficient_domains,
       s.insufficient_list,
       (select gt.failed from diagnostic.gates(s.org) gt
         where gt.level = least(a.gate_level + 1, 6)
           and not gt.passed)                              as next_level_blockers
from s
join achieved a using (org)
join diagnostic.v_confidence c using (org)
left join diagnostic.v_alignment al using (org)
left join diagnostic.levels l on l.level = diagnostic.level_of(s.score)
join diagnostic.v_responses r on r.org = s.org
group by s.org, s.score, a.gate_level, l.title, c.confidence, c.respondents,
         c.groups_n, c.unknown_share, al.alignment, al.avg_gap,
         s.insufficient_domains, s.insufficient_list;

grant select on all tables in schema diagnostic to diagnostic_reader;
grant execute on all functions in schema diagnostic to diagnostic_reader;

commit;
