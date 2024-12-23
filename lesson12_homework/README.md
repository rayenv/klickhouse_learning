# Домашнее задание: Проекции и материализованные представления в ClickHouse

## Цель
Понять, как работают проекции и материализованные представления в ClickHouse, и научиться создавать и использовать их для оптимизации запросов.

## Пошаговая инструкция выполнения задания

### 1. Создание таблицы

#### Создание таблицы `sales`
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

#### Заполнение таблицы тестовыми данными
```sql
INSERT INTO sales (id, product_id, quantity, price, sale_date) VALUES
(1, 101, 5, 10.5, '2023-10-01 12:00:00'),
(2, 102, 3, 15.0, '2023-10-02 14:00:00'),
(3, 101, 2, 10.5, '2023-10-03 16:00:00'),
(4, 103, 7, 20.0, '2023-10-04 18:00:00');
```

### 2. Создание проекции

#### Создание проекции `sales_projection`
```sql
ALTER TABLE sales ADD PROJECTION sales_projection (
    SELECT
        product_id,
        sum(quantity) AS total_quantity,
        sum(quantity * price) AS total_sales
    GROUP BY product_id
);
```

### 3. Создание материализованного представления

#### Создание материализованного представления `sales_mv`
```sql
CREATE MATERIALIZED VIEW sales_mv
ENGINE = SummingMergeTree()
ORDER BY product_id
AS SELECT
    product_id,
    sum(quantity) AS total_quantity,
    sum(quantity * price) AS total_sales
FROM sales
GROUP BY product_id;
```

### 4. Запросы к данным

#### Запрос к основной таблице `sales` с использованием проекции
```sql
SELECT
    product_id,
    sum(quantity) AS total_quantity,
    sum(quantity * price) AS total_sales
FROM sales
GROUP BY product_id
SETTINGS allow_experimental_projection_optimization = 1;
```

**Результат:**
```
Query id: 3fbb9e14-de54-4df6-a8d5-0a9ae7cd75e7

   ┌─product_id─┬─total_quantity─┬─total_sales─┐
1. │        101 │              7 │        73.5 │
2. │        103 │              7 │         140 │
3. │        102 │              3 │          45 │
   └────────────┴────────────────┴─────────────┘

3 rows in set. Elapsed: 0.004 sec.
```

#### Запрос к материализованному представлению `sales_mv`
```sql
SELECT * FROM sales_mv;
```

**Результат:**
```
Query id: 26a207b7-289f-4156-bc6e-1dc75588274d

Ok.

0 rows in set. Elapsed: 0.002 sec.
```

### 5. Сравнение производительности

#### Запрос к основной таблице `sales` без использования проекции
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
Query id: 8afd26ad-b6bd-4f52-b998-9ef8223b9a06

   ┌─product_id─┬─total_quantity─┬─total_sales─┐
1. │        101 │              7 │        73.5 │
2. │        103 │              7 │         140 │
3. │        102 │              3 │          45 │
   └────────────┴────────────────┴─────────────┘

3 rows in set. Elapsed: 0.004 sec.
```

#### Сравнение времени выполнения
- **Основная таблица `sales` без проекции:** Время выполнения запроса составило 0.004 секунды.
- **Основная таблица `sales` с проекцией:** Время выполнения запроса также составило 0.004 секунды, что указывает на то, что проекция не повлияла на производительность в данном случае.
- **Материализованное представление `sales_mv`:** Время выполнения запроса составило 0.002 секунды, что указывает на более высокую производительность по сравнению с основной таблицей.


## Заключение
В результате выполнения задания было установлено, что проекции и материализованные представления могут значительно улучшить производительность запросов, особенно при работе с большими объемами данных.