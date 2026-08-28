-- AInoia AI Readiness Diagnostic — аналітичний шар
-- Реалізує §5–§9 методології v1.2: групові середні, enterprise aggregate,
-- Alignment, Confidence, evidence-статуси, maturity gates, Achieved level.
--
-- Усе рахується на сервері, бо кожна з цих величин за визначенням потребує
-- усіх респондентів організації. Браузер рахує лише власний бал респондента.

begin;

-- ---------------------------------------------------------------------------
-- Базове представлення: ефективний ключ організації з урахуванням ручного злиття
-- ---------------------------------------------------------------------------
create or replace view diagnostic.v_responses as
select r.*,
       coalesce(nullif(btrim(r.org_key_merge), ''), r.org_key) as org
from diagnostic.responses r;

-- Кандидати на злиття: різні написання, схожі ключі
create or replace view diagnostic.v_org_duplicates as
select a.org_key as key_a, min(a.org_name) as name_a,
       b.org_key as key_b, min(b.org_name) as name_b
from diagnostic.responses a
join diagnostic.responses b
  on a.org_key < b.org_key
 and (b.org_key like a.org_key || '%' or a.org_key like b.org_key || '%')
group by a.org_key, b.org_key;

-- ---------------------------------------------------------------------------
-- §4.2 Бали доменів на рівні респондента.
-- Рахуємо з answers, а не з клієнтського domains: сторінці не довіряємо.
-- ---------------------------------------------------------------------------
create or replace view diagnostic.v_domain_respondent as
select r.id, r.org, r.role_group, d.key as domain, d.ord,
       count(v.val)                       as valid_n,
       cardinality(d.items)               as items_n,
       case when count(v.val) >= d.min_valid
            then round(avg(v.val), 3) end as score
from diagnostic.v_responses r
cross join diagnostic.domains d
left join lateral (
  select (r.answers ->> i) ::numeric as val
  from unnest(d.items) as i
  where jsonb_typeof(r.answers -> i) = 'number'
) v on true
group by r.id, r.org, r.role_group, d.key, d.ord, d.items, d.min_valid;

-- ---------------------------------------------------------------------------
-- §5 крок 2: середнє по role group
-- ---------------------------------------------------------------------------
create or replace view diagnostic.v_domain_group as
select org, role_group, domain, ord,
       count(*) filter (where score is not null) as n,
       round(avg(score), 3)                      as score
from diagnostic.v_domain_respondent
group by org, role_group, domain, ord;

-- §5 крок 3: enterprise aggregate — середнє групових середніх, групи рівноважні
create or replace view diagnostic.v_domain_org as
select org, domain, ord,
       count(*) filter (where score is not null) as groups_n,
       round(avg(score), 3)                      as score
from diagnostic.v_domain_group
group by org, domain, ord;

-- Питання на рівні організації (потрібне гейтам: Q15 ≥ 3, Q38 ≥ 3 тощо)
create or replace view diagnostic.v_item_org as
with items as (select distinct unnest(items) as item from diagnostic.domains),
     per_group as (
       select r.org, r.role_group, i.item, avg((r.answers ->> i.item)::numeric) as score
       from diagnostic.v_responses r
       cross join items i
       where jsonb_typeof(r.answers -> i.item) = 'number'
       group by r.org, r.role_group, i.item)
select org, item, round(avg(score), 3) as score
from per_group group by org, item;

-- ---------------------------------------------------------------------------
-- §4.3 Зважений бал із перенормуванням ваг недостатніх доменів
-- ---------------------------------------------------------------------------
create or replace view diagnostic.v_org_score as
select o.org,
       round(sum(o.score * d.weight)
             / nullif(sum(d.weight) filter (where o.score is not null), 0), 2) as score,
       count(*) filter (where o.score is null)                                  as insufficient_domains,
       array_agg(o.domain order by o.ord) filter (where o.score is null)        as insufficient_list
from diagnostic.v_domain_org o
join diagnostic.domains d on d.key = o.domain
group by o.org;

-- §4.4 Band mapping
create or replace function diagnostic.level_of(p_score numeric)
returns smallint language sql immutable as $fn$
  select level from diagnostic.levels
  where p_score between band_low and band_high
  order by level limit 1;
$fn$;

-- ---------------------------------------------------------------------------
-- §6 Alignment Score. Тільки групи з ≥2 респондентами: один голос не має
-- права створювати «розрив сприйняття».
-- ---------------------------------------------------------------------------
create or replace view diagnostic.v_alignment as
with g as (
  select org, domain, score from diagnostic.v_domain_group
  where n >= 2 and score is not null),
gaps as (
  select org, domain, max(score) - min(score) as gap
  from g group by org, domain having count(*) >= 2)
select org,
       round(avg(gap), 3)                                        as avg_gap,
       greatest(0, least(100, round(100 - 25 * avg(gap))))::int   as alignment,
       count(*)                                                   as domains_compared
from gaps group by org;

