# Если вы это смотрите, значит у вас есть время на кое что забавное =)
## Результат выполнения скрипта для перебора движков и сравнения результатов

 Тут же лежит [чудо скрипт](./check_engine.sh) не претендующий ни на оригинальность, ни на оптимизацию выполняемых функций 

## Вывод result_log
 cat result_log
```bash
Testing tbl1 with engine: MergeTree
Without FINAL:
4324182021466249494     5       146     1       1
4324182021466249494     6       185     1       2
4324182021466249494     5       146     -1      1
With FINAL:
Testing tbl1 with engine: ReplacingMergeTree
Without FINAL:
4324182021466249494     6       185     1       2
4324182021466249494     5       146     -1      1
With FINAL:
4324182021466249494     6       185     1       2
Testing tbl1 with engine: SummingMergeTree
Without FINAL:
4324182021466249494     11      75      2       3
4324182021466249494     5       146     -1      1
With FINAL:
4324182021466249494     16      221     1       4
Testing tbl1 with engine: CollapsingMergeTree
Without FINAL:
With FINAL:
Testing tbl2 with engine: MergeTree
Aggregated data:
2       1
1       3
Testing tbl2 with engine: ReplacingMergeTree
Aggregated data:
2       1
1       2
Testing tbl2 with engine: SummingMergeTree
Aggregated data:
2       1
1       3
Testing tbl2 with engine: CollapsingMergeTree
Aggregated data:
Testing tbl3 with engine: MergeTree
Without FINAL:
23      success 2000    Cancelled
23      success 1000    Confirmed
With FINAL:
Testing tbl3 with engine: ReplacingMergeTree
Without FINAL:
23      success 1000    Confirmed
23      success 2000    Cancelled
With FINAL:
23      success 2000    Cancelled
Testing tbl3 with engine: SummingMergeTree
Without FINAL:
23      success 1000    Confirmed
23      success 2000    Cancelled
With FINAL:
23      success 1000    Confirmed
Testing tbl3 with engine: CollapsingMergeTree
Without FINAL:
With FINAL:
Testing tbl4 and tbl5 with engine: MergeTree
Aggregated data:
1
1
Testing tbl4 and tbl5 with engine: ReplacingMergeTree
Aggregated data:
1
1
Testing tbl4 and tbl5 with engine: SummingMergeTree
Aggregated data:
1
1
Testing tbl4 and tbl5 with engine: CollapsingMergeTree
Aggregated data:
Testing tbl6 with engine: MergeTree
Without FINAL:
23      success 1000    Confirmed       -1
23      success 2000    Cancelled       1
23      success 1000    Confirmed       1
With FINAL:
Testing tbl6 with engine: ReplacingMergeTree
Without FINAL:
23      success 1000    Confirmed       1
23      success 2000    Cancelled       1
With FINAL:
23      success 2000    Cancelled       1
Testing tbl6 with engine: SummingMergeTree
Without FINAL:
23      success 1000    Confirmed       1
With FINAL:
23      success 1000    Confirmed       1
Testing tbl6 with engine: CollapsingMergeTree
Without FINAL:
With FINAL:
```

## Логи терминала
./check_engine.sh > result_log

