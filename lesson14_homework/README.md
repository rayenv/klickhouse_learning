# Отчёт по выполнению задачи репликации и удаления в ClickHouse

## Цель

Преобразовать таблицу в реплицируемую, настроить реплики в ClickHouse и работать с данными в распределённой системе.

## Описание/Пошаговая инструкция выполнения домашнего задания

### Шаг 1: Создание Docker контейнеров для ClickHouse и ZooKeeper

создание файла `docker-compose.yml` со следующим содержимым:

```yaml
version: '3.7'

services:
  zookeeper:
    image: zookeeper:latest
    container_name: zookeeper
    ports:
      - "2181:2181"
    environment:
      ZOO_MY_ID: 1
      ZOO_SERVERS: server.1=zookeeper:2888:3888;2181

  ch1:
    image: yandex/clickhouse-server:latest
    container_name: ch1
    ports:
      - "8125:8123"  # Измененный порт для HTTP
      - "9002:9000"  # Измененный порт для TCP
    environment:
      - CLICKHOUSE_DB=default
      - CLICKHOUSE_USER=default
      - CLICKHOUSE_PASSWORD=
    volumes:
      - ./ch1_data:/var/lib/clickhouse
      - ./ch1_config:/etc/clickhouse-server/config.d
    depends_on:
      - zookeeper

  ch2:
    image: yandex/clickhouse-server:latest
    container_name: ch2
    ports:
      - "8126:8123"  # Измененный порт для HTTP
      - "9003:9000"  # Измененный порт для TCP
    environment:
      - CLICKHOUSE_DB=default
      - CLICKHOUSE_USER=default
      - CLICKHOUSE_PASSWORD=
    volumes:
      - ./ch2_data:/var/lib/clickhouse
      - ./ch2_config:/etc/clickhouse-server/config.d
    depends_on:
      - zookeeper
```

Запуск контейнеров:

```bash
docker-compose up -d
```

### Шаг 2: Создание конфигурационных файлаов для ClickHouse

создание директории для конфигурационных файлаов ClickHouse:

```bash
mkdir -p ./ch1_config ./ch2_config
```

создание файла `zookeeper.xml` в директории `ch1_config`:

```xml
<!-- ./ch1_config/zookeeper.xml -->
<yandex>
    <zookeeper>
        <node>
            <host>zookeeper</host>
            <port>2181</port>
        </node>
    </zookeeper>
</yandex>
```

создание файла `macros.xml` в директории `ch1_config`:

```xml
<!-- ./ch1_config/macros.xml -->
<yandex>
    <macros>
        <shard>01</shard>
        <replica>ch1</replica>
    </macros>
</yandex>
```

создание файла `zookeeper.xml` в директории `ch2_config`:

```xml
<!-- ./ch2_config/zookeeper.xml -->
<yandex>
    <zookeeper>
        <node>
            <host>zookeeper</host>
            <port>2181</port>
        </node>
    </zookeeper>
</yandex>
```

создание файла `macros.xml` в директории `ch2_config`:

```xml
<!-- ./ch2_config/macros.xml -->
<yandex>
    <macros>
        <shard>02</shard>
        <replica>ch2</replica>
    </macros>
</yandex>
```

### Шаг 3: Создание таблицы и заполнение данными

Подключение к первому инстансу ClickHouse:

```bash
docker exec -it ch1 clickhouse-client
```

создание таблицы:

```sql
CREATE TABLE trips (
    trip_id             UInt32,
    pickup_datetime     DateTime,
    dropoff_datetime    DateTime,
    pickup_longitude    Nullable(Float64),
    pickup_latitude     Nullable(Float64),
    dropoff_longitude   Nullable(Float64),
    dropoff_latitude    Nullable(Float64),
    passenger_count     UInt8,
    trip_distance       Float32,
    fare_amount         Float32,
    extra               Float32,
    tip_amount          Float32,
    tolls_amount        Float32,
    total_amount        Float32,
    payment_type        Enum('CSH' = 1, 'CRE' = 2, 'NOC' = 3, 'DIS' = 4, 'UNK' = 5),
    pickup_ntaname      LowCardinality(String),
    dropoff_ntaname     LowCardinality(String)
)
ENGINE = MergeTree
PRIMARY KEY (pickup_datetime, dropoff_datetime);
```

Заполнение таблицы данными:

