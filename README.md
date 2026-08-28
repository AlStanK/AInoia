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
| `deploy/` | PostgREST: роль `authenticator`, маніфести k8s, приклад `.env`. |

## Що рахує сторінка, а що база

Браузер рахує **лише власний бал респондента** — щоб показати результат одразу.

Все інше рахує база, бо кожна з цих величин за визначенням потребує відповідей усіх
респондентів організації: enterprise aggregate, Alignment Score, Assessment Confidence,
статуси доказів (`confirmed` / `claimed` / `absent`) і maturity gates.

Це не дублювання: серверний розрахунок є єдиним джерелом істини, клієнтський
зберігається в колонці `domains` тільки для звірки.

---

## Розгортання

### 1. База

База `poll` уже існує в кластері. Схема `diagnostic` ізольована від решти її вмісту.

```bash
export ARD_DB_URL='postgres://ПОЛЬЗУВАЧ:ПАРОЛЬ@codis-pg-rw.codis-infra.svc.cluster.local:5432/poll'

psql "$ARD_DB_URL" -v pw="'ПАРОЛЬ_AUTHENTICATOR'" -f deploy/roles.sql
psql "$ARD_DB_URL" -v ON_ERROR_STOP=1 -f db/schema.sql
psql "$ARD_DB_URL" -v ON_ERROR_STOP=1 -f db/aggregate.sql
psql "$ARD_DB_URL" -v ON_ERROR_STOP=1 -f db/gates.sql
```

Адреса кластерна, тож команди виконуються зсередини кластера або через
`kubectl port-forward -n codis-infra svc/codis-pg-rw 5432:5432`.

### 2. API

```bash
kubectl -n codis-infra create secret generic ard-postgrest \
  --from-literal=PGRST_DB_URI='postgres://authenticator:ПАРОЛЬ@codis-pg-rw:5432/poll'
kubectl -n codis-infra apply -f deploy/k8s-postgrest.yaml
```

### 3. Сторінка

У `index.html` на початку скрипта:

```js
const API_URL = "https://ard-api.codis.dev";
```

Порожній рядок = локальний режим: сторінка працює, але нічого не надсилає й пропонує
вивантажити JSON. Зручно для демонстрації клієнту без збору даних.

Хостинг — будь-яка статика під HTTPS. Сторінка позначена `noindex`.

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

## Розробка

Локальний Postgres для перевірки змін в аналітиці:

```bash
initdb -D /tmp/ard/data -U postgres --encoding=UTF8 --locale=en_US.UTF-8
pg_ctl -D /tmp/ard/data -o "-k /tmp/ard/s -h '' -p 5599" start
psql -h /tmp/ard/s -p 5599 -U postgres -c 'create database poll'
for f in db/schema.sql db/aggregate.sql db/gates.sql db/fixture.sql; do
  psql -h /tmp/ard/s -p 5599 -U postgres -d poll -v ON_ERROR_STOP=1 -f "$f"
done
psql -h /tmp/ard/s -p 5599 -U postgres -d poll -x -c 'select * from diagnostic.v_org_result'
```

Локаль обов'язково UTF-8: у C-локалі `lower()` не опускає кирилицю, і назви
організацій перестають зводитися.