```plaintext
Received exception from server (version 24.9.2):
Code: 181. DB::Exception: Received from localhost:9000. DB::Exception: Storage MergeTree doesn't support FINAL. (ILLEGAL_FINAL)
(query: SELECT * FROM tbl1 FINAL;)
Received exception from server (version 24.9.2):
Code: 42. DB::Exception: Received from localhost:9000. DB::Exception: With extended storage definition syntax storage CollapsingMergeTree requires 1 parameters:
sign column

Syntax for the MergeTree table engine:

CREATE TABLE [IF NOT EXISTS] [db.]table_name [ON CLUSTER cluster]
(
    name1 [type1] [DEFAULT|MATERIALIZED|ALIAS expr1] [TTL expr1],
    name2 [type2] [DEFAULT|MATERIALIZED|ALIAS expr2] [TTL expr2],
    ...
    INDEX index_name1 expr1 TYPE type1(...) [GRANULARITY value1],
    INDEX index_name2 expr2 TYPE type2(...) [GRANULARITY value2]
) ENGINE = MergeTree()
ORDER BY expr
[PARTITION BY expr]
[PRIMARY KEY expr]
[SAMPLE BY expr]
[TTL expr [DELETE|TO DISK 'xxx'|TO VOLUME 'xxx'], ...]
[SETTINGS name=value, ...]
[COMMENT 'comment']

See details in documentation: https://clickhouse.com/docs/en/engines/table-engines/mergetree-family/mergetree/. Other engines of the family support different syntax, see details in the corresponding documentation topics.

If you use the Replicated version of engines, see https://clickhouse.com/docs/en/engines/table-engines/mergetree-family/replication/.
. (NUMBER_OF_ARGUMENTS_DOESNT_MATCH)
(query: CREATE TABLE tbl1
    (
        UserID UInt64,
        PageViews UInt8,
        Duration UInt8,
        Sign Int8,
        Version UInt8
    )
    ENGINE = CollapsingMergeTree
    ORDER BY UserID;)
Received exception from server (version 24.9.2):
Code: 60. DB::Exception: Received from localhost:9000. DB::Exception: Table default.tbl1 does not exist. (UNKNOWN_TABLE)
(query: INSERT INTO tbl1 VALUES (4324182021466249494, 5, 146, -1, 1);)
Received exception from server (version 24.9.2):
Code: 60. DB::Exception: Received from localhost:9000. DB::Exception: Unknown table expression identifier 'tbl1' in scope SELECT * FROM tbl1. (UNKNOWN_TABLE)
(query: SELECT * FROM tbl1;)
Received exception from server (version 24.9.2):
Code: 60. DB::Exception: Received from localhost:9000. DB::Exception: Unknown table expression identifier 'tbl1' in scope SELECT * FROM tbl1 FINAL. (UNKNOWN_TABLE)
(query: SELECT * FROM tbl1 FINAL;)
Received exception from server (version 24.9.2):
Code: 60. DB::Exception: Received from localhost:9000. DB::Exception: Table default.tbl1 does not exist. (UNKNOWN_TABLE)
(query: DROP TABLE tbl1;)
Received exception from server (version 24.9.2):
Code: 42. DB::Exception: Received from localhost:9000. DB::Exception: With extended storage definition syntax storage CollapsingMergeTree requires 1 parameters:
sign column

Syntax for the MergeTree table engine:

CREATE TABLE [IF NOT EXISTS] [db.]table_name [ON CLUSTER cluster]
(
    name1 [type1] [DEFAULT|MATERIALIZED|ALIAS expr1] [TTL expr1],
    name2 [type2] [DEFAULT|MATERIALIZED|ALIAS expr2] [TTL expr2],
    ...
    INDEX index_name1 expr1 TYPE type1(...) [GRANULARITY value1],
    INDEX index_name2 expr2 TYPE type2(...) [GRANULARITY value2]
) ENGINE = MergeTree()
ORDER BY expr
[PARTITION BY expr]
[PRIMARY KEY expr]
[SAMPLE BY expr]
[TTL expr [DELETE|TO DISK 'xxx'|TO VOLUME 'xxx'], ...]
[SETTINGS name=value, ...]
[COMMENT 'comment']

See details in documentation: https://clickhouse.com/docs/en/engines/table-engines/mergetree-family/mergetree/. Other engines of the family support different syntax, see details in the corresponding documentation topics.

If you use the Replicated version of engines, see https://clickhouse.com/docs/en/engines/table-engines/mergetree-family/replication/.
. (NUMBER_OF_ARGUMENTS_DOESNT_MATCH)
(query: CREATE TABLE tbl2
    (
        key UInt32,
        value UInt32
    )
    ENGINE = CollapsingMergeTree
    ORDER BY key;)
Received exception from server (version 24.9.2):
Code: 60. DB::Exception: Received from localhost:9000. DB::Exception: Table default.tbl2 does not exist. (UNKNOWN_TABLE)
(query: INSERT INTO tbl2 Values(1,1),(1,2),(2,1);)
Received exception from server (version 24.9.2):
Code: 60. DB::Exception: Received from localhost:9000. DB::Exception: Unknown table expression identifier 'tbl2' in scope SELECT key, sum(value) FROM tbl2 GROUP BY key. (UNKNOWN_TABLE)
(query: SELECT key, sum(value) FROM tbl2 GROUP BY key;)
Received exception from server (version 24.9.2):
Code: 60. DB::Exception: Received from localhost:9000. DB::Exception: Table default.tbl2 does not exist. (UNKNOWN_TABLE)
(query: DROP TABLE tbl2;)
Received exception from server (version 24.9.2):
Code: 181. DB::Exception: Received from localhost:9000. DB::Exception: Storage MergeTree doesn't support FINAL. (ILLEGAL_FINAL)
(query: SELECT * from tbl3 FINAL WHERE id=23;)
Received exception from server (version 24.9.2):
Code: 42. DB::Exception: Received from localhost:9000. DB::Exception: With extended storage definition syntax storage CollapsingMergeTree requires 1 parameters:
sign column

Syntax for the MergeTree table engine:

CREATE TABLE [IF NOT EXISTS] [db.]table_name [ON CLUSTER cluster]
(
    name1 [type1] [DEFAULT|MATERIALIZED|ALIAS expr1] [TTL expr1],
    name2 [type2] [DEFAULT|MATERIALIZED|ALIAS expr2] [TTL expr2],
    ...
    INDEX index_name1 expr1 TYPE type1(...) [GRANULARITY value1],
    INDEX index_name2 expr2 TYPE type2(...) [GRANULARITY value2]
) ENGINE = MergeTree()
ORDER BY expr
[PARTITION BY expr]
[PRIMARY KEY expr]
[SAMPLE BY expr]
[TTL expr [DELETE|TO DISK 'xxx'|TO VOLUME 'xxx'], ...]
[SETTINGS name=value, ...]
[COMMENT 'comment']

See details in documentation: https://clickhouse.com/docs/en/engines/table-engines/mergetree-family/mergetree/. Other engines of the family support different syntax, see details in the corresponding documentation topics.

If you use the Replicated version of engines, see https://clickhouse.com/docs/en/engines/table-engines/mergetree-family/replication/.
. (NUMBER_OF_ARGUMENTS_DOESNT_MATCH)
(query: CREATE TABLE tbl3
    (
        `id` Int32,
        `status` String,
        `price` String,
        `comment` String
    )
    ENGINE = CollapsingMergeTree
    PRIMARY KEY (id)
    ORDER BY (id, status);)
Received exception from server (version 24.9.2):
Code: 60. DB::Exception: Received from localhost:9000. DB::Exception: Table default.tbl3 does not exist. (UNKNOWN_TABLE)
(query: INSERT INTO tbl3 VALUES (23, 'success', '1000', 'Confirmed');)
Received exception from server (version 24.9.2):
Code: 60. DB::Exception: Received from localhost:9000. DB::Exception: Unknown table expression identifier 'tbl3' in scope SELECT * FROM tbl3 WHERE id = 23. (UNKNOWN_TABLE)
(query: SELECT * from tbl3 WHERE id=23;)
Received exception from server (version 24.9.2):
Code: 60. DB::Exception: Received from localhost:9000. DB::Exception: Unknown table expression identifier 'tbl3' in scope SELECT * FROM tbl3 FINAL WHERE id = 23. (UNKNOWN_TABLE)
(query: SELECT * from tbl3 FINAL WHERE id=23;)
Received exception from server (version 24.9.2):
Code: 60. DB::Exception: Received from localhost:9000. DB::Exception: Table default.tbl3 does not exist. (UNKNOWN_TABLE)
(query: DROP TABLE tbl3;)
Error on processing query: Code: 53. DB::Exception: Cannot convert UInt64 to AggregateFunction(uniq, UInt64): While executing ValuesBlockInputFormat: data for INSERT was parsed from query. (TYPE_MISMATCH) (version 24.9.2.42 (official build))
(query: INSERT INTO tbl5 VALUES (1,'2019-11-12',1);)
Error on processing query: Code: 53. DB::Exception: Cannot convert UInt64 to AggregateFunction(uniq, UInt64): While executing ValuesBlockInputFormat: data for INSERT was parsed from query. (TYPE_MISMATCH) (version 24.9.2.42 (official build))
(query: INSERT INTO tbl5 VALUES (1,'2019-11-12',1);)
Error on processing query: Code: 53. DB::Exception: Cannot convert UInt64 to AggregateFunction(uniq, UInt64): While executing ValuesBlockInputFormat: data for INSERT was parsed from query. (TYPE_MISMATCH) (version 24.9.2.42 (official build))
(query: INSERT INTO tbl5 VALUES (1,'2019-11-12',1);)
Received exception from server (version 24.9.2):
Code: 42. DB::Exception: Received from localhost:9000. DB::Exception: With extended storage definition syntax storage CollapsingMergeTree requires 1 parameters:
sign column

Syntax for the MergeTree table engine:

CREATE TABLE [IF NOT EXISTS] [db.]table_name [ON CLUSTER cluster]
(
    name1 [type1] [DEFAULT|MATERIALIZED|ALIAS expr1] [TTL expr1],
    name2 [type2] [DEFAULT|MATERIALIZED|ALIAS expr2] [TTL expr2],
    ...
    INDEX index_name1 expr1 TYPE type1(...) [GRANULARITY value1],
    INDEX index_name2 expr2 TYPE type2(...) [GRANULARITY value2]
) ENGINE = MergeTree()
ORDER BY expr
[PARTITION BY expr]
[PRIMARY KEY expr]
[SAMPLE BY expr]
[TTL expr [DELETE|TO DISK 'xxx'|TO VOLUME 'xxx'], ...]
[SETTINGS name=value, ...]
[COMMENT 'comment']

See details in documentation: https://clickhouse.com/docs/en/engines/table-engines/mergetree-family/mergetree/. Other engines of the family support different syntax, see details in the corresponding documentation topics.

If you use the Replicated version of engines, see https://clickhouse.com/docs/en/engines/table-engines/mergetree-family/replication/.
. (NUMBER_OF_ARGUMENTS_DOESNT_MATCH)
(query: CREATE TABLE tbl4
    (   CounterID UInt8,
        StartDate Date,
        UserID UInt64
    ) ENGINE = CollapsingMergeTree
    PARTITION BY toYYYYMM(StartDate)
    ORDER BY (CounterID, StartDate);)
Received exception from server (version 24.9.2):
Code: 60. DB::Exception: Received from localhost:9000. DB::Exception: Table default.tbl4 does not exist. (UNKNOWN_TABLE)
(query: INSERT INTO tbl4 VALUES(0, '2019-11-11', 1);)
Received exception from server (version 24.9.2):
Code: 42. DB::Exception: Received from localhost:9000. DB::Exception: With extended storage definition syntax storage CollapsingMergeTree requires 1 parameters:
sign column

Syntax for the MergeTree table engine:

CREATE TABLE [IF NOT EXISTS] [db.]table_name [ON CLUSTER cluster]
(
    name1 [type1] [DEFAULT|MATERIALIZED|ALIAS expr1] [TTL expr1],
    name2 [type2] [DEFAULT|MATERIALIZED|ALIAS expr2] [TTL expr2],
    ...
    INDEX index_name1 expr1 TYPE type1(...) [GRANULARITY value1],
    INDEX index_name2 expr2 TYPE type2(...) [GRANULARITY value2]
) ENGINE = MergeTree()
ORDER BY expr
[PARTITION BY expr]
[PRIMARY KEY expr]
[SAMPLE BY expr]
[TTL expr [DELETE|TO DISK 'xxx'|TO VOLUME 'xxx'], ...]
[SETTINGS name=value, ...]
[COMMENT 'comment']

See details in documentation: https://clickhouse.com/docs/en/engines/table-engines/mergetree-family/mergetree/. Other engines of the family support different syntax, see details in the corresponding documentation topics.

If you use the Replicated version of engines, see https://clickhouse.com/docs/en/engines/table-engines/mergetree-family/replication/.
. (NUMBER_OF_ARGUMENTS_DOESNT_MATCH)
(query: CREATE TABLE tbl5
    (   CounterID UInt8,
        StartDate Date,
        UserID AggregateFunction(uniq, UInt64)
    ) ENGINE = CollapsingMergeTree
    PARTITION BY toYYYYMM(StartDate)
    ORDER BY (CounterID, StartDate);)
Received exception from server (version 24.9.2):
Code: 60. DB::Exception: Received from localhost:9000. DB::Exception: Table default.tbl5 does not exist. (UNKNOWN_TABLE)
(query: INSERT INTO tbl5
    select CounterID, StartDate, uniqState(UserID)
    from tbl4
    group by CounterID, StartDate;)
Received exception from server (version 24.9.2):
Code: 60. DB::Exception: Received from localhost:9000. DB::Exception: Unknown table expression identifier 'tbl5' in scope SELECT uniqMerge(UserID) AS state FROM tbl5 GROUP BY CounterID, StartDate. (UNKNOWN_TABLE)
(query: SELECT uniqMerge(UserID) AS state FROM tbl5 GROUP BY CounterID, StartDate;)
Received exception from server (version 24.9.2):
Code: 60. DB::Exception: Received from localhost:9000. DB::Exception: Table default.tbl4 does not exist. (UNKNOWN_TABLE)
(query: DROP TABLE tbl4;)
Received exception from server (version 24.9.2):
Code: 60. DB::Exception: Received from localhost:9000. DB::Exception: Table default.tbl5 does not exist. (UNKNOWN_TABLE)
(query: DROP TABLE tbl5;)
Received exception from server (version 24.9.2):
Code: 181. DB::Exception: Received from localhost:9000. DB::Exception: Storage MergeTree doesn't support FINAL. (ILLEGAL_FINAL)
(query: SELECT * FROM tbl6 FINAL;)
Received exception from server (version 24.9.2):
Code: 42. DB::Exception: Received from localhost:9000. DB::Exception: With extended storage definition syntax storage CollapsingMergeTree requires 1 parameters:
sign column

Syntax for the MergeTree table engine:

CREATE TABLE [IF NOT EXISTS] [db.]table_name [ON CLUSTER cluster]
(
    name1 [type1] [DEFAULT|MATERIALIZED|ALIAS expr1] [TTL expr1],
    name2 [type2] [DEFAULT|MATERIALIZED|ALIAS expr2] [TTL expr2],
    ...
    INDEX index_name1 expr1 TYPE type1(...) [GRANULARITY value1],
    INDEX index_name2 expr2 TYPE type2(...) [GRANULARITY value2]
) ENGINE = MergeTree()
ORDER BY expr
[PARTITION BY expr]
[PRIMARY KEY expr]
[SAMPLE BY expr]
[TTL expr [DELETE|TO DISK 'xxx'|TO VOLUME 'xxx'], ...]
[SETTINGS name=value, ...]
[COMMENT 'comment']

See details in documentation: https://clickhouse.com/docs/en/engines/table-engines/mergetree-family/mergetree/. Other engines of the family support different syntax, see details in the corresponding documentation topics.

If you use the Replicated version of engines, see https://clickhouse.com/docs/en/engines/table-engines/mergetree-family/replication/.
. (NUMBER_OF_ARGUMENTS_DOESNT_MATCH)
(query: CREATE TABLE tbl6
    (
        `id` Int32,
        `status` String,
        `price` String,
        `comment` String,
        `sign` Int8
    )
    ENGINE = CollapsingMergeTree
    PRIMARY KEY (id)
    ORDER BY (id, status);)
Received exception from server (version 24.9.2):
Code: 60. DB::Exception: Received from localhost:9000. DB::Exception: Table default.tbl6 does not exist. (UNKNOWN_TABLE)
(query: INSERT INTO tbl6 VALUES (23, 'success', '1000', 'Confirmed', 1);)
Received exception from server (version 24.9.2):
Code: 60. DB::Exception: Received from localhost:9000. DB::Exception: Unknown table expression identifier 'tbl6' in scope SELECT * FROM tbl6. (UNKNOWN_TABLE)
(query: SELECT * FROM tbl6;)
Received exception from server (version 24.9.2):
Code: 60. DB::Exception: Received from localhost:9000. DB::Exception: Unknown table expression identifier 'tbl6' in scope SELECT * FROM tbl6 FINAL. (UNKNOWN_TABLE)
(query: SELECT * FROM tbl6 FINAL;)
Received
```
## 

