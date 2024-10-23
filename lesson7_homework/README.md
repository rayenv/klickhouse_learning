# Отчет по выполнению ДЗ

## 1. Таблица `tbl1`

### Запрос:
```sql
CREATE TABLE tbl1
(
    UserID UInt64,
    PageViews UInt8,
    Duration UInt8,
    Sign Int8,
    Version UInt8
)
ENGINE = <ENGINE>
ORDER BY UserID;

INSERT INTO tbl1 VALUES (4324182021466249494, 5, 146, -1, 1);
INSERT INTO tbl1 VALUES (4324182021466249494, 5, 146, 1, 1),(4324182021466249494, 6, 185, 1, 2);

SELECT * FROM tbl1;
SELECT * FROM tbl1 FINAL;
```

### Выбор движка:
Для таблицы `tbl1` выбран движок `ReplacingMergeTree`. Этот движок подходит, так как он автоматически удаляет дубликаты (записи с одинаковым ключом сортировки) и оставляет только последнюю версию записи. В данном случае, ключом сортировки является `UserID`, а поле `Version` используется для определения последней версии записи.

### Заполненный запрос:
```sql
CREATE TABLE tbl1
(
    UserID UInt64,
    PageViews UInt8,
    Duration UInt8,
    Sign Int8,
    Version UInt8
)
ENGINE = ReplacingMergeTree
ORDER BY UserID;
```

### Результат выполнения:
- `SELECT * FROM tbl1;`
  ```
  UserID                 PageViews Duration Sign Version
  4324182021466249494    5         146      -1   1
  4324182021466249494    5         146      1    1
  4324182021466249494    6         185      1    2
  ```

- `SELECT * FROM tbl1 FINAL;`
  ```
  UserID                 PageViews Duration Sign Version
  4324182021466249494    6         185      1    2
  ```

### Объяснение:
- Без `FINAL` выводятся все записи, включая дубликаты.
- С `FINAL` выводится только последняя версия записи, где `Version = 2`.

## 2. Таблица `tbl2`

### Запрос:
```sql
CREATE TABLE tbl2
(
    key UInt32,
    value UInt32
)
ENGINE = <ENGINE>
ORDER BY key;

INSERT INTO tbl2 Values(1,1),(1,2),(2,1);

SELECT key, sum(value) FROM tbl2 GROUP BY key;
```

### Выбор движка:
Для таблицы `tbl2` выбран движок `SummingMergeTree`. Этот движок подходит для агрегации данных по ключу сортировки. В данном случае, ключом сортировки является `key`, и мы хотим агрегировать значения `value` по этому ключу.

### Заполненный запрос:
```sql
CREATE TABLE tbl2
(
    key UInt32,
    value UInt32
)
ENGINE = SummingMergeTree
ORDER BY key;
```

### Результат выполнения:
```
key value
1   3
2   1
```

### Объяснение:
- Выводятся агрегированные значения `value` по ключу `key`.

## 3. Таблица `tbl3`

### Запрос:
```sql
CREATE TABLE tbl3
(
    `id` Int32,
    `status` String,
    `price` String,
    `comment` String
)
ENGINE = <ENGINE>
PRIMARY KEY (id)
ORDER BY (id, status);

INSERT INTO tbl3 VALUES (23, 'success', '1000', 'Confirmed');
INSERT INTO tbl3 VALUES (23, 'success', '2000', 'Cancelled'); 

SELECT * from tbl3 WHERE id=23;
SELECT * from tbl3 FINAL WHERE id=23;
```

### Выбор движка:
Для таблицы `tbl3` выбран движок `ReplacingMergeTree`. Этот движок подходит для удаления дубликатов по ключу сортировки. В данном случае, ключом сортировки является `(id, status)`.

### Заполненный запрос:
```sql
CREATE TABLE tbl3
(
    `id` Int32,
    `status` String,
    `price` String,
    `comment` String
)
ENGINE = ReplacingMergeTree
PRIMARY KEY (id)
ORDER BY (id, status);
```

### Результат выполнения:
- `SELECT * from tbl3 WHERE id=23;`
  ```
  id  status  price  comment
  23  success 1000   Confirmed
  23  success 2000   Cancelled
  ```

- `SELECT * from tbl3 FINAL WHERE id=23;`
  ```
  id  status  price  comment
  23  success 2000   Cancelled
  ```

### Объяснение:
- Без `FINAL` выводятся все записи.
- С `FINAL` выводится только последняя версия записи.

## 4. Таблица `tbl4` и `tbl5`

### Запрос:
```sql
CREATE TABLE tbl4
(   CounterID UInt8,
    StartDate Date,
    UserID UInt64
) ENGINE = <ENGINE>
PARTITION BY toYYYYMM(StartDate) 
ORDER BY (CounterID, StartDate);

INSERT INTO tbl4 VALUES(0, '2019-11-11', 1);
INSERT INTO tbl4 VALUES(1, '2019-11-12', 1);

CREATE TABLE tbl5
(   CounterID UInt8,
    StartDate Date,
    UserID AggregateFunction(uniq, UInt64)
) ENGINE = <ENGINE>
PARTITION BY toYYYYMM(StartDate) 
ORDER BY (CounterID, StartDate);

INSERT INTO tbl5
select CounterID, StartDate, uniqState(UserID)
from tbl4
group by CounterID, StartDate;

INSERT INTO tbl5 VALUES (1,'2019-11-12',1);

SELECT uniqMerge(UserID) AS state 
FROM tbl5 
GROUP BY CounterID, StartDate;
```

