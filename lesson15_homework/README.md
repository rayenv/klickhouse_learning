# Домашнее задание: Репликация и удаление

## Цель
Преобразовать таблицу в реплицируемую, настроить реплики в ClickHouse и работать с данными в распределённой системе.

---

## Шаги выполнения

### 1. Создание таблицы `uk_price_paid`

Исходная таблица:

```sql
CREATE TABLE uk_price_paid (
    price UInt32,
    date Date,
    postcode1 LowCardinality(String),
    postcode2 LowCardinality(String),
    type Enum8('terraced' = 1, 'semi-detached' = 2, 'detached' = 3, 'flat' = 4, 'other' = 0),
    is_new UInt8,
    duration Enum8('freehold' = 1, 'leasehold' = 2, 'unknown' = 0),
    addr1 String,
    addr2 String,
    street LowCardinality(String),
    locality LowCardinality(String),
    town LowCardinality(String),
    district LowCardinality(String),
    county LowCardinality(String)
)
ENGINE = MergeTree
ORDER BY (postcode1, postcode2, addr1, addr2);
```

---

### 2. Заполнение таблицы данными

Заполнение таблицы данными из внешнего источника:

```sql
INSERT INTO uk_price_paid
WITH
   splitByChar(' ', postcode) AS p
SELECT
    toUInt32(price_string) AS price,
    parseDateTimeBestEffortUS(time) AS date,
    p[1] AS postcode1,
    p[2] AS postcode2,
    transform(a, ['T', 'S', 'D', 'F', 'O'], ['terraced', 'semi-detached', 'detached', 'flat', 'other']) AS type,
    b = 'Y' AS is_new,
    transform(c, ['F', 'L', 'U'], ['freehold', 'leasehold', 'unknown']) AS duration,
    addr1,
    addr2,
    street,
    locality,
    town,
    district,
    county
FROM url(
    'http://prod.publicdata.landregistry.gov.uk.s3-website-eu-west-1.amazonaws.com/pp-complete.csv',
    'CSV',
    'uuid_string String,
    price_string String,
    time String,
    postcode String,
    a String,
    b String,
    c String,
    addr1 String,
    addr2 String,
    street String,
    locality String,
    town String,
    district String,
    county String,
    d String,
    e String'
)
LIMIT 10
SETTINGS max_http_get_redirects=10;
```

---

### 3. Проверка данных в таблице

Запрос для проверки данных:

```sql
SELECT *
FROM uk_price_paid;
```

Результат запроса:

```plaintext
┌──price─┬───────date─┬─postcode1─┬─postcode2─┬─type──────────┬─is_new─┬─duration──┬─addr1───────────┬─addr2───┬─street───────────────┬─locality─────────┬─town────────────────┬─district─────────────────────┬─county───────────┐
│  63000 │ 1995-09-08 │ CA25      │ 5QH       │ semi-detached │      0 │ freehold  │ 8               │         │ CROSSINGS CLOSE      │ CLEATOR MOOR     │ CLEATOR MOOR        │ COPELAND                     │ CUMBRIA          │
│  74950 │ 1995-10-03 │ CW10      │ 9ES       │ detached      │      1 │ freehold  │ 15              │         │ SHROPSHIRE CLOSE     │ MIDDLEWICH       │ MIDDLEWICH          │ CONGLETON                    │ CHESHIRE         │
│  43000 │ 1995-12-01 │ LA6       │ 3DQ       │ terraced      │      0 │ freehold  │ 90              │         │ NEW VILLAGE          │ INGLETON         │ CARNFORTH           │ CRAVEN                       │ NORTH YORKSHIRE  │
│ 121250 │ 1995-05-19 │ N12       │ 8LR       │ flat          │      0 │ leasehold │ CAVENDISH HOUSE │ FLAT 20 │ WOODSIDE GRANGE ROAD │ LONDON           │ LONDON              │ BARNET                       │ GREATER LONDON   │
│  42000 │ 1995-12-21 │ NE4       │ 9DN       │ semi-detached │      0 │ freehold  │ 8               │         │ MATFEN PLACE         │ FENHAM           │ NEWCASTLE UPON TYNE │ NEWCASTLE UPON TYNE          │ TYNE AND WEAR    │
│  29995 │ 1995-05-12 │ PE14      │ 8JF       │ semi-detached │      0 │ freehold  │ 114             │         │ SMEETH ROAD          │ ST JOHNS FEN END │ WISBECH             │ KING'S LYNN AND WEST NORFOLK │ NORFOLK          │
│  95000 │ 1995-03-03 │ RM16      │ 4UR       │ semi-detached │      0 │ freehold  │ 30              │         │ HEATH ROAD           │ GRAYS            │ GRAYS               │ THURROCK                     │ THURROCK         │
│ 105000 │ 1995-11-30 │ S6        │ 6TG       │ detached      │      0 │ freehold  │ 70              │         │ WOODSTOCK ROAD       │ LOXLEY           │ SHEFFIELD           │ SHEFFIELD                    │ SOUTH YORKSHIRE  │
│ 128500 │ 1995-03-01 │ SW18      │ 5DH       │ terraced      │      0 │ freehold  │ 149             │         │ TRENTHAM STREET      │ LONDON           │ LONDON              │ WANDSWORTH                   │ GREATER LONDON   │
│  43500 │ 1995-11-14 │ TS23      │ 3LA       │ semi-detached │      0 │ freehold  │ 19              │         │ SLEDMERE CLOSE       │ BILLINGHAM       │ BILLINGHAM          │ STOCKTON-ON-TEES             │ STOCKTON-ON-TEES │
└────────┴────────────┴───────────┴───────────┴───────────────┴────────┴───────────┴─────────────────┴─────────┴──────────────────────┴──────────────────┴─────────────────────┴──────────────────────────────┴──────────────────┘
```

