# AI Readiness Diagnostic

Консалтинговий інструмент AInoia: multi-respondent опитування з 43 scoring/evidence
питаннями і шістьма контекстними питаннями. Воно показує позицію організації на
**AInoia Evolution Path** (рівні 0–6) і те, які саме умови переходу не виконані.

Поточна методологія: **AI Maturity Assessment v2.0** — чеклист фактів для 35
scoring-питань; п'ять evidence-питань і Q15/Q20/Q30 лишаються окремими контролами.
Вихідний канон фактів — `methodology/v2-facts.json`. Відповіді v1.2 зберігаються для
історії, але не зіставляються і не об'єднуються з v2.0 в один результат зрілості.

> Це окремий застосунок. Дипломне дослідження «Індекс ШІ-зрілості організаційної культури»
> (`Personal/learning/ai-maturity-survey`) живе своїм життям і спільного коду не має:
> у нього інший респондент, інша мета й інші дані.

---

## Що всередині

| Шлях | Призначення |
|---|---|
| `index.html` | Уся анкета: 43 scoring/evidence + шість контекстних питань, дев'ять кроків, індивідуальний результат. Самодостатній файл — стилі й логіка вбудовані. |
| `db/schema.sql` | Схема `diagnostic`: таблиці відповідей і контактів, довідники доменів і рівнів, ролі, RLS. |
| `db/aggregate.sql` | Агрегація §5–§8: групові середні, enterprise aggregate, Alignment, Confidence, evidence-статуси. |
| `db/gates.sql` | Гейти Evolution Path §9 і підсумкове представлення `v_org_result`. |
| `db/fixture.sql` | DEV-ONLY: синтетична організація для перевірки аналітики. У продакшн не застосовувати. |
| `db/migrate-v2.sql` | Ідемпотентна міграція існуючої бази до v2: `version`, `facts`, `facts_flags`, контакт лише за `org_code` і `v_fact_flags`. Накочує власник вручну після бекапу. |
| `db/neon-grants.sql` | Insert-only права ролі `anonymous` для Neon Data API (після увімкнення Data API). |
| `db/migrate-2026-09-03-p0.sql` | Міграція для бази, накоченої до появи `org_code`, згоди і `contacts`. Свіжій базі не потрібна. |
| `dashboard/results-dashboard.html` | Офлайн reader export: розрахунки, склад версій і заявлені непослідовні факти. |
| `.github/workflows/pages.yml` | Публікація лише статики на GitHub Pages. |
| `deploy/` | `postgrest.local.conf` для локальної перевірки; k8s-варіант (`k8s-postgrest.yaml`, `roles.sql`) як альтернатива. |

## Що рахує сторінка, а що база

Браузер рахує **лише власний бал респондента** — щоб показати результат одразу.

Все інше рахує база, бо кожна з цих величин за визначенням потребує відповідей усіх
респондентів організації: enterprise aggregate, Alignment Score, Assessment Confidence,
статуси доказів (`confirmed` / `claimed` / `absent`) і maturity gates.

Це не дублювання: серверний розрахунок є єдиним джерелом істини, клієнтський
зберігається в колонці `domains` тільки для звірки.

Для v2 браузер передає старий числовий контракт `answers.qN` і додатково:

```json
{
  "version": "2.0",
  "facts": {"q1": {"checked": [2, 3], "none": false, "unknown": false}},
  "facts_flags": {"q1": [5]}
}
```

`facts_flags` містить лише відмічені рівні вище першого розриву в ланцюгу. Вони є
заявами для верифікації: не впливають на score, рівень, Confidence, evidence-статуси
чи gates, які й надалі розраховуються лише з `answers`.

---

## Розгортання

Продакшн-схема: **сторінка на GitHub Pages, база й API у Neon**. Свій PostgREST не
потрібен: Neon Data API — це керований PostgREST поверх тієї ж бази.

> Важливо: цей репозиторій не виконує production-міграцію або деплой автоматично.
> Власник має вручну зробити бекап, накотити `db/migrate-v2.sql`, перевірити регресію
> v1.2 і лише потім окремо змержити PR та дозволити Pages deploy.

| Шар | Де | Стан |
|---|---|---|
| Код | `github.com/AlStanK/AInoia` | main = канон, зміни через PR |
| Сторінка | `https://alstank.github.io/AInoia/` | публікує `.github/workflows/pages.yml` (лише `index.html` + `assets/`) |
| База | Neon, проєкт AInoia (`eu-central-1`), база `poll`, схема `diagnostic` | накочено `db/schema.sql`, `aggregate.sql`, `gates.sql` |
| API | Neon Data API для бази `poll` | `https://ep-orange-flower-b29e9zvj.apirest.c-6.eu-central-1.aws.neon.tech/poll/rest/v1`, анонімні запити → роль `anonymous`; Neon Auth: `https://ep-orange-flower-b29e9zvj.neonauth.c-6.eu-central-1.aws.neon.tech/poll/auth` |

### 1. База (Neon)

Пряме підключення власника (`DATABASE_URL` — див. `~/.claude/secrets-registry.md`, у git не потрапляє):