1. **Ошибки при использовании `CollapsingMergeTree`:**
   - Движок `CollapsingMergeTree` требует указания столбца `sign`, который отвечает за определение, какие записи должны быть удалены. В скрипте этот столбец не был указан, что привело к ошибкам.

2. **Ошибки при использовании `FINAL`:**
   - Движок `MergeTree` не поддерживает ключевое слово `FINAL`, что привело к ошибкам при попытке выполнить запросы с `FINAL`.

3. **Типичные ошибки:**
   - `ILLEGAL_FINAL`: Движок `MergeTree` не поддерживает `FINAL`.
   - `NUMBER_OF_ARGUMENTS_DOESNT_MATCH`: Движок `CollapsingMergeTree` требует указания столбца `sign`.
   - `UNKNOWN_TABLE`: Таблица не была создана или уже была удалена.
   - `TYPE_MISMATCH`: Несоответствие типов данных при вставке значений в столбец с типом `AggregateFunction`.

## Результаты для каждой таблицы:

### Таблица `tbl1`:
- **MergeTree:**
  - Без `FINAL`: Выводятся все записи.
  - С `FINAL`: Ошибка `ILLEGAL_FINAL`.
- **ReplacingMergeTree:**
  - Без `FINAL`: Выводятся все записи.
  - С `FINAL`: Выводится только последняя версия записи.