```sql
INSERT INTO trips VALUES
(1200864931, '2015-07-01 00:00:13', '2015-07-01 00:14:41', -73.99046325683594, 40.746116638183594, -73.97918701171875, 40.78467559814453, 5, 3.54, 13.5, 0.5, 1, 0, 15.8, 'CSH', 'Midtown-Midtown South', 'Upper West Side'),
(1200018648, '2015-07-01 00:00:16', '2015-07-01 00:02:57', -73.78358459472656, 40.648677825927734, -73.80242919921875, 40.64767837524414, 1, 1.45, 6, 0.5, 0, 0, 7.3, 'CRE', 'Airport', 'Airport'),
(1201452450, '2015-07-01 00:00:20', '2015-07-01 00:11:07', -73.98579406738281, 40.72777557373047, -74.00482177734375, 40.73748779296875, 5, 1.56, 8.5, 0.5, 1.96, 0, 11.76, 'CSH', 'East Village', 'West Village'),
(1202368372, '2015-07-01 00:00:40', '2015-07-01 00:05:46', -74.00206756591797, 40.73833084106445, -74.00658416748047, 40.74875259399414, 2, 1, 6, 0.5, 0, 0, 7.3, 'CRE', 'West Village', 'Hudson Yards-Chelsea-Flatiron-Union Square'),
(1200831168, '2015-07-01 00:01:06', '2015-07-01 00:09:23', -73.98748016357422, 40.74344253540039, -74.00575256347656, 40.716793060302734, 1, 2.3, 9, 0.5, 2, 0, 12.3, 'CSH', 'Hudson Yards-Chelsea-Flatiron-Union Square', 'SoHo-TriBeCa-Civic Center-Little Italy'),
(1201362116, '2015-07-01 00:01:07', '2015-07-01 00:03:31', -73.9926986694336, 40.75826644897461, -73.98628997802734, 40.76075744628906, 1, 0.6, 4, 0.5, 0, 0, 5.3, 'CRE', 'Clinton', 'Midtown-Midtown South'),
(1200639419, '2015-07-01 00:01:13', '2015-07-01 00:03:56', -74.00382995605469, 40.741981506347656, -73.99711608886719, 40.742271423339844, 1, 0.49, 4, 0.5, 0, 0, 5.3, 'CRE', 'Hudson Yards-Chelsea-Flatiron-Union Square', 'Hudson Yards-Chelsea-Flatiron-Union Square'),
(1201181622, '2015-07-01 00:01:17', '2015-07-01 00:05:12', -73.9512710571289, 40.78261947631836, -73.95230865478516, 40.77476119995117, 4, 0.97, 5, 0.5, 1, 0, 7.3, 'CSH', 'Upper East Side-Carnegie Hill', 'Yorkville'),
(1200978273, '2015-07-01 00:01:28', '2015-07-01 00:09:46', -74.00822448730469, 40.72113037109375, -74.00422668457031, 40.70782470703125, 1, 1.71, 8.5, 0.5, 1.96, 0, 11.76, 'CSH', 'SoHo-TriBeCa-Civic Center-Little Italy', 'Battery Park City-Lower Manhattan'),
(1203283366, '2015-07-01 00:01:47', '2015-07-01 00:24:26', -73.98199462890625, 40.77289962768555, -73.91968536376953, 40.766082763671875, 3, 5.26, 19.5, 0.5, 5.2, 0, 26, 'CSH', 'Lincoln Square', 'Astoria');
```

### Шаг 4: Преобразование таблицы в реплицируемую

Подключение к первому инстансу ClickHouse:

```bash
docker exec -it ch1 clickhouse-client
```

создание реплицируемой таблицы:

```sql
CREATE TABLE trips_replicated (
    trip_id             UInt32,
    pickup_datetime     DateTime,
    dropoff_datetime    DateTime,
    pickup_longitude    Nullable(Float64),
    pickup_latitude     Nullable(Float64),
    dropoff_longitude   Nullable(Float64),
    dropoff_latitude    Nullable(Float64),
    passenger_count     UInt8,
    trip_distance       Float32,
    fare_amount         Float32,
    extra               Float32,
    tip_amount          Float32,
    tolls_amount        Float32,
    total_amount        Float32,
    payment_type        Enum('CSH' = 1, 'CRE' = 2, 'NOC' = 3, 'DIS' = 4, 'UNK' = 5),
    pickup_ntaname      LowCardinality(String),
    dropoff_ntaname     LowCardinality(String)
)
ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/trips_replicated', '{replica}')
PRIMARY KEY (pickup_datetime, dropoff_datetime);
```

