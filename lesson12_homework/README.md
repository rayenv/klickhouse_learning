# Домашнее задание: Взаимодействия со словарями и оконными функциями

## Цель
Продемонстрировать навыки в обращении со словарями и оконными функциями в ClickHouse.

## Описание задания

### 1. Создание таблицы
Создана таблица `user_actions` с полями:
- `user_id` (UInt64)
- `action` (String)
- `expense` (UInt64)

```sql
CREATE TABLE user_actions (
    user_id UInt64,
    action String,
    expense UInt64
) ENGINE = MergeTree()
ORDER BY user_id;
```

### 2. Создание словаря
Создан словарь `user_emails` с ключом `user_id` и атрибутом `email` (String). В качестве источника использован файл.

```sql
CREATE DICTIONARY user_emails (
    user_id UInt64,
    email String
)
PRIMARY KEY user_id
SOURCE(FILE(path '/path/to/your/file.csv' format 'CSV'))
LAYOUT(FLAT())
LIFETIME(0);
```

### 3. Наполнение таблицы и словаря данными

#### Таблица `user_actions`
```sql
INSERT INTO user_actions VALUES
(1, 'buy', 100),
(1, 'sell', 50),
(2, 'buy', 200),
(2, 'sell', 100),
(3, 'buy', 150),
(3, 'sell', 75);
```

#### Словарь `user_emails`
Файл `file.csv`:
```csv
1,user1@example.com
2,user2@example.com
3,user3@example.com
```

### 4. Написание SELECT запроса
Написан запрос, который возвращает:
- `email` при помощи `dictGet`
- аккумулятивную сумму `expense` с окном по `action`
- сортировка по `email`

```sql
SELECT
    dictGet('user_emails', 'email', user_id) AS email,
    action,
    expense,
    sum(expense) OVER (PARTITION BY action ORDER BY user_id) AS cumulative_expense
FROM user_actions
ORDER BY email;
```

## Результат выполнения запроса

| email               | action | expense | cumulative_expense |
|---------------------|--------|---------|--------------------|
| user1@example.com    | buy    | 100     | 100                |
| user1@example.com    | sell   | 50      | 50                 |
| user2@example.com    | buy    | 200     | 300                |
| user2@example.com    | sell   | 100     | 150                |
| user3@example.com    | buy    | 150     | 450                |
| user3@example.com    | sell   | 75      | 225                |