- **SummingMergeTree:**
  - Без `FINAL`: Выводятся агрегированные значения.
  - С `FINAL`: Выводятся агрегированные значения.
- **CollapsingMergeTree:**
  - Без `FINAL`: Ошибка `NUMBER_OF_ARGUMENTS_DOESNT_MATCH`.
  - С `FINAL`: Ошибка `NUMBER_OF_ARGUMENTS_DOESNT_MATCH`.

### Таблица `tbl2`:
- **MergeTree:**
  - Агрегированные данные: Выводятся агрегированные значения.
- **ReplacingMergeTree:**
  - Агрегированные данные: Выводятся агрегированные значения.
- **SummingMergeTree:**
  - Агрегированные данные: Выводятся агрегированные значения.
- **CollapsingMergeTree:**
  - Агрегированные данные: Ошибка `NUMBER_OF_ARGUMENTS_DOESNT_MATCH`.

### Таблица `tbl3`:
- **MergeTree:**
  - Без `FINAL`: Выводятся все записи.
  - С `FINAL`: Ошибка `ILLEGAL_FINAL`.
- **ReplacingMergeTree:**
  - Без `FINAL`: Выводятся все записи.
  - С `FINAL`: Выводится только последняя версия записи.
- **SummingMergeTree:**
  - Без `FINAL`: Выводятся все записи.
  - С `FINAL`: Выводятся все записи.