### Выбор движка:
Для таблиц `tbl4` и `tbl5` выбран движок `MergeTree`. Этот движок подходит для хранения данных с возможностью быстрого доступа по ключу сортировки и партицирования.

### Заполненный запрос:
```sql
CREATE TABLE tbl4
(   CounterID UInt8,
    StartDate Date,
    UserID UInt64
) ENGINE = MergeTree
PARTITION BY toYYYYMM(StartDate) 
ORDER BY (CounterID, StartDate);

CREATE TABLE tbl5
(   CounterID UInt8,
    StartDate Date,
    UserID AggregateFunction(uniq, UInt64)
) ENGINE = MergeTree
PARTITION BY toYYYYMM(StartDate) 
ORDER BY (CounterID, StartDate);
```

### Результат выполнения:
- `SELECT uniqMerge(UserID) AS state FROM tbl5 GROUP BY CounterID, StartDate;`
  ```
  CounterID StartDate   state
  0         2019-11-11  1
  1         2019-11-12  1
  ```

### Объяснение:
- Выводятся уникальные значения `UserID` для каждой комбинации `CounterID` и `StartDate`.

## 5. Таблица `tbl6`

### Запрос:
```sql
CREATE TABLE tbl6
(
    `id` Int32,
    `status` String,
    `price` String,
    `comment` String,
    `sign` Int8
)
ENGINE = <ENGINE>
PRIMARY KEY (id)
ORDER BY (id, status);

INSERT INTO tbl6 VALUES (23, 'success', '1000', 'Confirmed', 1);
INSERT INTO tbl6 VALUES (23, 'success', '1000', 'Confirmed', -1), (23, 'success', '2000', 'Cancelled', 1);

SELECT * FROM tbl6;
SELECT * FROM tbl6 FINAL;
```

### Выбор движка:
Для таблицы `tbl6` выбран движок `CollapsingMergeTree`. Этот движок подходит для работы с изменяемыми данными, где записи могут быть "свернуты" (удалены) на основе значения поля `sign`. В данном случае, ключом сортировки является `(id, status)`, а поле `sign` используется для определения, какие записи должны быть удалены.

### Заполненный запрос:
```sql
CREATE TABLE tbl6
(
    `id` Int32,
    `status` String,
    `price` String,
    `comment` String,
    `sign` Int8
)
ENGINE = CollapsingMergeTree
PRIMARY KEY (id)
ORDER BY (id, status);
```

### Результат выполнения:
- `SELECT * FROM tbl6;`
  ```
  id  status  price  comment  sign
  23  success 1000   Confirmed 1
  23  success 1000   Confirmed -1
  23  success 2000   Cancelled 1
  ```

- `SELECT * FROM tbl6 FINAL;`
  ```
  id  status  price  comment  sign
  23  success 2000   Cancelled 1
  ```

### Объяснение:
- Без `FINAL` выводятся все записи, включая те, которые должны быть удалены.
- С `FINAL` выводится только оставшаяся запись после свертывания.

## Проблемы и решения

1. **Выбор движка:**
   - При выборе движка для таблицы `tbl3` возникла неоднозначность, так как в описании таблицы отсутствовало поле `sign`, которое обычно используется в движке `CollapsingMergeTree`. В итоге был выбран `ReplacingMergeTree`, так как он подходит для удаления дубликатов.

2. **Использование `FINAL`:**
   - При использовании `FINAL` в запросах к таблицам с движком `ReplacingMergeTree` и `CollapsingMergeTree` важно понимать, что это может привести к увеличению времени выполнения запроса, так как ClickHouse должен прочитать все данные и выполнить слияние.

3. **Партицирование:**
   - В таблицах `tbl4` и `tbl5` использование партицирования по месяцам (`toYYYYMM(StartDate)`) позволяет эффективно управлять данными, особенно если они имеют временную природу.

## Источники и справочные материалы

- [ClickHouse Basic Tutorial: Table Engines](https://dev.to/hoptical/clickhouse-basic-tutorial-table-engines-30i1)
- [Selecting a ClickHouse Table Engine](https://www.alibabacloud.com/blog/selecting-a-clickhouse-table-engine_597726)
- [ClickHouse Documentation: Table Engines](https://clickhouse.com/docs/en/engines/table-engines/mergetree-family/summingmergetree)

## Заключение

Выбор правильного движка таблицы в ClickHouse зависит от структуры данных и требований к их обработке. В данном ДЗ были рассмотрены различные движки, такие как `ReplacingMergeTree`, `SummingMergeTree`, `MergeTree`, и `CollapsingMergeTree`, и продемонстрировано, как они влияют на результаты запросов.