-- Найбільші розриви — джерело executive finding
create or replace view diagnostic.v_alignment_detail as
select g.org, g.domain,
       max(g.score) filter (where g.role_group = 'executive') as executive,
       max(g.score) filter (where g.role_group = 'business')  as business,
       max(g.score) filter (where g.role_group = 'it_data')   as it_data,
       max(g.score) filter (where g.role_group = 'risk')      as risk,
       max(g.score) filter (where g.role_group = 'people')    as people,
       o.score                                                as overall,
       round(max(g.score) - min(g.score), 3)                  as gap
from diagnostic.v_domain_group g
join diagnostic.v_domain_org o using (org, domain)
where g.n >= 2 and g.score is not null
group by g.org, g.domain, g.ord, o.score
order by g.org, g.ord;

-- ---------------------------------------------------------------------------
-- §7 Assessment Confidence — чотири чинники, підсумок = найгірший
-- ---------------------------------------------------------------------------
create or replace view diagnostic.v_confidence as
with base as (
  select org,
         count(*)                                                as respondents,
         count(distinct role_group)                              as groups_n,
         avg((coalesce(c3_scope, 3) + coalesce(c4_awareness, 3)) / 2.0) as visibility
  from diagnostic.v_responses group by org),
unknowns as (
  select r.org,
         count(*)                                                             as asked,
         count(*) filter (where jsonb_typeof(r.answers -> i.item) <> 'number') as unknown
  from diagnostic.v_responses r
  join diagnostic.domains d on d.key <> 'agentic' or r.agentic_shown
  cross join lateral (select unnest(d.items) as item) i
  group by r.org),
ins as (
  select org, insufficient_domains from diagnostic.v_org_score),
f as (
  select b.org, b.respondents, b.groups_n, round(b.visibility, 2) as visibility,
         round(u.unknown::numeric / nullif(u.asked, 0), 3)        as unknown_share,
         i.insufficient_domains,
         case when b.respondents >= 8 then 3 when b.respondents >= 3 then 2 else 1 end as f_resp,
         case when b.groups_n = 5 then 3 when b.groups_n >= 3 then 2 else 1 end        as f_cover,
         case when u.unknown::numeric / nullif(u.asked, 0) < 0.15 then 3
              when u.unknown::numeric / nullif(u.asked, 0) <= 0.30 then 2 else 1 end   as f_unknown,
         case when b.visibility > 3.5 then 3 when b.visibility >= 2.5 then 2 else 1 end as f_vis,
         case when i.insufficient_domains >= 2 then 1
              when i.insufficient_domains = 1 then 2 else 3 end                        as f_domains
  from base b join unknowns u using (org) join ins i using (org))
select org, respondents, groups_n, visibility, unknown_share, insufficient_domains,
       least(f_resp, f_cover, f_unknown, f_vis, f_domains) as confidence_rank,
       case least(f_resp, f_cover, f_unknown, f_vis, f_domains)
         when 3 then 'High' when 2 then 'Medium' else 'Low' end as confidence
from f;

-- ---------------------------------------------------------------------------
-- §8 Evidence-статуси
-- ---------------------------------------------------------------------------
create or replace view diagnostic.v_evidence as
with base as (
  select r.org, q.question,
         coalesce((r.evidence -> q.question ->> 'unknown')::boolean, false) as unknown,
         coalesce(r.evidence -> q.question -> 'selected', '[]'::jsonb)      as sel
  from diagnostic.v_responses r
  cross join (values ('q5'), ('q10'), ('q25'), ('q37'), ('q43')) as q(question)),
knowers as (
  select org, question, count(*) filter (where not unknown) as knowers
  from base group by org, question),
picks as (
  select b.org, b.question, x.key, count(*) as picks
  from base b, lateral jsonb_array_elements_text(b.sel) as x(key)
  where not b.unknown
  group by b.org, b.question, x.key)
select p.org, p.question, p.key, p.picks, k.knowers,
       case when p.picks >= 2 and p.picks::numeric / nullif(k.knowers, 0) >= 0.5
              then 'confirmed'
            when p.picks >= 1 then 'claimed'
            else 'absent' end as status
from picks p join knowers k using (org, question);

-- Статус конкретного пункту; відсутній пункт = absent
create or replace function diagnostic.ev(p_org text, p_question text, p_key text)
returns text language sql stable as $fn$
  select coalesce((select status from diagnostic.v_evidence
                   where org = p_org and question = p_question and key = p_key), 'absent');
$fn$;

create or replace function diagnostic.ev_confirmed(p_org text, p_question text, p_key text)
returns boolean language sql stable as $fn$
  select diagnostic.ev(p_org, p_question, p_key) = 'confirmed';
$fn$;

create or replace function diagnostic.ev_count(p_org text, p_question text, p_status text default 'confirmed')
returns integer language sql stable as $fn$
  select count(*)::int from diagnostic.v_evidence
  where org = p_org and question = p_question and status = p_status;
$fn$;

-- Скорочення для гейтів
create or replace function diagnostic.dom(p_org text, p_domain text)
returns numeric language sql stable as $fn$
  select score from diagnostic.v_domain_org where org = p_org and domain = p_domain;
$fn$;

create or replace function diagnostic.item(p_org text, p_item text)
returns numeric language sql stable as $fn$
  select score from diagnostic.v_item_org where org = p_org and item = p_item;
$fn$;

commit;
