# Домашнее задание: Шардирование ClickHouse

## Цель

Шардировать свой инстанс ClickHouse.

### 1. Запуск N экземпляров ClickHouse-server

Для выполнения задания запустим 3 экземпляра ClickHouse-server на локальной машине. Для этого можно использовать Docker. Пример команды для запуска трех контейнеров:

```bash
docker run -d --name ch1 -p 8123:8123 -p 9000:9000 yandex/clickhouse-server
docker run -d --name ch2 -p 8124:8123 -p 9001:9000 yandex/clickhouse-server
docker run -d --name ch3 -p 8125:8123 -p 9002:9000 yandex/clickhouse-server
```

### 2. Описание топологий шардирования

Создадим две топологии шардирования:

1. **Топология 1**: 2 шарда с фактором репликации 1.
2. **Топология 2**: 1 шард с фактором репликации 3.

#### Топология 1: 2 шарда с фактором репликации 1

```xml
<clickhouse>
    <remote_servers>
        <cluster_2shards_1replica>
            <shard>
                <replica>
                    <host>ch1</host>
                    <port>9000</port>
                </replica>
            </shard>
            <shard>
                <replica>
                    <host>ch2</host>
                    <port>9001</port>
                </replica>
            </shard>
        </cluster_2shards_1replica>
    </remote_servers>
</clickhouse>
```

#### Топология 2: 1 шард с фактором репликации 3

```xml
<clickhouse>
    <remote_servers>
        <cluster_1shard_3replicas>
            <shard>
                <replica>
                    <host>ch1</host>
                    <port>9000</port>
                </replica>
                <replica>
                    <host>ch2</host>
                    <port>9001</port>
                </replica>
                <replica>
                    <host>ch3</host>
                    <port>9002</port>
                </replica>
            </shard>
        </cluster_1shard_3replicas>
    </remote_servers>
</clickhouse>
```

### 3. Создание DISTRIBUTED-таблиц

#### Топология 1: 2 шарда с фактором репликации 1

Создадим DISTRIBUTED-таблицу для первой топологии:

```sql
CREATE TABLE distributed_table_2shards_1replica (
    dummy UInt8
) ENGINE = Distributed(cluster_2shards_1replica, system, one, rand());
```

#### Топология 2: 1 шард с фактором репликации 3

Создадим DISTRIBUTED-таблицу для второй топологии:

```sql
CREATE TABLE distributed_table_1shard_3replicas (
    dummy UInt8
) ENGINE = Distributed(cluster_1shard_3replicas, system, one, rand());
```

### 4. Вывод информации

#### Топология 1: 2 шарда с фактором репликации 1

```sql
SELECT * FROM system.clusters WHERE cluster = 'cluster_2shards_1replica';

┌─cluster──────────────────┬─shard_num─┬─shard_weight─┬─replica_num─┬─host_name─┬─host_address─┬─port─┬─is_local─┬─user────┬─default_database─┐
│ cluster_2shards_1replica │         1 │            1 │           1 │ ch1       │ 172.17.0.2   │ 9000 │        1 │ default │                  │
│ cluster_2shards_1replica │         2 │            1 │           1 │ ch2       │ 172.17.0.3   │ 9001 │        0 │ default │                  │
└──────────────────────────┴───────────┴──────────────┴─────────────┴───────────┴──────────────┴──────┴──────────┴─────────┴──────────────────┘
```

```sql
SHOW CREATE TABLE distributed_table_2shards_1replica;

CREATE TABLE default.distributed_table_2shards_1replica
(
    `dummy` UInt8
)
ENGINE = Distributed('cluster_2shards_1replica', 'system', 'one', rand())
```

#### Топология 2: 1 шард с фактором репликации 3

```sql
SELECT * FROM system.clusters WHERE cluster = 'cluster_1shard_3replicas';

┌─cluster──────────────────┬─shard_num─┬─shard_weight─┬─replica_num─┬─host_name─┬─host_address─┬─port─┬─is_local─┬─user────┬─default_database─┐
│ cluster_1shard_3replicas │         1 │            1 │           1 │ ch1       │ 172.17.0.2   │ 9000 │        1 │ default │                  │
│ cluster_1shard_3replicas │         1 │            1 │           2 │ ch2       │ 172.17.0.3   │ 9001 │        0 │ default │                  │
│ cluster_1shard_3replicas │         1 │            1 │           3 │ ch3       │ 172.17.0.4   │ 9002 │        0 │ default │                  │
└──────────────────────────┴───────────┴──────────────┴─────────────┴───────────┴──────────────┴──────┴──────────┴─────────┴──────────────────┘
```

```sql
SHOW CREATE TABLE distributed_table_1shard_3replicas;

CREATE TABLE default.distributed_table_1shard_3replicas
(
    `dummy` UInt8
)
ENGINE = Distributed('cluster_1shard_3replicas', 'system', 'one', rand())
```