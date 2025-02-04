# Базовый образ Apache Superset
FROM apache/superset:2.1.0

# Установка необходимых пакетов Python
RUN pip install --no-cache-dir clickhouse-connect

# Копирование конфигурационного файла (если необходимо)
COPY superset_config.py /app/superset_config.py

# Запуск приложения
CMD ["superset", "run", "-h", "0.0.0.0", "-p", "8088"]