- **CollapsingMergeTree:**
  - Без `FINAL`: Ошибка `NUMBER_OF_ARGUMENTS_DOESNT_MATCH`.
  - С `FINAL`: Ошибка `NUMBER_OF_ARGUMENTS_DOESNT_MATCH`.

### Таблицы `tbl4` и `tbl5`:
- **MergeTree:**
  - Агрегированные данные: Выводятся агрегированные значения.
- **ReplacingMergeTree:**
  - Агрегированные данные: Выводятся агрегированные значения.
- **SummingMergeTree:**
  - Агрегированные данные: Выводятся агрегированные значения.
- **CollapsingMergeTree:**
  - Агрегированные данные: Ошибка `NUMBER_OF_ARGUMENTS_DOESNT_MATCH`.

### Таблица `tbl6`:
- **MergeTree:**
  - Без `FINAL`: Выводятся все записи.
  - С `FINAL`: Ошибка `ILLEGAL_FINAL`.
- **ReplacingMergeTree:**
  - Без `FINAL`: Выводятся все записи.
  - С `FINAL`: Выводится только последняя версия записи.
- **SummingMergeTree:**
  - Без `FINAL`: Выводятся все записи.
  - С `FINAL`: Выводятся все записи.
- **CollapsingMergeTree:**
  - Без `FINAL`: Ошибка `NUMBER_OF_ARGUMENTS_DOESNT_MATCH`.
  - С `FINAL`: Ошибка `NUMBER_OF_ARGUMENTS_DOESNT_MATCH`.