Подключение ко второму инстансу ClickHouse:

```bash
docker exec -it ch2 clickhouse-client
```

создание таблицы на второй реплике:

```sql
CREATE TABLE trips_replicated (
    trip_id             UInt32,
    pickup_datetime     DateTime,
    dropoff_datetime    DateTime,
    pickup_longitude    Nullable(Float64),
    pickup_latitude     Nullable(Float64),
    dropoff_longitude   Nullable(Float64),
    dropoff_latitude    Nullable(Float64),
    passenger_count     UInt8,
    trip_distance       Float32,
    fare_amount         Float32,
    extra               Float32,
    tip_amount          Float32,
    tolls_amount        Float32,
    total_amount        Float32,
    payment_type        Enum('CSH' = 1, 'CRE' = 2, 'NOC' = 3, 'DIS' = 4, 'UNK' = 5),
    pickup_ntaname      LowCardinality(String),
    dropoff_ntaname     LowCardinality(String)
)
ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/trips_replicated', '{replica}')
PRIMARY KEY (pickup_datetime, dropoff_datetime);
```

### Шаг 5: Проверка таблицы репликации на `ch2`

Подключение ко второму инстансу ClickHouse:

```bash
docker exec -it ch2 clickhouse-client
```

Выполнение запроса:

```sql
SELECT * FROM trips_replicated;
```

**Результат:**

```sql
Query id: 20d07d81-4c30-47da-8dd4-cabee376b002

Ok.

0 rows in set. Elapsed: 0.002 sec.
```

### Шаг 6: Вставка данных на `ch1` и проверка

Подключение к первому инстансу ClickHouse:

```bash
docker exec -it ch1 clickhouse-client
```

Вставьте данные:

```sql
INSERT INTO trips_replicated VALUES
(1200864931, '2015-07-01 00:00:13', '2015-07-01 00:14:41', -73.99046325683594, 40.746116638183594, -73.97918701171875, 40.78467559814453, 5, 3.54, 13.5, 0.5, 1, 0, 15.8, 'CSH', 'Midtown-Midtown South', 'Upper West Side'),
(1200018648, '2015-07-01 00:00:16', '2015-07-01 00:02:57', -73.78358459472656, 40.648677825927734, -73.80242919921875, 40.64767837524414, 1, 1.45, 6, 0.5, 0, 0, 7.3, 'CRE', 'Airport', 'Airport'),
(1201452450, '2015-07-01 00:00:20', '2015-07-01 00:11:07', -73.98579406738281, 40.72777557373047, -74.00482177734375, 40.73748779296875, 5, 1.56, 8.5, 0.5, 1.96, 0, 11.76, 'CSH', 'East Village', 'West Village'),
(1202368372, '2015-07-01 00:00:40', '2015-07-01 00:05:46', -74.00206756591797, 40.73833084106445, -74.00658416748047, 40.74875259399414, 2, 1, 6, 0.5, 0, 0, 7.3, 'CRE', 'West Village', 'Hudson Yards-Chelsea-Flatiron-Union Square'),
(1200831168, '2015-07-01 00:01:06', '2015-07-01 00:09:23', -73.98748016357422, 40.74344253540039, -74.00575256347656, 40.716793060302734, 1, 2.3, 9, 0.5, 2, 0, 12.3, 'CSH', 'Hudson Yards-Chelsea-Flatiron-Union Square', 'SoHo-TriBeCa-Civic Center-Little Italy'),
(1201362116, '2015-07-01 00:01:07', '2015-07-01 00:03:31', -73.9926986694336, 40.75826644897461, -73.98628997802734, 40.76075744628906, 1, 0.6, 4, 0.5, 0, 0, 5.3, 'CRE', 'Clinton', 'Midtown-Midtown South'),
(1200639419, '2015-07-01 00:01:13', '2015-07-01 00:03:56', -74.00382995605469, 40.741981506347656, -73.99711608886719, 40.742271423339844, 1, 0.49, 4, 0.5, 0, 0, 5.3, 'CRE', 'Hudson Yards-Chelsea-Flatiron-Union Square', 'Hudson Yards-Chelsea-Flatiron-Union Square'),
(1201181622, '2015-07-01 00:01:17', '2015-07-01 00:05:12', -73.9512710571289, 40.78261947631836, -73.95230865478516, 40.77476119995117, 4, 0.97, 5, 0.5, 1, 0, 7.3, 'CSH', 'Upper East Side-Carnegie Hill', 'Yorkville'),
(1200978273, '2015-07-01 00:01:28', '2015-07-01 00:09:46', -74.00822448730469, 40.72113037109375, -74.00422668457031, 40.70782470703125, 1, 1.71, 8.5, 0.5, 1.96, 0, 11.76, 'CSH', 'SoHo-TriBeCa-Civic Center-Little Italy', 'Battery Park City-Lower Manhattan'),
(1203283366, '2015-07-01 00:01:47', '2015-07-01 00:24:26', -73.98199462890625, 40.77289962768555, -73.91968536376953, 40.766082763671875, 3, 5.26, 19.5, 0.5, 5.2, 0, 26, 'CSH', 'Lincoln Square', 'Astoria');
```