---

### 4. Конвертация таблицы в реплицируемую

Создание реплицируемой таблицы с использованием макроса `{replica}`:

```sql
CREATE TABLE uk_price_paid_repl (
    price UInt32,
    date Date,
    postcode1 LowCardinality(String),
    postcode2 LowCardinality(String),
    type Enum8('terraced' = 1, 'semi-detached' = 2, 'detached' = 3, 'flat' = 4, 'other' = 0),
    is_new UInt8,
    duration Enum8('freehold' = 1, 'leasehold' = 2, 'unknown' = 0),
    addr1 String,
    addr2 String,
    street LowCardinality(String),
    locality LowCardinality(String),
    town LowCardinality(String),
    district LowCardinality(String),
    county LowCardinality(String)
)
ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/uk_price_paid', '{replica}')
ORDER BY (postcode1, postcode2, addr1, addr2);
```

---

### 5. Добавление двух реплик

#### Реплика 1:
```sql
CREATE TABLE uk_price_paid_repl_1 (
    price UInt32,
    date Date,
    postcode1 LowCardinality(String),
    postcode2 LowCardinality(String),
    type Enum8('terraced' = 1, 'semi-detached' = 2, 'detached' = 3, 'flat' = 4, 'other' = 0),
    is_new UInt8,
    duration Enum8('freehold' = 1, 'leasehold' = 2, 'unknown' = 0),
    addr1 String,
    addr2 String,
    street LowCardinality(String),
    locality LowCardinality(String),
    town LowCardinality(String),
    district LowCardinality(String),
    county LowCardinality(String)
)
ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/uk_price_paid', 'replica_1')
ORDER BY (postcode1, postcode2, addr1, addr2);
```

#### Реплика 2:
```sql
CREATE TABLE uk_price_paid_repl_2 (
    price UInt32,
    date Date,
    postcode1 LowCardinality(String),
    postcode2 LowCardinality(String),
    type Enum8('terraced' = 1, 'semi-detached' = 2, 'detached' = 3, 'flat' = 4, 'other' = 0),
    is_new UInt8,
    duration Enum8('freehold' = 1, 'leasehold' = 2, 'unknown' = 0),
    addr1 String,
    addr2 String,
    street LowCardinality(String),
    locality LowCardinality(String),
    town LowCardinality(String),
    district LowCardinality(String),
    county LowCardinality(String)
)
ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/uk_price_paid', 'replica_2')
ORDER BY (postcode1, postcode2, addr1, addr2);
```

---

### 6. Запросы для проверки реплик

#### Запрос 1: Получение макроса `{replica}` и данных из `system.parts`
```sql
SELECT
    getMacro('replica') AS replica,
    *
FROM remote('replica_1,replica_2', system.parts)
FORMAT JSONEachRow;
```

#### Запрос 2: Получение информации о репликах из `system.replicas`
```sql
SELECT * FROM system.replicas FORMAT JSONEachRow;
```

Результаты сохранены в файлы:
- [query_1_result.json](./query_1_result.json)
- [query_2_result.json](./query_2_result.json)

---

### 7. Добавление колонки и настройка TTL

#### Добавление колонки `event_date`
```sql
ALTER TABLE uk_price_paid_repl ADD COLUMN event_date Date DEFAULT date;
```

#### Настройка TTL для хранения данных за последние 7 дней
```sql
ALTER TABLE uk_price_paid_repl MODIFY TTL event_date + INTERVAL 7 DAY;
```

---

### 8. Результат запроса `SHOW CREATE TABLE`

```sql
CREATE TABLE uk_price_paid_repl (
    price UInt32,
    date Date,
    postcode1 LowCardinality(String),
    postcode2 LowCardinality(String),
    type Enum8('terraced' = 1, 'semi-detached' = 2, 'detached' = 3, 'flat' = 4, 'other' = 0),
    is_new UInt8,
    duration Enum8('freehold' = 1, 'leasehold' = 2, 'unknown' = 0),
    addr1 String,
    addr2 String,
    street LowCardinality(String),
    locality LowCardinality(String),
    town LowCardinality(String),
    district LowCardinality(String),
    county LowCardinality(String),
    event_date Date DEFAULT date
)
ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/uk_price_paid', '{replica}')
ORDER BY (postcode1, postcode2, addr1, addr2)
TTL event_date + INTERVAL 7 DAY;
```

---

## Итог

1. Таблица `uk_price_paid` преобразована в реплицируемую.
2. Добавлены две реплики.
3. Выполнены запросы для проверки реплик.
4. Добавлена колонка `event_date` и настроен TTL для хранения данных за последние 7 дней.
5. Предоставлен результат запроса `SHOW CREATE TABLE`.

---