```bash
psql "$DATABASE_URL" -c 'create database poll'
POLL_URL=$(printf "%s" "$DATABASE_URL" | sed "s#/neondb?#/poll?#")   # та сама адреса, база poll
psql "$POLL_URL" -v ON_ERROR_STOP=1 -f db/schema.sql
psql "$POLL_URL" -v ON_ERROR_STOP=1 -f db/aggregate.sql
psql "$POLL_URL" -v ON_ERROR_STOP=1 -f db/gates.sql
```

Замінюється лише імʼя бази в шляху (`/neondb?` → `/poll?`), не підрядок у імені користувача. Користувача змінювати не потрібно: Neon автоматично ремапить `neondb_owner` → `poll_owner` для бази `poll`.

`db/fixture.sql` — лише для локальної перевірки аналітики, у продакшн не застосовувати.

Для вже наявної production-бази v2 не замінює попередні файли схеми. Після перевіреного
бекапу власник вручну запускає `db/migrate-v2.sql`; цей крок не виконується локальним
frontend/dashboard workflow і не є підтвердженням деплою.

### 2. API (Neon Data API)

Data API увімкнути для бази `poll` (консоль → Data API, або `neon data-api create`) з
Neon Auth як провайдером JWT. Потрібні налаштування: схема `diagnostic`, анонімна роль
`anonymous`, CORS на домен сторінки, OpenAPI вимкнено:

```bash
neon data-api create --database poll --auth-provider neon_auth \
  --db-schemas diagnostic --db-anon-role anonymous --openapi-mode disabled \
  --server-cors-allowed-origins https://alstank.github.io
```

Після цього роль `anonymous` існує в базі — дати їй insert-only права:

```bash
psql "$POLL_URL" -v ON_ERROR_STOP=1 -f db/neon-grants.sql
```

Neon Data API не приймає запити без JWT, навіть анонімні. Тому сторінка перед
відправкою бере короткоживучий анонімний токен у Neon Auth (`GET AUTH_URL/token/anonymous`)
і кладе його в `Authorization: Bearer`.

### 3. Сторінка

У `index.html` на початку скрипта:

```js
const API_URL  = "https://ep-orange-flower-b29e9zvj.apirest.c-6.eu-central-1.aws.neon.tech/poll/rest/v1";
const AUTH_URL = "https://ep-orange-flower-b29e9zvj.neonauth.c-6.eu-central-1.aws.neon.tech/poll/auth";
```

Порожній `API_URL` = локальний режим: сторінка працює, але нічого не надсилає й пропонує
вивантажити JSON. Зручно для демонстрації клієнту без збору даних. Порожній `AUTH_URL` =
токен не береться (звичайний PostgREST з анонімною роллю, як у локальній перевірці).

Після ручного merge у `main` workflow публікує сторінку на Pages. Сторінка позначена
`noindex`; merge/deploy не є частиною локальної валідації.

### Альтернатива: свій PostgREST у Kubernetes

`deploy/k8s-postgrest.yaml`, `deploy/roles.sql`, `deploy/.env.example` — варіант для
кластера з власним Postgres (роль `authenticator` → `web_anon`). Не використовується в
продакшні; ingress у маніфесті розрахований на nginx і потребує адаптації під кластер.

### Локальна перевірка наскрізь

```bash
export LC_ALL=en_US.UTF-8
initdb -D /tmp/ard/data -U postgres --encoding=UTF8 --locale=en_US.UTF-8
pg_ctl -D /tmp/ard/data -o "-c unix_socket_directories='' -c listen_addresses=127.0.0.1 -p 5599" start
psql -h 127.0.0.1 -p 5599 -U postgres -c 'create database poll'
for f in db/schema.sql db/aggregate.sql db/gates.sql db/fixture.sql; do
  psql -h 127.0.0.1 -p 5599 -U postgres -d poll -v ON_ERROR_STOP=1 -f "$f"
done
psql -h 127.0.0.1 -p 5599 -U postgres -d poll -v pw="'localtest'" -f deploy/roles.sql
postgrest deploy/postgrest.local.conf     # brew install postgrest; порт 3999, схема diagnostic, роль web_anon
```

Далі копія `index.html` з `API_URL = "http://127.0.0.1:3999"` і будь-який статичний
сервер: POST зі сторінки має повернути 201, а `select * from diagnostic.v_org_result`
— порахувати організацію. Локаль обов'язково UTF-8: у C-локалі `lower()` не опускає
кирилицю, і назви організацій перестають зводитися.

### Точний порядок локальної валідації v2

Виконуйте перевірку послідовно в disposable локальному середовищі, не в Neon:

1. Згенерувати публічний asset: `node methodology/build-v2-question-bank.mjs`.
2. Запустити facts, generator і helper тести: `node methodology/validate-facts.mjs` та
   `node --test 'methodology/*.test.mjs'`.
