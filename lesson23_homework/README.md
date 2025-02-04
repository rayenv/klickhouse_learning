Для выполнения задачи мы будем использовать Airbyte как ETL-инструмент и ClickHouse как БД-приемник.
гайд по разворачиванию Airbyte:
https://docs.airbyte.com/using-airbyte/getting-started/oss-quickstart#install-abctl-the-fast-way-mac-linux
![alt text](image.png)![alt text]({B1170D1F-70A7-4251-BC5A-1039E44A46E5}.png)
2. Откройте веб-интерфейс Airbyte по адресу http://localhost:8000

![2](2025-02-04_23-32.png)

почту вводим любую, pwd вернёт команда
```bash
abctl local credentials
```
3. Настройка источника данных (Source):
API через url https://jsonplaceholder.typicode.com/users
![alt text](image-1.png)

4. Настройка приемника данных (Destination):
- Нажмите "Add destination"
- Выберите ClickHouse
- Заполните параметры подключения:
  * Host: clickhouse
  * Port: 8123
  * Database: default
  * Username: default
  * Password: оставить пустым
![alt text](image-2.png)

5. Создание синхронизации:
- Нажмите "Create connection"
- Выберите настроенный Source и Destination
- Выберите таблицы/коллекции для синхронизации
- Настройте режим синхронизации (полная/инкрементальная)
- Установите расписание выполнения
![alt text]({1B4510C7-3CC9-42AF-8D91-F0AF05825E4E}.png)

6. Проверка данных в ClickHouse:

![alt text](image-3.png)