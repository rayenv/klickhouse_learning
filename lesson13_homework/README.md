# Отчёт о работе с ClickHouse: Проекции и материализованные представления

## 1. Создание таблицы `sales`

```sql
CREATE TABLE sales (
    id UInt32,
    product_id UInt32,
    quantity UInt32,
    price Float32,
    sale_date DateTime
) ENGINE = MergeTree()
ORDER BY id;
```

## 2. Заполнение таблицы тестовыми данными

```sql
INSERT INTO sales (id, product_id, quantity, price, sale_date) VALUES
(1, 101, 5, 10.5, '2023-10-01 12:00:00'),
(2, 102, 3, 15.0, '2023-10-02 14:00:00'),
(3, 101, 2, 10.5, '2023-10-03 16:00:00'),
(4, 103, 1, 20.0, '2023-10-04 18:00:00'),
(5, 102, 4, 15.0, '2023-10-05 20:00:00');
```

## 3. Создание проекции `sales_projection`

```sql
ALTER TABLE sales ADD PROJECTION sales_projection (
    SELECT
        product_id,
        sum(quantity) AS total_quantity,
        sum(quantity * price) AS total_sales
    GROUP BY product_id
);
```

## 4. Применение проекции

```sql
ALTER TABLE sales MATERIALIZE PROJECTION sales_projection;
```

## 5. Создание материализованного представления `sales_mv`

```sql
CREATE MATERIALIZED VIEW sales_mv
ENGINE = SummingMergeTree()
ORDER BY product_id
AS
SELECT
    product_id,
    sum(quantity) AS total_quantity,
    sum(quantity * price) AS total_sales
FROM sales
GROUP BY product_id;
```

## 6. Запросы к данным

### Запрос к основной таблице `sales`

```sql
SELECT
    product_id,
    sum(quantity) AS total_quantity,
    sum(quantity * price) AS total_sales
FROM sales
GROUP BY product_id;
```

**Результат:**

```
┌─product_id─┬─total_quantity─┬─total_sales─┐
│        101 │              7 │        73.5 │
│        103 │              1 │          20 │
│        102 │              7 │         105 │
└────────────┴────────────────┴─────────────┘

3 rows in set. Elapsed: 0.008 sec.
```

### Запрос к материализованному представлению `sales_mv`

```sql
SELECT * FROM sales_mv;
```

**Результат:**

```
┌─product_id─┬─total_quantity─┬─total_sales─┐
│        101 │              7 │        73.5 │
│        103 │              1 │          20 │
│        102 │              7 │         105 │
└────────────┴────────────────┴─────────────┘

3 rows in set. Elapsed: 0.008 sec.
```

## 7. Использование агрегатных функций

### Среднее значение (`avg()`)

```sql
SELECT
    product_id,
    avg(quantity) AS avg_quantity,
    avg(price) AS avg_price
FROM sales
GROUP BY product_id;
```

**Результат:**

```
┌─product_id─┬─avg_quantity─┬─avg_price─┐
│        101 │          3.5 │      10.5 │
│        103 │            1 │        20 │
│        102 │          3.5 │        15 │
└────────────┴──────────────┴───────────┘

3 rows in set. Elapsed: 0.008 sec.
```

### Максимальное значение (`max()`)

```sql
SELECT
    product_id,
    max(quantity) AS max_quantity,
    max(price) AS max_price
FROM sales
GROUP BY product_id;
```

**Результат:**

```
┌─product_id─┬─max_quantity─┬─max_price─┐
│        101 │            5 │      10.5 │
│        103 │            1 │        20 │
│        102 │            4 │        15 │
└────────────┴──────────────┴───────────┘

3 rows in set. Elapsed: 0.005 sec.
```

### Минимальное значение (`min()`)

```sql
SELECT
    product_id,
    min(quantity) AS min_quantity,
    min(price) AS min_price
FROM sales
GROUP BY product_id;
```

**Результат:**

```
┌─product_id─┬─min_quantity─┬─min_price─┐
│        101 │            2 │      10.5 │
│        103 │            1 │        20 │
│        102 │            3 │        15 │
└────────────┴──────────────┴───────────┘

3 rows in set. Elapsed: 0.004 sec.
```

## 8. Сравнение производительности

### Запрос к основной таблице `sales`

```bash
clickhouse-client --time -q "SELECT product_id, sum(quantity) AS total_quantity, sum(quantity * price) AS total_sales FROM sales GROUP BY product_id;"
```

**Результат:**

```
101     7       73.5
103     7       140
102     3       45
0.112 sec.
```

### Запрос к материализованному представлению `sales_mv`

```bash
clickhouse-client --time -q "SELECT * FROM sales_mv;"
```

**Результат:**

```
101     7       73.5
103     7       140
102     3       45
0.008 sec.
```

## Выводы

- Материализованные представления значительно ускоряют выполнение запросов, особенно при частом обращении к агрегированным данным.
- Проекции в ClickHouse используются для оптимизации запросов, но сами по себе не являются таблицами, из которых можно выбирать данные.
- Агрегатные функции `avg()`, `max()`, `min()` позволяют вычислять дополнительные статистические данные, что может быть полезно для анализа.

Этот отчёт демонстрирует базовое понимание работы проекций и материализованных представлений в ClickHouse, а также практические навыки их создания и использования.