Для выполнения домашнего задания по профилированию запросов в ClickHouse и анализу использования индексов, выполним следующие шаги:

### 1. Создание таблицы

Создадим таблицу с первичным ключом (ПК) и вставим в неё данные для дальнейшего анализа.

```sql
CREATE TABLE test_table
(
    id UInt32,
    name String,
    date Date
)
ENGINE = MergeTree()
ORDER BY (id, date);
```

В этой таблице первичный ключ (ПК) состоит из колонок `id` и `date`.

### 2. Вставка данных

Вставим тестовые данные в таблицу:

```sql
INSERT INTO test_table (id, name, date) VALUES
(1, 'Alice', '2023-10-01'),
(2, 'Bob', '2023-10-02'),
(3, 'Charlie', '2023-10-03'),
(4, 'David', '2023-10-04'),
(5, 'Eve', '2023-10-05');
```

### 3. Выполнение запросов

#### Запрос без использования первичного ключа

Выполним запрос, который не использует первичный ключ:

```sql
SELECT * FROM test_table WHERE name = 'Bob';


┌─id─┬─name─┬───────date─┐
│  2 │ Bob  │ 2023-10-02 │
└────┴──────┴────────────┘
```

#### Запрос с использованием первичного ключа

Теперь выполним запрос, который использует первичный ключ:

```sql
SELECT * FROM test_table WHERE id = 2 AND date = '2023-10-02';

┌─id─┬─name─┬───────date─┐
│  2 │ Bob  │ 2023-10-02 │
└────┴──────┴────────────┘
```

### 4. Анализ логов

После выполнения запросов, проверьте логи в таблице `system.query_log`:

```sql
SELECT
    query,
    query_duration_ms,
    read_rows,
    read_bytes,
    memory_usage
FROM system.query_log
WHERE type = 'QueryFinish'
ORDER BY event_time DESC
LIMIT 2;


   ┌─query──────────────────────────────────────────────────────────┬─query_duration_ms─┬─read_rows─┬─read_bytes─┬─memory_usage─┐
1. │ SELECT * FROM test_table WHERE id = 2 AND date = '2023-10-02'; │                 3 │         5 │         98 │         5985 │
2. │ SELECT * FROM test_table WHERE name = 'Bob';                   │                 6 │         5 │         98 │         7425 │
   └────────────────────────────────────────────────────────────────┴───────────────────┴───────────┴────────────┴──────────────┘
```

### 5.  Использование EXPLAIN

Для анализа использования индекса можно использовать команду `EXPLAIN`:

```sql
EXPLAIN indexes = 1
SELECT * FROM test_table WHERE id = 2 AND date = '2023-10-02';

    ┌─explain──────────────────────────────────────────────────────────┐
 1. │ Expression ((Project names + Projection))                        │
 2. │   Expression                                                     │
 3. │     ReadFromMergeTree (default.test_table)                       │
 4. │     Indexes:                                                     │
 5. │       PrimaryKey                                                 │
 6. │         Keys:                                                    │
 7. │           id                                                     │
 8. │           date                                                   │
 9. │         Condition: and((date in [19632, 19632]), (id in [2, 2])) │
10. │         Parts: 1/1                                               │
11. │         Granules: 1/1                                            │
    └──────────────────────────────────────────────────────────────────┘

11 rows in set. Elapsed: 0.003 sec.
```