3. Підняти чисту схему з `db/schema.sql`, `db/aggregate.sql` і `db/gates.sql`.
4. Застосувати `db/fixture.sql`; перевірити v1.2 і v2 відповіді та `v_fact_flags`.
5. Окремо відтворити шлях міграції: зберегти JSON `v_org_result` для v1.2, накотити
   `db/migrate-v2.sql`, повторити запит і звірити ідентичність результату.
6. На локальному static server перевірити три сценарії: координатор; респондент
   `?org=ABCD1234&from=Олена`; респондент `?org=ABCD1234` без `from`.
7. У Network перевірити POST: у респондента немає email/name або POST до `contacts`, а
   `facts_flags` є лише для розірваного ланцюга фактів.
8. Відкрити dashboard з поточним старим export і з `?fixture=v2`: другий має показати
   змішані v1.2/v2.0 та один заявлений факт, перший — працювати без обох масивів.

Ці команди не авторизують production-дії. Невиконані вручну дії: backup і міграція
production-бази, merge PR та deploy на Pages.

---

## Як це працює для консультанта

### Запрошення і код організації

Відповіді колег зводяться в одну організацію **за кодом**, а не за назвою. Код —
8 символів без 0/O/1/I. Візит без `?org=` є візитом координатора: сторінка генерує код,
а після збереження дає координатору посилання для колег з `&from=`. Візит із валідним
`?org=` є візитом респондента: він не запрошує інших людей і не лишає контактні дані.

* координатор отримує згенерований сторінкою код і посилання-запрошення;
* консультант може згенерувати код сам і надіслати посилання команді;
* респонденти не бачать картки запрошення, поля імені чи email.

```
https://alstank.github.io/AInoia/?org=KX7PQ2MN&from=Олена
```

Код із посилання не редагується. Назва організації лишається окремим полем — для
показу і для підказки при злитті: якщо колега не отримав посилання і сторінка
згенерувала йому власний код, `diagnostic.v_org_duplicates` покаже дві організації
зі схожою назвою, які варто звести через `responses.org_key_merge`.

Старі посилання з назвою (`?org=ТОВ%20«Ромашка»`) досі працюють: значення, що не
схоже на код, підставляється в поле назви.

### Контакти

Email та ім'я може лишити лише координатор на екрані результату. Це окремий insert у
`diagnostic.contacts`, пов'язаний тільки через `org_code`; `response_id`, роль і функція
респондента технічно не можуть бути приєднані до контакту. Payload контакту:
`{org_code,email,name,kind:"coordinator",consent_version}`.

```sql
select org_code, email, name, kind, consent_version, created_at
from diagnostic.contacts
order by created_at desc;
```

Автопідказки наявних організацій свідомо немає: анонімний відвідувач не повинен
отримувати перелік клієнтів AInoia.

### Читання результатів

```sql
-- Головне представлення
select * from diagnostic.v_org_result;

-- Профіль за доменами і розрив між функціями
select * from diagnostic.v_alignment_detail where org = 'ромашка';

-- Що саме блокує наступний рівень
select unnest(next_level_blockers) from diagnostic.v_org_result where org = 'ромашка';

-- Заявлене, але не підтверджене іншими функціями
select question, key, picks, knowers from diagnostic.v_evidence
where org = 'ромашка' and status = 'claimed';

-- Неперервність чеклиста фактів порушена: читати лише як заявлене
select org, response_id, question, checked, flags, created_at, role_group
from diagnostic.v_fact_flags
where org = 'ромашка';

-- Два масиви для офлайн dashboard reader export
select org_key as org, version, count(*)::int as respondents
from diagnostic.responses
group by org_key, version
order by org_key, version;

select org, response_id, question, checked, flags, created_at, role_group
from diagnostic.v_fact_flags
order by org, created_at, question;

-- Повна картина гейтів
select level, passed, failed from diagnostic.gates('ромашка');
```

`v_org_result` показує **два** рівні: `calculated_level` (з балу) і `achieved_level`
(після гейтів). Розрив між ними — не помилка, а зміст діагностики.

Якщо в одній організації є рядки v1.2 і v2.0, dashboard показує їхні кількості окремо
і попереджає, що це не один порівнюваний maturity result. Не підсумовуйте й не
порівнюйте такі версії між собою.

---

## Приватність

* Перед стартом респондент бачить повідомлення про обробку даних (контролер —
  CodisLab, LLC, контакт ainoia@codislab.com;
  що збирається, навіщо, кому видно, де і скільки зберігається, права) і ставить
  явну згоду. Момент і версія тексту зберігаються в `responses.consent_at` /
  `consent_version`; при зміні тексту в `index.html` підняти `CONSENT_VERSION`.
* Роль `web_anon` (на Neon — `anonymous`) має рівно одне право — `insert` у
  `responses` і `contacts`. Читати не може нічого: ані чужі відповіді, ані перелік
  організацій.
* Індивідуальний результат рахується у браузері, по нього на сервер не ходять.
* Респондент бачить лише власну оцінку, з явним застереженням, що рівень організації
  рахується інакше.
* Email та ім'я збираються лише за бажанням координатора після збереження його відповідей
  і використовуються тільки для надсилання зведення. Респондент не бачить цих полів.
