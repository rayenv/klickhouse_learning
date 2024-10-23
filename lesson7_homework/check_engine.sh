#!/bin/bash

# Функция для выполнения SQL-запросов
execute_query() {
    clickhouse-client -q "$1"
}

# Функция для создания и заполнения таблицы tbl1
test_tbl1() {
    local engine=$1
    echo "Testing tbl1 with engine: $engine"

    # Создание таблицы
    execute_query "
    CREATE TABLE tbl1
    (
        UserID UInt64,
        PageViews UInt8,
        Duration UInt8,
        Sign Int8,
        Version UInt8
    )
    ENGINE = $engine
    ORDER BY UserID;
    "

    # Вставка данных
    execute_query "
    INSERT INTO tbl1 VALUES (4324182021466249494, 5, 146, -1, 1);
    INSERT INTO tbl1 VALUES (4324182021466249494, 5, 146, 1, 1),(4324182021466249494, 6, 185, 1, 2);
    "

    # Выборка данных без FINAL
    echo "Without FINAL:"
    execute_query "SELECT * FROM tbl1;"

    # Выборка данных с FINAL
    echo "With FINAL:"
    execute_query "SELECT * FROM tbl1 FINAL;"

    # Удаление таблицы
    execute_query "DROP TABLE tbl1;"
}

# Функция для создания и заполнения таблицы tbl2
test_tbl2() {
    local engine=$1
    echo "Testing tbl2 with engine: $engine"

    # Создание таблицы
    execute_query "
    CREATE TABLE tbl2
    (
        key UInt32,
        value UInt32
    )
    ENGINE = $engine
    ORDER BY key;
    "

    # Вставка данных
    execute_query "
    INSERT INTO tbl2 Values(1,1),(1,2),(2,1);
    "

    # Выборка агрегированных данных
    echo "Aggregated data:"
    execute_query "SELECT key, sum(value) FROM tbl2 GROUP BY key;"

    # Удаление таблицы
    execute_query "DROP TABLE tbl2;"
}

# Функция для создания и заполнения таблицы tbl3
test_tbl3() {
    local engine=$1
    echo "Testing tbl3 with engine: $engine"

    # Создание таблицы
    execute_query "
    CREATE TABLE tbl3
    (
        \`id\` Int32,
        \`status\` String,
        \`price\` String,
        \`comment\` String
    )
    ENGINE = $engine
    PRIMARY KEY (id)
    ORDER BY (id, status);
    "

    # Вставка данных
    execute_query "
    INSERT INTO tbl3 VALUES (23, 'success', '1000', 'Confirmed');
    INSERT INTO tbl3 VALUES (23, 'success', '2000', 'Cancelled'); 
    "

    # Выборка данных без FINAL
    echo "Without FINAL:"
    execute_query "SELECT * from tbl3 WHERE id=23;"

    # Выборка данных с FINAL
    echo "With FINAL:"
    execute_query "SELECT * from tbl3 FINAL WHERE id=23;"

    # Удаление таблицы
    execute_query "DROP TABLE tbl3;"
}

# Функция для создания и заполнения таблиц tbl4 и tbl5
test_tbl4_tbl5() {
    local engine=$1
    echo "Testing tbl4 and tbl5 with engine: $engine"

    # Создание таблицы tbl4
    execute_query "
    CREATE TABLE tbl4
    (   CounterID UInt8,
        StartDate Date,
        UserID UInt64
    ) ENGINE = $engine
    PARTITION BY toYYYYMM(StartDate) 
    ORDER BY (CounterID, StartDate);
    "

    # Вставка данных в tbl4
    execute_query "
    INSERT INTO tbl4 VALUES(0, '2019-11-11', 1);
    INSERT INTO tbl4 VALUES(1, '2019-11-12', 1);
    "

    # Создание таблицы tbl5
    execute_query "
    CREATE TABLE tbl5
    (   CounterID UInt8,
        StartDate Date,
        UserID AggregateFunction(uniq, UInt64)
    ) ENGINE = $engine
    PARTITION BY toYYYYMM(StartDate) 
    ORDER BY (CounterID, StartDate);
    "

    # Вставка данных в tbl5
    execute_query "
    INSERT INTO tbl5
    select CounterID, StartDate, uniqState(UserID)
    from tbl4
    group by CounterID, StartDate;

    INSERT INTO tbl5 VALUES (1,'2019-11-12',1);
    "

    # Выборка агрегированных данных
    echo "Aggregated data:"
    execute_query "SELECT uniqMerge(UserID) AS state FROM tbl5 GROUP BY CounterID, StartDate;"

    # Удаление таблиц
    execute_query "DROP TABLE tbl4;"
    execute_query "DROP TABLE tbl5;"
}

# Функция для создания и заполнения таблицы tbl6
test_tbl6() {
    local engine=$1
    echo "Testing tbl6 with engine: $engine"

    # Создание таблицы
    execute_query "
    CREATE TABLE tbl6
    (
        \`id\` Int32,
        \`status\` String,
        \`price\` String,
        \`comment\` String,
        \`sign\` Int8
    )
    ENGINE = $engine
    PRIMARY KEY (id)
    ORDER BY (id, status);
    "

    # Вставка данных
    execute_query "
    INSERT INTO tbl6 VALUES (23, 'success', '1000', 'Confirmed', 1);
    INSERT INTO tbl6 VALUES (23, 'success', '1000', 'Confirmed', -1), (23, 'success', '2000', 'Cancelled', 1);
    "

    # Выборка данных без FINAL
    echo "Without FINAL:"
    execute_query "SELECT * FROM tbl6;"

    # Выборка данных с FINAL
    echo "With FINAL:"
    execute_query "SELECT * FROM tbl6 FINAL;"

    # Удаление таблицы
    execute_query "DROP TABLE tbl6;"
}

# Список движков для тестирования
engines=("MergeTree" "ReplacingMergeTree" "SummingMergeTree" "CollapsingMergeTree")

# Тестирование таблицы tbl1
for engine in "${engines[@]}"; do
    test_tbl1 "$engine"
done

# Тестирование таблицы tbl2
for engine in "${engines[@]}"; do
    test_tbl2 "$engine"
done

# Тестирование таблицы tbl3
for engine in "${engines[@]}"; do
    test_tbl3 "$engine"
done

# Тестирование таблиц tbl4 и tbl5
for engine in "${engines[@]}"; do
    test_tbl4_tbl5 "$engine"
done

# Тестирование таблицы tbl6
for engine in "${engines[@]}"; do
    test_tbl6 "$engine"
done