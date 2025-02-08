#!/bin/bash

# Цветовые константы
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция для вывода заголовков
print_header() {
    echo -e "${BLUE}***********************************************${NC}"
    echo -e "${BLUE}* $1${NC}"
    echo -e "${BLUE}***********************************************${NC}"
}

# Логирование
LOG_FILE="backup_clickhouse.log"
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Начало отсчета времени выполнения
START_TIME=$(date +%s)

# Запрос данных у пользователя
print_header "Настройка подключения к ClickHouse"

read -p "$(echo -e "${YELLOW}Введите хост ClickHouse (например, localhost): ${NC}")" HOST
read -p "$(echo -e "${YELLOW}Введите порт ClickHouse (например, 8443): ${NC}")" PORT
read -p "$(echo -e "${YELLOW}Введите имя пользователя ClickHouse: ${NC}")" USER
read -s -p "$(echo -e "${YELLOW}Введите пароль пользователя ClickHouse: ${NC}")" PASSWORD
echo
read -p "$(echo -e "${YELLOW}Использовать самоподписанный сертификат? (yes/no): ${NC}")" USE_INSECURE_SSL
read -p "$(echo -e "${YELLOW}Введите путь для сохранения бэкапа (например, /backups): ${NC}")" BACKUP_DIR

# Проверка существования директории для бэкапов
if [ ! -d "$BACKUP_DIR" ]; then
    log_message "${RED}Директория $BACKUP_DIR не существует. Создаю...${NC}"
    mkdir -p "$BACKUP_DIR"
fi

# Опции для curl
CURL_OPTS="--user $USER:$PASSWORD"
if [[ "$USE_INSECURE_SSL" == "yes" ]]; then
    CURL_OPTS="$CURL_OPTS --insecure"
else
    CURL_OPTS="$CURL_OPTS --cacert /path/to/ca-cert.pem" # Укажите путь к CA-сертификату, если требуется
fi

# Получение списка баз данных
print_header "Анализ доступных баз данных"

DATABASES_INFO=$(curl -sS $CURL_OPTS "https://$HOST:$PORT/?query=SHOW+DATABASES")
if [ $? -ne 0 ]; then
    log_message "${RED}Не удалось получить список баз данных. Проверьте подключение.${NC}"
    exit 1
fi

# Парсинг баз данных
declare -A DATABASE_TABLES
for DATABASE in $DATABASES_INFO; do
    if [[ "$DATABASE" != "system" && "$DATABASE" != "default" ]]; then
        TABLES_INFO=$(curl -sS $CURL_OPTS "https://$HOST:$PORT/?database=$DATABASE&query=SHOW+TABLES")
        if [ $? -eq 0 ]; then
            DATABASE_TABLES["$DATABASE"]="$TABLES_INFO"
        fi
    fi
done

# Вывод информации о базах данных и таблицах
log_message "${GREEN}Список доступных баз данных и таблиц:${NC}"
for DATABASE in "${!DATABASE_TABLES[@]}"; do
    echo -e "${YELLOW}База данных: $DATABASE${NC}"
    echo -e "Таблицы:"
    for TABLE in ${DATABASE_TABLES["$DATABASE"]}; do
        echo -e "  - $TABLE"
    done
done

# Выбор баз данных и таблиц для бэкапа
log_message "${YELLOW}Введите названия баз данных для бэкапа через пробел (или 'all' для всех): ${NC}"
read -r DB_SELECTION

# Определение выбранных баз данных
if [[ "$DB_SELECTION" == "all" ]]; then
    SELECTED_DATABASES=("${!DATABASE_TABLES[@]}")
else
    read -ra SELECTED_DATABASES <<< "$DB_SELECTION"
fi

# Проверка корректности выбранных баз данных
INVALID_DATABASES=()
for DATABASE in "${SELECTED_DATABASES[@]}"; do
    if [[ -z "${DATABASE_TABLES[$DATABASE]}" ]]; then
        INVALID_DATABASES+=("$DATABASE")
    fi
done

if [ ${#INVALID_DATABASES[@]} -ne 0 ]; then
    log_message "${RED}Некорректные базы данных: ${INVALID_DATABASES[*]}. Пожалуйста, повторите выбор.${NC}"
    exit 1
fi

# Выбор таблиц для каждой базы данных
declare -A SELECTED_TABLES
for DATABASE in "${SELECTED_DATABASES[@]}"; do
    log_message "${YELLOW}Выберите таблицы для бэкапа в базе '$DATABASE' через пробел (или 'all' для всех): ${NC}"
    read -r TABLE_SELECTION
    if [[ "$TABLE_SELECTION" == "all" ]]; then
        SELECTED_TABLES["$DATABASE"]="${DATABASE_TABLES[$DATABASE]}"
    else
        read -ra SELECTED_TABLES["$DATABASE"] <<< "$TABLE_SELECTION"
    fi
done

# Запрос на использование параллельного бэкапа
log_message "${YELLOW}Хотите выполнить бэкап параллельно? (yes/no): ${NC}"
read -r PARALLEL_BACKUP

# Запрос на архивацию бэкапов
log_message "${YELLOW}Хотите архивировать бэкапы? (yes/no): ${NC}"
read -r ARCHIVE_BACKUP

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
    curl -sS $CURL_OPTS "https://$HOST:$PORT/?database=$DATABASE&query=SELECT+*+FROM+$TABLE+FORMAT+SQLInsert" > "$BACKUP_FILE"
    if [ $? -ne 0 ]; then
        echo "$DATABASE:$TABLE"
    else
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
    BACKUP_ARCHIVE="$BACKUP_DIR/$DATABASE-backup-$TIMESTAMP.tar.gz"
    log_message "${YELLOW}Архивация бэкапов в файл: $BACKUP_ARCHIVE${NC}"
    tar -czf "$BACKUP_ARCHIVE" -C "$TEMP_BACKUP_DIR" .
    if [ $? -eq 0 ]; then
        log_message "${GREEN}Архив успешно создан: $BACKUP_ARCHIVE${NC}"
    else
        log_message "${RED}Ошибка при создании архива.${NC}"
    fi
    # Удаление временной директории
    rm -rf "$TEMP_BACKUP_DIR"
else
    log_message "${YELLOW}Бэкапы оставлены в виде отдельных файлов в директории: $TEMP_BACKUP_DIR${NC}"
    mv "$TEMP_BACKUP_DIR"/* "$BACKUP_DIR/"
    rmdir "$TEMP_BACKUP_DIR"
fi

# Конец отсчета времени выполнения
END_TIME=$(date +%s)
EXECUTION_TIME=$((END_TIME - START_TIME))

# Легенда
print_header "Легенда завершения работы скрипта"
echo -e "${GREEN}Результаты работы скрипта:${NC}"
echo -e "Успешно забэкапировано таблиц: ${SUCCESSFUL_BACKUPS}"
if [ ${#FAILED_BACKUPS[@]} -ne 0 ]; then
    echo -e "${RED}Ошибки при бэкапе таблиц: ${FAILED_BACKUPS[*]}${NC}"
fi
if [[ "$ARCHIVE_BACKUP" == "yes" ]]; then
    echo -e "Архив бэкапа: ${BACKUP_ARCHIVE}"
else
    echo -e "Бэкапы находятся в директории: ${BACKUP_DIR}"
fi
echo -e "Файл логов: $(pwd)/${LOG_FILE}"
echo -e "Время выполнения скрипта: ${EXECUTION_TIME} секунд"

print_header "Завершение работы скрипта"