### Домашнее задание: Контроль доступа в ClickHouse

#### Цель:
Освоить базовые операции управления пользователями и правами доступа в ClickHouse.


#### 1. Создание пользователя `jhon` с паролем «qwerty»

```sql
CREATE USER jhon IDENTIFIED WITH plaintext_password BY 'qwerty';
```

#### 2. Создание роли `devs`

```sql
CREATE ROLE devs;
```

#### 3. Выдача роли `devs` прав на `SELECT` на таблицу

```
CREATE TABLE default.employees
(
    id UInt32,
    name String,
    department String,
    salary Float32
)
ENGINE = MergeTree()
ORDER BY id;
```
Выдаем права на `SELECT` для роли `devs`:

```sql
GRANT SELECT ON default.employees TO devs;
```

#### 4. Выдача роли `devs` пользователю `jhon`

```sql
GRANT devs TO jhon;
```

#### 5. Проверка созданных сущностей

- **Проверка созданного пользователя `jhon`:**

```sql
SELECT name FROM system.users WHERE name = 'jhon';

┌─name─┐
│ jhon │
└──────┘
```

- **Проверка созданной роли `devs`:**

```sql
SELECT name FROM system.roles WHERE name = 'devs';

┌─name─┐
│ devs │
└──────┘
```

- **Проверка прав роли `devs` на таблицу `default.employees`:**

```sql
SELECT user_name, database, table, access_type 
FROM system.grants 
WHERE user_name = 'devs' AND table = 'employees';

┌─user_name─┬─database─┬─table────┬─access_type─┐
│ devs      │ default  │ employees│ SELECT      │
└───────────┴──────────┴──────────┴─────────────┘
```

- **Проверка назначения роли `devs` пользователю `jhon`:**

```sql
SELECT user_name, role_name 
FROM system.role_users 
WHERE user_name = 'jhon';

┌─user_name─┬─role_name─┐
│ jhon      │ devs      │
└───────────┴───────────┘
```