## Выводы:

1. **Движок `ReplacingMergeTree`:**
   - Подходит для таблиц, где требуется удаление дубликатов и выборка последней версии записи.
   - Поддерживает ключевое слово `FINAL`.

2. **Движок `SummingMergeTree`:**
   - Подходит для таблиц, где требуется агрегация данных.
   - Не поддерживает ключевое слово `FINAL`.

3. **Движок `MergeTree`:**
   - Подходит для базовых таблиц без агрегации и удаления дубликатов.
   - Не поддерживает ключевое слово `FINAL`.

4. **Движок `CollapsingMergeTree`:**
   - Требует указания столбца `sign` для работы.
   - Не поддерживает ключевое слово `FINAL` без указания столбца `sign`.

## Рекомендации:

- Для таблиц `tbl1`, `tbl3` и `tbl6`, где требуется удаление дубликатов и выборка последней версии записи, рекомендуется использовать `ReplacingMergeTree`.
- Для таблиц `tbl2`, `tbl4` и `tbl5`, где требуется агрегация данных, рекомендуется использовать `SummingMergeTree`.
- Для базовых таблиц без особых требований к агрегации и удалению дубликатов, можно использовать `MergeTree`.
- При использовании `CollapsingMergeTree` необходимо указывать столбец `sign` и учитывать его особенности.
