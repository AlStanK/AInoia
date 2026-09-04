# AI Readiness Diagnostic

Консалтинговий інструмент AInoia: multi-respondent опитування, яке визначає фактичну
позицію організації на **AInoia Evolution Path** (рівні 0–6) і те, які саме умови
переходу не виконані.

Методологія: **AI Maturity Assessment v1.2** —
`AInoia/board/04 Knowledge/wiki/AI Maturity Assessment v1.2.md`.

> Це окремий застосунок. Дипломне дослідження «Індекс ШІ-зрілості організаційної культури»
> (`Personal/learning/ai-maturity-survey`) живе своїм життям і спільного коду не має:
> у нього інший респондент, інша мета й інші дані.

---

## Що всередині

| Шлях | Призначення |
|---|---|
| `index.html` | Уся анкета: 48 питань, 9 кроків, умовний агентний блок, індивідуальний результат. Самодостатній файл — стилі й логіка вбудовані. |
| `db/schema.sql` | Схема `diagnostic`: таблиці відповідей і контактів, довідники доменів і рівнів, ролі, RLS. |
| `db/aggregate.sql` | Агрегація §5–§8: групові середні, enterprise aggregate, Alignment, Confidence, evidence-статуси. |
| `db/gates.sql` | Гейти Evolution Path §9 і підсумкове представлення `v_org_result`. |
| `db/fixture.sql` | DEV-ONLY: синтетична організація для перевірки аналітики. У продакшн не застосовувати. |
| `db/neon-grants.sql` | Insert-only права ролі `anonymous` для Neon Data API (після увімкнення Data API). |
| `db/migrate-2026-09-03-p0.sql` | Міграція для бази, накоченої до появи `org_code`, згоди і `contacts`. Свіжій базі не потрібна. |
| `.github/workflows/pages.yml` | Публікація лише статики на GitHub Pages. |
| `deploy/` | `postgrest.local.conf` для локальної перевірки; k8s-варіант (`k8s-postgrest.yaml`, `roles.sql`) як альтернатива. |

## Що рахує сторінка, а що база

Браузер рахує **лише власний бал респондента** — щоб показати результат одразу.

Все інше рахує база, бо кожна з цих величин за визначенням потребує відповідей усіх
респондентів організації: enterprise aggregate, Alignment Score, Assessment Confidence,
статуси доказів (`confirmed` / `claimed` / `absent`) і maturity gates.

Це не дублювання: серверний розрахунок є єдиним джерелом істини, клієнтський
зберігається в колонці `domains` тільки для звірки.

---

## Розгортання

Продакшн-схема: **сторінка на GitHub Pages, база й API у Neon**. Свій PostgREST не
потрібен: Neon Data API — це керований PostgREST поверх тієї ж бази.

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

Merge у `main` → workflow публікує сторінку на Pages. Сторінка позначена `noindex`.

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

---

## Як це працює для консультанта

### Запрошення і код організації

Відповіді колег зводяться в одну організацію **за кодом**, а не за назвою. Код —
8 символів без 0/O/1/I. Він зʼявляється так:

* перший респондент отримує згенерований сторінкою код і на екрані результату —
  посилання-запрошення виду `…/?org=KX7PQ2MN`, яке надсилає колегам;
* консультант може згенерувати код сам і одразу розіслати посилання команді:
  тоді всі респонденти потрапляють в одну картину без зайвих кроків.

```
https://alstank.github.io/AInoia/?org=KX7PQ2MN
```

Код із посилання не редагується. Назва організації лишається окремим полем — для
показу і для підказки при злитті: якщо колега не отримав посилання і сторінка
згенерувала йому власний код, `diagnostic.v_org_duplicates` покаже дві організації
зі схожою назвою, які варто звести через `responses.org_key_merge`.

Старі посилання з назвою (`?org=ТОВ%20«Ромашка»`) досі працюють: значення, що не
схоже на код, підставляється в поле назви.

### Контакти

Email збирається лише на екрані результату і лише з ініціативи респондента —
окремим insert у `diagnostic.contacts`, привʼязаним до `responses.id`, який
сторінка генерує сама перед POST.

```sql
select c.email, c.name, r.org_name, r.org_code, r.c1_role, r.c2_function, c.created_at
from diagnostic.contacts c join diagnostic.responses r on r.id = c.response_id
order by c.created_at desc;
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

-- Повна картина гейтів
select level, passed, failed from diagnostic.gates('ромашка');
```

`v_org_result` показує **два** рівні: `calculated_level` (з балу) і `achieved_level`
(після гейтів). Розрив між ними — не помилка, а зміст діагностики.

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
* Email збирається лише за бажанням респондента після збереження відповідей і використовується тільки для надсилання зведення.
