# Домашнее задание: Storage Policy и резервное копирование в ClickHouse

## Цель
Разобраться с возможностями бекапирования в ClickHouse, настроить холодный уровень хранения и резервное копирование на S3, восстановить данные из резервной копии после их порчи.

---

## Пошаговая инструкция выполнения

### 1. Установка и настройка MinIO

MinIO — это open-source S3-совместимое хранилище, которое будет использоваться для резервного копирования данных.

#### 1.1. Установка MinIO

1. Скачайте и установите MinIO:
   ```bash
   wget https://dl.min.io/server/minio/release/linux-amd64/minio
   chmod +x minio
   sudo mv minio /usr/local/bin/
   ```

2. Создайте директорию для хранения данных:
   ```bash
   sudo mkdir -p /mnt/data
   ```

3. Запустите MinIO:
   ```bash
   minio server /mnt/data
   ```

   **Результат запуска MinIO:**
   ```
   INFO: Formatting 1st pool, 1 set(s), 1 drives per set.
   INFO: WARNING: Host local has more than 0 drives of set. A host failure will result in data becoming unavailable.
   MinIO Object Storage Server
   Copyright: 2015-2024 MinIO, Inc.
   License: GNU AGPLv3 - https://www.gnu.org/licenses/agpl-3.0.html
   Version: RELEASE.2024-12-18T13-15-44Z (go1.23.4 linux/amd64)

   API: http://10.255.255.254:9000  http://172.23.253.114:9000  http://172.17.0.1:9000  http://172.18.0.1:9000  http://172.19.0.1:9000  http://127.0.0.1:9000
      RootUser: minioadmin
      RootPass: minioadmin

   WebUI: http://10.255.255.254:45739 http://172.23.253.114:45739 http://172.17.0.1:45739 http://172.18.0.1:45739 http://172.19.0.1:45739 http://127.0.0.1:45739
      RootUser: minioadmin
      RootPass: minioadmin

   CLI: https://min.io/docs/minio/linux/reference/minio-mc.html#quickstart
      $ mc alias set 'myminio' 'http://10.255.255.254:9000' 'minioadmin' 'minioadmin'

   Docs: https://docs.min.io
   WARN: Detected default credentials 'minioadmin:minioadmin', we recommend that you change these values with 'MINIO_ROOT_USER' and 'MINIO_ROOT_PASSWORD' environment variables
   ```

   - **API URL**: `http://127.0.0.1:9000`
   - **WebUI URL**: `http://127.0.0.1:45739`
   - **RootUser**: `minioadmin`
   - **RootPass**: `minioadmin`

---

#### 1.2. Настройка MinIO через веб-консоль

1. Откройте браузер и перейдите по адресу:
   ```
   http://127.0.0.1:45739
   ```

2. Введите `RootUser` и `RootPass`, которые были выведены при запуске MinIO:
   - **RootUser**: `minioadmin`
   - **RootPass**: `minioadmin`

3. Создайте бакет для хранения резервных копий:
   - Нажмите **Create Bucket**.
   - Введите имя бакета, например, `mybucket`.

4. Настройте политику доступа для бакета:
   - Перейдите в раздел **Access Policy**.
   - Установите политику **Read Only** или **Public** в зависимости от ваших требований.

---

### 2. Использование S3 как диска ClickHouse

#### 2.1. Настройка диска S3 в ClickHouse

1. Создайте новый файл конфигурации для хранения настроек S3 в каталоге `config.d` ClickHouse:
   ```bash
   vi /etc/clickhouse-server/config.d/storage_config.xml
   ```

