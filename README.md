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
| `db/schema.sql` | Схема `diagnostic`: таблиця відповідей, довідники доменів і рівнів, ролі, RLS. |
| `db/aggregate.sql` | Агрегація §5–§8: групові середні, enterprise aggregate, Alignment, Confidence, evidence-статуси. |
| `db/gates.sql` | Гейти Evolution Path §9 і підсумкове представлення `v_org_result`. |
| `db/fixture.sql` | DEV-ONLY: синтетична організація для перевірки аналітики. У продакшн не застосовувати. |
| `db/neon-grants.sql` | Insert-only права ролі `anonymous` для Neon Data API (після увімкнення Data API). |
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
export POLL_URL="${DATABASE_URL/\/neondb/\/poll}"   # та сама адреса, база poll
psql "$POLL_URL" -v ON_ERROR_STOP=1 -f db/schema.sql
psql "$POLL_URL" -v ON_ERROR_STOP=1 -f db/aggregate.sql
psql "$POLL_URL" -v ON_ERROR_STOP=1 -f db/gates.sql
```

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

### Запрошення

Посилання можна персоналізувати назвою організації:

```
https://diagnostic.ainoia.example/?org=ТОВ%20«Ромашка»
```

Поле лишається редагованим — це підказка, а не обмеження. Різні написання
(«ТОВ «Ромашка»», «Ромашка», «ромашка») зводяться в один ключ автоматично;
`diagnostic.v_org_duplicates` показує те, що варто звести вручну через
`responses.org_key_merge`.

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

* Роль `web_anon` має рівно одне право — `insert`. Читати не може нічого: ані чужі
  відповіді, ані перелік організацій.
* Індивідуальний результат рахується у браузері, по нього на сервер не ходять.
* Респондент бачить лише власну оцінку, з явним застереженням, що рівень організації
  рахується інакше.
* Email не збирається.