**Результат:**

```sql
Query id: 10bd6654-222d-4b41-a722-73224be19a3b

Ok.

10 rows in set. Elapsed: 0.019 sec.
```

Проверьте данные на первом инстансе:

```sql
SELECT * FROM trips_replicated;
```

**Результат:**

```sql
Query id: 9fb21756-89e6-4d9f-93fa-8ae20f10c5c8

┌────trip_id─┬─────pickup_datetime─┬────dropoff_datetime─┬───pickup_longitude─┬────pickup_latitude─┬──dropoff_longitude─┬───dropoff_latitude─┬─passenger_count─┬─trip_distance─┬─fare_amount─┬─extra─┬─tip_amount─┬─tolls_amount─┬─total_amount─┬─payment_type─┬─pickup_ntaname─────────────────────────────┬─dropoff_ntaname────────────────────────────┐
│ 1200864931 │ 2015-07-01 00:00:13 │ 2015-07-01 00:14:41 │ -73.99046325683594 │ 40.746116638183594 │ -73.97918701171875 │  40.78467559814453 │               5 │          3.54 │        13.5 │   0.5 │          1 │            0 │         15.8 │ CSH          │ Midtown-Midtown South                      │ Upper West Side                            │
│ 1200018648 │ 2015-07-01 00:00:16 │ 2015-07-01 00:02:57 │ -73.78358459472656 │ 40.648677825927734 │ -73.80242919921875 │  40.64767837524414 │               1 │          1.45 │           6 │   0.5 │          0 │            0 │          7.3 │ CRE          │ Airport                                    │ Airport                                    │
│ 1201452450 │ 2015-07-01 00:00:20 │ 2015-07-01 00:11:07 │ -73.98579406738281 │  40.72777557373047 │ -74.00482177734375 │  40.73748779296875 │               5 │          1.56 │         8.5 │   0.5 │       1.96 │            0 │        11.76 │ CSH          │ East Village                               │ West Village                               │
│ 1202368372 │ 2015-07-01 00:00:40 │ 2015-07-01 00:05:46 │ -74.00206756591797 │  40.73833084106445 │ -74.00658416748047 │  40.74875259399414 │               2 │             1 │           6 │   0.5 │          0 │            0 │          7.3 │ CRE          │ West Village                               │ Hudson Yards-Chelsea-Flatiron-Union Square │
│ 1200831168 │ 2015-07-01 00:01:06 │ 2015-07-01 00:09:23 │ -73.98748016357422 │  40.74344253540039 │ -74.00575256347656 │ 40.716793060302734 │               1 │           2.3 │           9 │   0.5 │          2 │            0 │         12.3 │ CSH          │ Hudson Yards-Chelsea-Flatiron-Union Square │ SoHo-TriBeCa-Civic Center-Little Italy     │
│ 1201362116 │ 2015-07-01 00:01:07 │ 2015-07-01 00:03:31 │  -73.9926986694336 │  40.75826644897461 │ -73.98628997802734 │  40.76075744628906 │               1 │           0.6 │           4 │   0.5 │          0 │            0 │          5.3 │ CRE          │ Clinton                                    │ Midtown-Midtown South                      │
│ 1200639419 │ 2015-07-01 00:01:13 │ 2015-07-01 00:03:56 │ -74.00382995605469 │ 40.741981506347656 │ -73.99711608886719 │ 40.742271423339844 │               1 │          0.49 │           4 │   0.5 │          0 │            0 │          5.3 │ CRE          │ Hudson Yards-Chelsea-Flatiron-Union Square │ Hudson Yards-Chelsea-Flatiron-Union Square │
│ 1201181622 │ 2015-07-01 00:01:17 │ 2015-07-01 00:05:12 │  -73.9512710571289 │  40.78261947631836 │ -73.95230865478516 │  40.77476119995117 │               4 │          0.97 │           5 │   0.5 │          1 │            0 │          7.3 │ CSH          │ Upper East Side-Carnegie Hill              │ Yorkville                                  │
│ 1200978273 │ 2015-07-01 00:01:28 │ 2015-07-01 00:09:46 │ -74.00822448730469 │  40.72113037109375 │ -74.00422668457031 │  40.70782470703125 │               1 │          1.71 │         8.5 │   0.5 │       1.96 │            0 │        11.76 │ CSH          │ SoHo-TriBeCa-Civic Center-Little Italy     │ Battery Park City-Lower Manhattan          │
│ 1203283366 │ 2015-07-01 00:01:47 │ 2015-07-01 00:24:26 │ -73.98199462890625 │  40.77289962768555 │ -73.91968536376953 │ 40.766082763671875 │               3 │          5.26 │        19.5 │   0.5 │        5.2 │            0 │           26 │ CSH          │ Lincoln Square                             │ Astoria                                    │
└────────────┴─────────────────────┴─────────────────────┴────────────────────┴────────────────────┴────────────────────┴────────────────────┴─────────────────┴───────────────┴─────────────┴───────┴────────────┴──────────────┴──────────────┴──────────────┴────────────────────────────────────────────┴────────────────────────────────────────────┘

10 rows in set. Elapsed: 0.003 sec.
```