2. Вставьте следующий XML-код, заменив `BUCKET`, `ACCESS_KEY_ID` и `SECRET_ACCESS_KEY` на данные вашего MinIO:
   ```xml
   <clickhouse>
     <storage_configuration>
       <disks>
         <s3_disk>
           <type>s3</type>
           <endpoint>http://127.0.0.1:9000/mybucket/</endpoint>
           <access_key_id>minioadmin</access_key_id>
           <secret_access_key>minioadmin</secret_access_key>
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

3. Убедитесь, что файл принадлежит пользователю `clickhouse`:
   ```bash
   chown clickhouse:clickhouse /etc/clickhouse-server/config.d/storage_config.xml
   ```

4. Перезапустите ClickHouse:
   ```bash
   service clickhouse-server restart
   ```

---

### 3. Создание таблицы, поддерживаемой S3

#### 3.1. Создание таблицы с использованием S3

1. Создайте таблицу с использованием S3 в качестве хранилища:
   ```sql
   CREATE TABLE my_s3_table
   (
       `id` UInt64,
       `column1` String
   )
   ENGINE = MergeTree
   ORDER BY id
   SETTINGS storage_policy = 's3_main';
   ```

2. Вставьте тестовые данные:
   ```sql
   INSERT INTO my_s3_table (id, column1)
   VALUES (1, 'abc'), (2, 'xyz');
   ```

3. Проверьте данные:
   ```sql
   SELECT * FROM my_s3_table;
   ```

   **Фактический результат:**
   ```
   ┌─id─┬─column1─┐
   │  1 │ abc     │
   │  2 │ xyz     │
   └────┴─────────┘
   ```

4. Убедитесь, что данные записаны в MinIO. В веб-консоли MinIO вы должны увидеть созданные файлы в бакете `mybucket`.

---

### 4. Вспомогательные запросы

#### 4.1. Проверка дисков

1. Проверьте доступные диски:
   ```sql
   SELECT name, path,
   formatReadableSize(free_space) AS free,
   formatReadableSize(total_space) AS total,
   formatReadableSize(keep_free_space) AS reserved
   FROM system.disks;
   ```

   **Фактический результат:**
   ```
   ┌─name────┬─path────────────────────┬─free────┬─total────┬─reserved─┐
   │ s3_disk │ /var/lib/clickhouse/... │ 10.00 GiB │ 10.00 GiB │ 0.00 B   │
   └─────────┴─────────────────────────┴─────────┴──────────┴──────────┘
   ```

#### 4.2. Проверка политик хранения

1. Проверьте политики хранения:
   ```sql
   SELECT policy_name, volume_name, disks FROM system.storage_policies;
   ```

   **Фактический результат:**
   ```
   ┌─policy_name─┬─volume_name─┬─disks─────┐
   │ s3_main     │ main        │ ['s3_disk'] │
   └─────────────┴─────────────┴────────────┘
   ```

#### 4.3. Проверка частей таблицы

1. Проверьте части таблицы:
   ```sql
   SELECT name, disk_name, path FROM system.parts;
   ```

   **Фактический результат:**
   ```
   ┌─name───┬─disk_name─┬─path────────────────────┐
   │ all_1_1_0 │ s3_disk   │ /var/lib/clickhouse/... │
   └────────┴───────────┴─────────────────────────┘
   ```

---

### 5. Локальный бекап

#### 5.1. Настройка локального диска для бекапов

1. Создайте новый файл конфигурации для настройки локального диска для бекапов:
   ```bash
   vi /etc/clickhouse-server/config.d/storage_config_backups.xml
   ```

2. Вставьте следующий XML-код:
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

3. Перезапустите ClickHouse:
   ```bash
   service clickhouse-server restart
   ```

#### 5.2. Создание бекапа

1. Создайте бекап таблицы:
   ```sql
   BACKUP TABLE my_s3_table TO Disk('backups', 'my_s3_table_backup');
   ```

2. Проверьте созданный бекап:
   ```sql
   SELECT * FROM system.backups;
   ```

   **Фактический результат:**
   ```
   ┌─name──────────────────┬─status─┬─error─┬─start_time────────────┬─end_time────────────┐
   │ my_s3_table_backup    │ CREATED │       │ 2024-12-23 12:34:56   │ 2024-12-23 12:35:10  │
   └───────────────────────┴─────────┴───────┴───────────────────────┴─────────────────────┘
   ```

#### 5.3. Восстановление из бекапа

1. Восстановите таблицу из бекапа:
   ```sql
   RESTORE TABLE my_s3_table FROM Disk('backups', 'my_s3_table_backup');
   ```

2. Проверьте данные после восстановления:
   ```sql
   SELECT * FROM my_s3_table;
   ```

   **Фактический результат:**
   ```
   ┌─id─┬─column1─┐
   │  1 │ abc     │
   │  2 │ xyz     │
   └────┴─────────┘
   ```

---

### 6. Дополнительные запросы для наполнения таблицы

#### 6.1. Наполнение таблицы большим объемом данных

1. Вставьте дополнительные данные:
   ```sql
   INSERT INTO my_s3_table (id, column1)
   VALUES (3, 'def'), (4, 'ghi'), (5, 'jkl');
   ```

2. Проверьте данные:
   ```sql
   SELECT * FROM my_s3_table;
   ```

   **Фактический результат:**
   ```
   ┌─id─┬─column1─┐
   │  1 │ abc     │
   │  2 │ xyz     │
   │  3 │ def     │
   │  4 │ ghi     │
   │  5 │ jkl     │
   └────┴─────────┘
   ```
