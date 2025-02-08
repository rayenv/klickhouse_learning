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
read -p "$(echo -e "${YELLOW}Введите порт ClickHouse (например, 8123): ${NC}")" PORT
read -p "$(echo -e "${YELLOW}Введите имя пользователя ClickHouse: ${NC}")" USER
read -s -p "$(echo -e "${YELLOW}Введите пароль пользователя ClickHouse: ${NC}")" PASSWORD
echo
read -p "$(echo -e "${YELLOW}Введите название базы данных для бэкапа: ${NC}")" DATABASE
read -p "$(echo -e "${YELLOW}Введите путь для сохранения бэкапа (например, /backups): ${NC}")" BACKUP_DIR

# Проверка существования директории для бэкапов
if [ ! -d "$BACKUP_DIR" ]; then
    log_message "${RED}Директория $BACKUP_DIR не существует. Создаю...${NC}"
    mkdir -p "$BACKUP_DIR"
fi

# Получение списка таблиц и их размеров
print_header "Анализ таблиц в базе данных $DATABASE"

TABLES_INFO=$(curl -sS --user "$USER:$PASSWORD" "http://$HOST:$PORT/?database=$DATABASE&query=SELECT+name,+data_compressed_bytes+FROM+system.tables+WHERE+database='$DATABASE'")
if [ $? -ne 0 ]; then
    log_message "${RED}Не удалось получить информацию о таблицах. Проверьте подключение.${NC}"
    exit 1
fi

# Парсинг таблиц и их размеров
declare -A TABLE_SIZES
while IFS=$'\t' read -r TABLE SIZE; do
    TABLE_SIZES["$TABLE"]=$SIZE
done <<< "$TABLES_INFO"

# Вывод информации о таблицах
log_message "${GREEN}Список таблиц и их размеры:${NC}"
for TABLE in "${!TABLE_SIZES[@]}"; do
    SIZE=${TABLE_SIZES[$TABLE]}
    HUMAN_SIZE=$(numfmt --to=iec --suffix=B --padding=7 "$SIZE")
    log_message "${YELLOW}$TABLE${NC}: ${HUMAN_SIZE}"
done

# Выбор таблиц для бэкапа
log_message "${YELLOW}Введите названия таблиц для бэкапа через пробел (или 'all' для всех): ${NC}"
read -r TABLE_SELECTION

# Определение выбранных таблиц
if [[ "$TABLE_SELECTION" == "all" ]]; then
    SELECTED_TABLES=("${!TABLE_SIZES[@]}")
else
    read -ra SELECTED_TABLES <<< "$TABLE_SELECTION"
fi

# Проверка корректности выбранных таблиц
INVALID_TABLES=()
for TABLE in "${SELECTED_TABLES[@]}"; do
    if [[ -z "${TABLE_SIZES[$TABLE]}" ]]; then
        INVALID_TABLES+=("$TABLE")
    fi
done

if [ ${#INVALID_TABLES[@]} -ne 0 ]; then
    log_message "${RED}Некорректные таблицы: ${INVALID_TABLES[*]}. Пожалуйста, повторите выбор.${NC}"
    exit 1
fi

# Запрос на использование параллельного бэкапа
log_message "${YELLOW}Хотите выполнить бэкап параллельно? (yes/no): ${NC}"
read -r PARALLEL_BACKUP

# Выполнение бэкапа
print_header "Выполняется бэкап выбранных таблиц..."

TIMESTAMP=$(date +"%Y%m%d%H%M%S")
TEMP_BACKUP_DIR=$(mktemp -d)

SUCCESSFUL_BACKUPS=0
FAILED_BACKUPS=()

# Функция для бэкапа одной таблицы
backup_table() {
    TABLE=$1
    BACKUP_FILE="$TEMP_BACKUP_DIR/$DATABASE-$TABLE-$TIMESTAMP.sql"
    curl -sS --user "$USER:$PASSWORD" "http://$HOST:$PORT/?database=$DATABASE&query=SELECT+*+FROM+$TABLE+FORMAT+SQLInsert" > "$BACKUP_FILE"
    if [ $? -ne 0 ]; then
        echo "$TABLE"
    else
        echo ""
    fi
}

# Выполнение бэкапа в зависимости от выбора пользователя
if [[ "$PARALLEL_BACKUP" == "yes" ]]; then
    log_message "${GREEN}Бэкап выполняется параллельно...${NC}"
    FAILED_TABLES=$(printf "%s\n" "${SELECTED_TABLES[@]}" | xargs -n 1 -P 4 -I {} bash -c 'backup_table "$@"' _ {})
else
    log_message "${GREEN}Бэкап выполняется последовательно...${NC}"
    for TABLE in "${SELECTED_TABLES[@]}"; do
        FAILED_TABLE=$(backup_table "$TABLE")
        if [[ -n "$FAILED_TABLE" ]]; then
            FAILED_BACKUPS+=("$FAILED_TABLE")
        else
            SUCCESSFUL_BACKUPS=$((SUCCESSFUL_BACKUPS + 1))
        fi
    done
fi

# Обработка результатов параллельного бэкапа
if [[ "$PARALLEL_BACKUP" == "yes" ]]; then
    for TABLE in $FAILED_TABLES; do
        if [[ -n "$TABLE" ]]; then
            FAILED_BACKUPS+=("$TABLE")
        else
            SUCCESSFUL_BACKUPS=$((SUCCESSFUL_BACKUPS + 1))
        fi
    done
fi

# Запрос на архивацию бэкапов
log_message "${YELLOW}Хотите архивировать бэкапы? (yes/no): ${NC}"
read -r ARCHIVE_BACKUP

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