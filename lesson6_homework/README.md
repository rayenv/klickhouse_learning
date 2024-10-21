# Результаты выполнения заданий
Выполнял Вариант 1 из предложенного в  [задании](./todo).

 Все SQL-запросы собраны в файл [request_storage](./request_storage).
## Агрегатные функции

### 1. Общий доход от всех операций

```sql
SELECT SUM(quantity * price) AS total_revenue
FROM transactions;
```

**Результат:**

| total_revenue |
|---------------|
| 1330          |

### 2. Средний доход с одной сделки

```sql
SELECT AVG(quantity * price) AS average_revenue_per_transaction
FROM transactions;
```

**Результат:**

| average_revenue_per_transaction |
|---------------------------------|
| 133                             |

### 3. Общее количество проданной продукции

```sql
SELECT SUM(quantity) AS total_quantity_sold
FROM transactions;
```

**Результат:**

| total_quantity_sold |
|---------------------|
| 20                  |

### 4. Количество уникальных пользователей, совершивших покупку

```sql
SELECT COUNT(DISTINCT user_id) AS unique_users
FROM transactions;
```

**Результат:**

| unique_users |
|--------------|
| 10           |

## Функции для работы с типами данных

### 1. Преобразование `transaction_date` в строку формата `YYYY-MM-DD`

```sql
SELECT formatDateTime(transaction_date, '%Y-%m-%d') AS transaction_date_str
FROM transactions
```

**Результат:**

| transaction_date_str |
|----------------------|
| 2023-10-01           |
| 2023-10-02           |
| 2023-10-03           |
| 2023-10-04           |
| 2023-10-05           |
| 2023-10-06           |
| 2023-10-07           |
| 2023-10-08           |
| 2023-10-09           |
| 2023-10-10           |

### 2. Извлечение года и месяца из `transaction_date`

```sql
SELECT 
    toYear(transaction_date) AS year,
    toMonth(transaction_date) AS month
FROM transactions;
```

**Результат:**

| year | month |
|------|-------|
| 2023 | 10    |
| 2023 | 10    |
| 2023 | 10    |
| 2023 | 10    |
| 2023 | 10    |
| 2023 | 10    |
| 2023 | 10    |
| 2023 | 10    |
| 2023 | 10    |
| 2023 | 10    |

### 3. Округление `price` до ближайшего целого числа

```sql
SELECT round(price) AS rounded_price
FROM transactions;
```

**Результат:**

| rounded_price |
|---------------|
| 50            |
| 150           |
| 30            |
| 200           |
| 75            |
| 100           |
| 25            |
| 120           |
| 80            |
| 40            |

### 4. Преобразование `transaction_id` в строку

```sql
SELECT toString(transaction_id) AS transaction_id_str
FROM transactions;
```

**Результат:**

| transaction_id_str |
|--------------------|
| 1                  |
| 2                  |
| 3                  |
| 4                  |
| 5                  |
| 6                  |
| 7                  |
| 8                  |
| 9                  |
| 10                 |

## User-Defined Functions (UDFs)

### 1. Создание и использование UDF для расчета общей стоимости транзакции

```sql
CREATE FUNCTION total_cost AS (quantity, price) -> quantity * price;

SELECT 
    transaction_id,
    total_cost(quantity, price) AS total_price
FROM transactions;
```

**Результат:**

| transaction_id | total_price |
|----------------|-------------|
| 1              | 100         |
| 2              | 150         |
| 3              | 90          |
| 4              | 200         |
| 5              | 150         |
| 6              | 100         |
| 7              | 100         |
| 8              | 240         |
| 9              | 80          |
| 10             | 120         |

### 2. Создание и использование UDF для классификации транзакций

```sql
CREATE FUNCTION classify_transaction AS (total_price) -> if(total_price > 100, 'высокоценные', 'малоценные');

SELECT 
    transaction_id,
    classify_transaction(total_cost(quantity, price)) AS transaction_category
FROM transactions;
```

**Результат:**

| transaction_id | transaction_category |
|----------------|----------------------|
| 1              | малоценные           |
| 2              | высокоценные         |
| 3              | малоценные           |
| 4              | высокоценные         |
| 5              | высокоценные         |
| 6              | малоценные           |
| 7              | малоценные           |
| 8              | высокоценные         |
| 9              | малоценные           |
| 10             | высокоценные         |

## Заключение

В этом задании мы использовали агрегатные функции для обобщения данных, функции для работы с различными типами данных и создали пользовательские функции (UDF) в ClickHouse для выполнения более сложных операций.