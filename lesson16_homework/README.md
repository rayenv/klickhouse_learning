# Отчёт по домашнему заданию: "Мутации данных и манипуляции с партициями"

## 1. Создание таблицы

Создаём таблицу `user_activity` с использованием движка `MergeTree` и партиционированием по дате активности (`activity_date`).

```sql
CREATE TABLE user_activity (
    user_id UInt32,
    activity_type String,
    activity_date DateTime
) ENGINE = MergeTree
PARTITION BY toYYYYMM(activity_date)
ORDER BY user_id;
```

## 2. Заполнение таблицы

Вставляем несколько записей в таблицу `user_activity` с различными значениями `user_id`, `activity_type` и `activity_date`.

```sql
INSERT INTO user_activity (user_id, activity_type, activity_date) VALUES
(1, 'login', '2023-10-01 10:00:00'),
(2, 'logout', '2023-10-01 11:00:00'),
(3, 'purchase', '2023-10-02 12:00:00'),
(1, 'logout', '2023-10-03 13:00:00'),
(2, 'login', '2023-11-01 14:00:00');
```

## 3. Выполнение мутаций

Выполняем мутацию для изменения типа активности у пользователя с `user_id = 1` с `login` на `logout`.

```sql
ALTER TABLE user_activity UPDATE activity_type = 'logout' WHERE user_id = 1 AND activity_type = 'login';
```

## 4. Проверка результатов мутации

Проверяем изменения в таблице `user_activity` с помощью запроса:

```sql
SELECT * FROM user_activity WHERE user_id = 1;

   ┌─user_id─┬─activity_type─┬───────activity_date─┐
1. │       1 │ logout        │ 2023-10-01 10:00:00 │
2. │       1 │ logout        │ 2023-10-03 13:00:00 │
   └─────────┴───────────────┴─────────────────────┘
```

### Логи отслеживания мутаций

Проверяем статус выполнения мутации в системной таблице `system.mutations`:

```sql
SELECT mutation_id, command, block_numbers.partition_id, parts_to_do, is_done
FROM system.mutations
WHERE table = 'user_activity';

   ┌─mutation_id────┬─command─────────────────────────────────────────────────────────────────────────────┬─block_numbers.partition_id─┬─parts_to_do─┬─is_done─┐
1. │ mutation_3.txt │ (UPDATE activity_type = 'logout' WHERE (user_id = 1) AND (activity_type = 'login')) │ ['']                       │           0 │       1 │
   └────────────────┴─────────────────────────────────────────────────────────────────────────────────────┴────────────────────────────┴─────────────┴─────────┘
```

## 5. Манипуляции с партициями

Удаляем партицию за октябрь 2023 года (`202310`).

```sql
ALTER TABLE user_activity DROP PARTITION 202310;
```

## 6. Проверка состояния таблицы после удаления партиции

Проверяем текущее состояние таблицы `user_activity` после удаления партиции:

```sql
SELECT * FROM user_activity;


   ┌─user_id─┬─activity_type─┬───────activity_date─┐
1. │       2 │ login         │ 2023-11-01 14:00:00 │
   └─────────┴───────────────┴─────────────────────┘

```
Данные за октябрь 2023 года были успешно удалены.

## 7. Итог

1. Создана таблица `user_activity` с партиционированием по дате активности.
2. В таблицу были вставлены данные с различными значениями.
3. Выполнена мутация для изменения типа активности у определённых пользователей.
4. Проверены результаты мутации и отслежены логи в системной таблице.
5. Удалена партиция за определённый месяц.
6. Проверено состояние таблицы после удаления партиции.