### Шаг 7: Проверка реплицирования данных на `ch2`

Подключение ко второму инстансу ClickHouse:

```bash
docker exec -it ch2 clickhouse-client
```

Выполнение запрос:

```sql
SELECT * FROM trips_replicated;
```

**Результат:**

```sql
Query id: 3e121e9b-10c6-4173-97f9-49b44c3a55c7

Ok.

0 rows in set. Elapsed: 0.002 sec.
```

### Шаг 8: Добавление колонки с типом Date и TTL на `ch1`

Подключение к первому инстансу ClickHouse:

```bash
docker exec -it ch1 clickhouse-client
```

Добавление колонки и настройка TTL:

```sql
ALTER TABLE trips_replicated
ADD COLUMN trip_date Date DEFAULT toDate(pickup_datetime) AFTER trip_id;

ALTER TABLE trips_replicated
MODIFY TTL trip_date + INTERVAL 7 DAY;
```

**Результат:**

```sql
Query id: c6763f9f-8cc7-48dc-8495-17e5477932bc

Ok.

0 rows in set. Elapsed: 0.024 sec.

Query id: 6d29decb-2126-4cce-a8fb-9bb447ee4573

Ok.

0 rows in set. Elapsed: 0.065 sec.
```

Результат запроса `SHOW CREATE TABLE`:

```sql
SHOW CREATE TABLE trips_replicated;
```

**Результат:**

```sql
Query id: 94d911b3-6c34-45a2-b154-213750ffa71c

┌─statement──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ CREATE TABLE default.trips_replicated
(
    `trip_id` UInt32,
    `trip_date` Date DEFAULT toDate(pickup_datetime),
    `pickup_datetime` DateTime,
    `dropoff_datetime` DateTime,
    `pickup_longitude` Nullable(Float64),
    `pickup_latitude` Nullable(Float64),
    `dropoff_longitude` Nullable(Float64),
    `dropoff_latitude` Nullable(Float64),
    `passenger_count` UInt8,
    `trip_distance` Float32,
    `fare_amount` Float32,
    `extra` Float32,
    `tip_amount` Float32,
    `tolls_amount` Float32,
    `total_amount` Float32,
    `payment_type` Enum8('CSH' = 1, 'CRE' = 2, 'NOC' = 3, 'DIS' = 4, 'UNK' = 5),
    `pickup_ntaname` LowCardinality(String),
    `dropoff_ntaname` LowCardinality(String)
)
ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/trips_replicated', '{replica}')
PRIMARY KEY (pickup_datetime, dropoff_datetime)
ORDER BY (pickup_datetime, dropoff_datetime)
TTL trip_date + toIntervalDay(7)
SETTINGS index_granularity = 8192 │
└────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

1 rows in set. Elapsed: 0.002 sec.
```