#!/bin/bash

# Файл лога
LOG_FILE="backup_clickhouse.log"

# Перенаправление всего вывода в файл лога
exec > >(tee -a "$LOG_FILE") 2>&1

# Проверка поддержки цветов
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# Функция для вывода заголовков
print_header() {
    echo -e "${BLUE}***********************************************${NC}"
    echo -e "${BLUE}* $1 ${NC}"
    echo -e "${BLUE}***********************************************${NC}"
}

# Функция для получения статистики по таблицам
get_table_stats() {
    local DATABASE=$1
    local TABLE=$2

    # Запрос для подсчета строк
    ROWS_COUNT=$(curl -sS $CURL_OPTS "$PROTOCOL://$HOST:$PORT/?database=$DATABASE&query=SELECT+COUNT(*)+FROM+$TABLE" 2>/dev/null)
    if [[ -z "$ROWS_COUNT" || "$ROWS_COUNT" =~ [^0-9] ]]; then
        ROWS_COUNT="N/A"
    fi

    # Запрос для получения объема данных в байтах
    TABLE_SIZE_BYTES=$(curl -sS $CURL_OPTS "$PROTOCOL://$HOST:$PORT/?query=SELECT+sum(bytes)+FROM+system.parts+WHERE+database='$DATABASE'+AND+table='$TABLE'+AND+active=1" 2>/dev/null)
    if [[ -z "$TABLE_SIZE_BYTES" || "$TABLE_SIZE_BYTES" =~ [^0-9] ]]; then
        TABLE_SIZE_MB="N/A"
    else
        # Конвертируем байты в мегабайты с округлением до двух знаков после запятой
        TABLE_SIZE_MB=$(echo "scale=2; $TABLE_SIZE_BYTES / (1024 * 1024)" | bc 2>/dev/null || echo "N/A")
    fi

    # Возвращаем результат
    echo "$ROWS_COUNT|$TABLE_SIZE_MB"
}

# Начало отсчета времени выполнения
START_TIME=$(date +%s)

# Запрос данных у пользователя
print_header "Настройка подключения к ClickHouse"

# Ввод хоста
read -p "$(echo -e "${YELLOW}Введите хост ClickHouse (например, localhost) [по умолчанию: localhost]: ${NC}")" HOST
HOST=${HOST:-localhost} # Используем localhost по умолчанию

# Ввод порта
read -p "$(echo -e "${YELLOW}Введите порт ClickHouse (например, 8123) [по умолчанию: 8123]: ${NC}")" PORT
PORT=${PORT:-8123} # Используем 8123 по умолчанию

# Ввод имени пользователя
read -p "$(echo -e "${YELLOW}Введите имя пользователя ClickHouse (по умолчанию: default): ${NC}")" USER
USER=${USER:-default} # Используем default по умолчанию

# Ввод пароля
read -s -p "$(echo -e "${YELLOW}Введите пароль пользователя ClickHouse (оставьте пустым, если пароль не требуется): ${NC}")" PASSWORD
echo

# Запрос на использование самоподписанных сертификатов
read -p "$(echo -e "${YELLOW}Использовать самоподписанный сертификат? (yes/no): ${NC}")" USE_INSECURE_SSL

# Определение протокола и опций для curl
CURL_OPTS="--max-time 10" # Таймаут 10 секунд
if [[ -n "$USER" ]]; then
    if [[ -n "$PASSWORD" ]]; then
        CURL_OPTS="$CURL_OPTS --user $USER:$PASSWORD"
    else
        CURL_OPTS="$CURL_OPTS --user $USER:"
    fi
fi

if [[ "$USE_INSECURE_SSL" == "yes" ]]; then
    PROTOCOL="https"
    CURL_OPTS="$CURL_OPTS --insecure"
else
    PROTOCOL="http"
fi

# Проверка подключения к ClickHouse
check_connection() {
    echo -e "Проверка подключения к ClickHouse..."
    TEST_QUERY="SHOW+DATABASES"
    RESPONSE=$(curl -sS $CURL_OPTS "$PROTOCOL://$HOST:$PORT/?query=$TEST_QUERY" 2>&1)
    if [[ $? -eq 0 && -n "$RESPONSE" ]]; then
        echo -e "${GREEN}Подключение к ClickHouse успешно установлено. ${NC}"
        return 0
    else
        echo -e "${RED}Не удалось подключиться к ClickHouse. Проверьте введенные данные. ${NC}"
        echo -e "${RED}Ответ сервера: $RESPONSE ${NC}"
        return 1
    fi
}

# Проверка подключения
if ! check_connection; then
    echo -e "${RED}Выход из скрипта. ${NC}"
    exit 1
fi

# Получение списка баз данных
print_header "Анализ доступных баз данных"
DATABASES_INFO=$(curl -sS $CURL_OPTS "$PROTOCOL://$HOST:$PORT/?query=SHOW+DATABASES" 2>/dev/null)
if [ $? -ne 0 ]; then
    echo -e "${RED}Не удалось получить список баз данных. Проверьте подключение. ${NC}"
    exit 1
