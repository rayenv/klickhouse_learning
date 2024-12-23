# Separation of Storage and Compute (ClickHouse и S3). [Source](https://clickhouse.com/docs/en/guides/separation-storage-compute)

Разделение `storage` и `compute` означает, что вычислительные ресурсы и ресурсы хранения управляются (и масштабируются) независимо друг от друга, что обеспечивает лучшую масштабируемость, экономическую эффективность и гибкость.

Использование `ClickHouse` на базе `S3` особенно полезно в тех случаях, когда производительность запросов к "холодным" данным менее критична. `ClickHouse` поддерживает использование `S3` в качестве хранилища для механизма `MergeTree` с помощью `S3BackedMergeTree`. Этот табличный механизм позволяет пользователям использовать преимущества масштабируемости и стоимости `S3`, сохраняя при этом производительность вставки и запросов механизма `MergeTree`.


### 1. Use S3 as a ClickHouse disk
Создание диска - cоздайте новый файл в каталоге `ClickHouse` `config.d` для хранения конфигурации хранилища:

Скопируйте следующий XML во вновь созданный файл, заменив `BUCKET` (для YC https://storage.yandexcloud.net/bucket-name/), `ACCESS_KEY_ID`, `SECRET_ACCESS_KEY` на данные вашего object storage бакета, в котором вы хотите хранить свои данные:

```bash
vi /etc/clickhouse-server/config.d/storage_config.xml
```
```xml
<clickhouse>
  <storage_configuration>
    <disks>
      <s3_disk>
        <type>s3</type>
        <endpoint>$BUCKET</endpoint>
        <access_key_id>$ACCESS_KEY_ID</access_key_id>
        <secret_access_key>$SECRET_ACCESS_KEY</secret_access_key>
        <metadata_path>/var/lib/clickhouse/disks/s3_disk/</metadata_path>
      </s3_disk>
      <s3_cache>
        <type>cache</type>
        <disk>s3_disk</disk>
        <path>/var/lib/clickhouse/disks/s3_cache/</path>
        <max_size>10Gi</max_size>
      </s3_cache>
    </disks>
    <policies>
      <s3_main>
        <volumes>
          <main>
            <disk>s3_disk</disk>
          </main>
        </volumes>
      </s3_main>
    </policies>
  </storage_configuration>
</clickhouse>
```

После создания файла конфигурации необходимо изменить владельца файла на пользователя и группу clickhouse и перезагрузить сервис:
```bash
chown clickhouse:clickhouse /etc/clickhouse-server/config.d/storage_config.xml

service clickhouse-server restart
```


### 2. Create a table backed by S3

Обратите внимание, что нам не нужно указывать движок `S3BackedMergeTree`. `ClickHouse` автоматически преобразует тип движка, если обнаружит, что таблица использует S3 для хранения.

```sql
CREATE TABLE my_s3_table
  (
    `id` UInt64,
    `column1` String
  )
ENGINE = MergeTree
ORDER BY id
SETTINGS storage_policy = 's3_main'; 

INSERT INTO my_s3_table (id, column1)
VALUES (1, 'abc'), (2, 'xyz');

SELECT * FROM my_s3_table;
```

Если все прошло успешно, в консоли вашего s3-провайдера вы должны увидеть созданные файлы.


# Вспомогательные запросы:
```sql
SELECT name, path,
formatReadableSize(free_space) AS free,
    formatReadableSize(total_space) AS total,
    formatReadableSize(keep_free_space) AS reserved
FROM system.disks;

select policy_name, volume_name, disks from system.storage_policies;

SELECT name, disk_name, path FROM system.parts;

SELECT name, data_paths, metadata_path, storage_policy
FROM system.tables WHERE name LIKE 'sample%';
```

### Локальный бекап
```bash
vi /etc/clickhouse-server/config.d/storage_config_backups.xml
```
```xml
<clickhouse>
    <storage_configuration>
        <disks>
            <backups>
                <type>local</type>
                <path>/tmp/backups/</path>
            </backups>
        </disks>
    </storage_configuration>
    <backups>
        <allowed_disk>backups</allowed_disk>
        <allowed_path>/tmp/backups/</allowed_path>
    </backups>
</clickhouse>
```

```sql
BACKUP database default TO Disk('backups', 'default');

BACKUP table default.trips TO Disk('backups', 'default_trips');

RESTORE table default.trips FROM Disk('backups', 'default_trips');

select *
from system.backups;
```