fi

# Вывод списка баз данных
echo -e "${GREEN}Список доступных баз данных: ${NC}"
for DATABASE in $DATABASES_INFO; do
    echo -e "${YELLOW}- $DATABASE ${NC}"
done

# Выбор баз данных для анализа
while true; do
    echo -e "${YELLOW}Введите названия баз данных через пробел: ${NC}"
    echo -e "${YELLOW}- или 'all' для выбора всех баз данных ${NC}"
    read -r DB_SELECTION

    if [[ "$DB_SELECTION" == "all" ]]; then
        SELECTED_DATABASES=($DATABASES_INFO)
        break
    else
        # Разбиваем ввод на массив
        read -ra SELECTED_DATABASES <<< "$DB_SELECTION"

        # Проверяем корректность выбранных баз данных
        INVALID_DATABASES=()
        for DATABASE in "${SELECTED_DATABASES[@]}"; do
            if ! [[ " $DATABASES_INFO " =~ " $DATABASE " ]]; then
                INVALID_DATABASES+=("$DATABASE")
            fi
        done

        if [ ${#INVALID_DATABASES[@]} -ne 0 ]; then
            echo -e "${RED}Некорректные базы данных: ${INVALID_DATABASES[*]}. Пожалуйста, повторите выбор. ${NC}"
        else
            break
        fi
    fi
done

# Сбор статистики для выбранных баз данных
declare -A DATABASE_TABLES
declare -A TABLE_STATS
for DATABASE in "${SELECTED_DATABASES[@]}"; do
    print_header "Анализ таблиц в базе '$DATABASE'"
    TABLES_INFO=$(curl -sS $CURL_OPTS "$PROTOCOL://$HOST:$PORT/?database=$DATABASE&query=SHOW+TABLES" 2>/dev/null)
    if [ $? -eq 0 ]; then
        DATABASE_TABLES["$DATABASE"]="$TABLES_INFO"
        echo -e "${YELLOW}Таблицы в базе '$DATABASE': ${NC}"
        for TABLE in $TABLES_INFO; do
            STATS=$(get_table_stats "$DATABASE" "$TABLE")
            ROWS_COUNT=$(echo "$STATS" | cut -d'|' -f1)
            TABLE_SIZE_MB=$(echo "$STATS" | cut -d'|' -f2)
            echo -e "  - $TABLE (строк: ${ROWS_COUNT:-N/A}, размер: ${TABLE_SIZE_MB:-N/A} MB)"
            echo -e "${BLUE}***********************************************${NC}"
            TABLE_STATS["$DATABASE:$TABLE"]=$STATS
        done
    else
        echo -e "${RED}Не удалось получить список таблиц для базы '$DATABASE'. Пропускаем... ${NC}"
    fi
done

# Выбор таблиц для бэкапа
declare -A SELECTED_TABLES
for DATABASE in "${SELECTED_DATABASES[@]}"; do
    echo -e "${YELLOW}Выберите таблицы для бэкапа в базе '$DATABASE': ${NC}"
    echo -e "${YELLOW}- или 'all' для бекапа всех таблиц ${NC}"
    echo -e "${YELLOW}- или '-' для отказа от бекапа таблиц этой базы: ${NC}"
    read -r TABLE_SELECTION

    if [[ "$TABLE_SELECTION" == "-" ]]; then
        echo -e "${YELLOW} Бэкап таблиц базы '$DATABASE' пропущен. ${NC}"
        continue
    elif [[ "$TABLE_SELECTION" == "all" ]]; then
        SELECTED_TABLES["$DATABASE"]="${DATABASE_TABLES[$DATABASE]}"
    else
        # Разбиваем ввод на массив
        read -ra SELECTED_TABLES_ARRAY <<< "$TABLE_SELECTION"

        # Проверяем корректность выбранных таблиц
        INVALID_TABLES=()
        for TABLE in "${SELECTED_TABLES_ARRAY[@]}"; do
            if ! [[ " ${DATABASE_TABLES[$DATABASE]} " =~ " $TABLE " ]]; then
                INVALID_TABLES+=("$TABLE")
            fi
        done

        if [ ${#INVALID_TABLES[@]} -ne 0 ]; then
            echo -e "${RED}Некорректные таблицы: ${INVALID_TABLES[*]}. Пожалуйста, повторите выбор. ${NC}"
            ((--i)) # Возвращаемся к предыдущей итерации
            continue
        else
            SELECTED_TABLES["$DATABASE"]="${SELECTED_TABLES_ARRAY[@]}"
        fi
    fi
done

# Запрос на использование параллельного бэкапа
while true; do
    echo -e "${YELLOW}Хотите выполнить бэкап параллельно? ${NC}"
    echo -e "${YELLOW}- Введите 'yes' для параллельного бэкапа ${NC}"
    echo -e "${YELLOW}- Введите 'no' для последовательного бэкапа: ${NC}"
    read -r PARALLEL_BACKUP

    if [[ "$PARALLEL_BACKUP" == "yes" || "$PARALLEL_BACKUP" == "no" ]]; then
        break
    else
        echo -e "${RED}Пожалуйста, введите 'yes' или 'no'. ${NC}"
    fi
done

# Запрос на архивацию бэкапов
while true; do
    echo -e "${YELLOW}Хотите архивировать бэкапы? ${NC}"
    echo -e "${YELLOW}- Введите 'yes' для создания архива ${NC}"
    echo -e "${YELLOW}- Введите 'no' для сохранения файлов без архивации: ${NC}"
    read -r ARCHIVE_BACKUP

    if [[ "$ARCHIVE_BACKUP" == "yes" || "$ARCHIVE_BACKUP" == "no" ]]; then
        break
    else
        echo -e "${RED}Пожалуйста, введите 'yes' или 'no'. ${NC}"
    fi
done

# Выполнение бэкапа
print_header "Выполняется бэкап выбранных таблиц..."
TIMESTAMP=$(date +"%Y%m%d%H%M%S")
TEMP_BACKUP_DIR=$(mktemp -d)

SUCCESSFUL_BACKUPS=0
FAILED_BACKUPS=()

# Функция для бэкапа одной таблицы
backup_table() {
    DATABASE=$1
    TABLE=$2
    BACKUP_FILE="$TEMP_BACKUP_DIR/$DATABASE-$TABLE-$TIMESTAMP.sql"
    echo -e "Выполняется бэкап таблицы '$TABLE' из базы '$DATABASE'..."
    curl -sS $CURL_OPTS "$PROTOCOL://$HOST:$PORT/?database=$DATABASE&query=SELECT+*+FROM+$TABLE+FORMAT+SQLInsert" > "$BACKUP_FILE"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Ошибка при бэкапе таблицы '$TABLE' из базы '$DATABASE'. ${NC}"
        echo "$DATABASE:$TABLE"
    else
        echo -e "${GREEN}Бэкап таблицы '$TABLE' из базы '$DATABASE' успешно завершен. ${NC}"
        echo ""
    fi
}

# Выполнение бэкапа в зависимости от выбора пользователя
for DATABASE in "${!SELECTED_TABLES[@]}"; do
    for TABLE in ${SELECTED_TABLES["$DATABASE"]}; do
        if [[ "$PARALLEL_BACKUP" == "yes" ]]; then
            FAILED_TABLE=$(backup_table "$DATABASE" "$TABLE" &)
        else
            FAILED_TABLE=$(backup_table "$DATABASE" "$TABLE")
        fi
        if [[ -n "$FAILED_TABLE" ]]; then
            FAILED_BACKUPS+=("$FAILED_TABLE")
        else
            SUCCESSFUL_BACKUPS=$((SUCCESSFUL_BACKUPS + 1))
        fi
    done
done

# Обработка результатов параллельного бэкапа
if [[ "$PARALLEL_BACKUP" == "yes" ]]; then
    wait
fi

# Архивация бэкапов
if [[ "$ARCHIVE_BACKUP" == "yes" ]]; then
    BACKUP_ARCHIVE="$TEMP_BACKUP_DIR/$DATABASE-backup-$TIMESTAMP.tar.gz"
    echo -e "${YELLOW}Архивация бэкапов в файл: $BACKUP_ARCHIVE ${NC}"
    tar -czf "$BACKUP_ARCHIVE" -C "$TEMP_BACKUP_DIR" .
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Архив успешно создан: $BACKUP_ARCHIVE ${NC}"
    else
        echo -e "${RED}Ошибка при создании архива. ${NC}"
    fi
    # Удаление временной директории
    rm -rf "$TEMP_BACKUP_DIR"
else
    echo -e "${YELLOW}Бэкапы оставлены в виде отдельных файлов в директории: $TEMP_BACKUP_DIR ${NC}"
    mv "$TEMP_BACKUP_DIR"/* "$BACKUP_DIR/"
    rmdir "$TEMP_BACKUP_DIR"
fi

# Конец отсчета времени выполнения
END_TIME=$(date +%s)
EXECUTION_TIME=$((END_TIME - START_TIME))

# Легенда
print_header "Отчёт о работе скрипта"
echo -e "${GREEN}Результаты работы скрипта: ${NC}"
echo -e "Успешно забэкапировано таблиц: ${SUCCESSFUL_BACKUPS}"
if [ ${#FAILED_BACKUPS[@]} -ne 0 ]; then
    echo -e "${RED}Ошибки при бэкапе таблиц: ${FAILED_BACKUPS[*]} ${NC}"
fi
if [[ "$ARCHIVE_BACKUP" == "yes" ]]; then
    echo -e "Архив бэкапа: ${BACKUP_ARCHIVE} "
else
    echo -e "Бэкапы находятся в директории: ${TEMP_BACKUP_DIR} "
fi
echo -e "Файл логов: $(pwd)/${LOG_FILE} "
echo -e "Время выполнения скрипта: ${EXECUTION_TIME} секунд "
print_header "Завершение работы скрипта"