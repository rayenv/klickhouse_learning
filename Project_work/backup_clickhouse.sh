#!/bin/bash
# Файл лога
LOG_FILE="backup_clickhouse.log"
# Перенаправление всего вывода в файл лога
exec > >(tee -a "$LOG_FILE") 2>&1

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция для вывода заголовков
print_header() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${BLUE}***********************************************${NC}"
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${BLUE}* $1${NC}"
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${BLUE}***********************************************${NC}"
}

# Начало отсчета времени выполнения
START_TIME=$(date +%s)

# Запрос данных у пользователя
print_header "Настройка подключения к ClickHouse"

# Ввод хоста
read -p "$(echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${YELLOW}Введите хост ClickHouse (например, localhost) [по умолчанию: localhost]: ${NC}")" HOST
HOST=${HOST:-localhost} # Используем localhost по умолчанию

# Ввод порта
read -p "$(echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${YELLOW}Введите порт ClickHouse (например, 8123) [по умолчанию: 8123]: ${NC}")" PORT
PORT=${PORT:-8123} # Используем 8123 по умолчанию

# Ввод имени пользователя
read -p "$(echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${YELLOW}Введите имя пользователя ClickHouse (по умолчанию: default): ${NC}")" USER
USER=${USER:-default} # Используем default по умолчанию

# Ввод пароля
read -s -p "$(echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${YELLOW}Введите пароль пользователя ClickHouse (оставьте пустым, если пароль не требуется): ${NC}")" PASSWORD
echo

# Запрос на выбор протокола (HTTP или HTTPS)
while true; do
    read -p "$(echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${YELLOW}Выберите протокол для подключения к ClickHouse (http/https) (по умолчанию: http): ${NC}")" PROTOCOL
    PROTOCOL=${PROTOCOL:-http}
    if [[ "$PROTOCOL" == "http" || "$PROTOCOL" == "https" ]]; then
        break
    else
        echo -e "${RED}Пожалуйста, введите 'http' или 'https'.${NC}"
    fi
done

# Определение опций для curl
CURL_OPTS="--user $USER:$PASSWORD --max-time 10" # Таймаут 10 секунд
if [[ "$PROTOCOL" == "https" ]]; then
    CURL_OPTS="$CURL_OPTS --insecure" # Добавляем флаг --insecure для HTTPS
fi

# Добавляем запрос на выбор директории
print_header "Выбор директории для сохранения бэкапа"
DEFAULT_BACKUP_DIR=$(pwd)
read -p "$(echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${YELLOW}Введите путь к директории для сохранения бэкапа [по умолчанию: $DEFAULT_BACKUP_DIR/backup]: ${NC}")" BACKUP_DIR
BACKUP_DIR=${BACKUP_DIR:-$DEFAULT_BACKUP_DIR/backup}

# Проверка существования директории
if [[ ! -d "$BACKUP_DIR" ]]; then
    echo -e "${YELLOW}Директория '$BACKUP_DIR' не существует. Создать её? (yes/no): ${NC}"
    read -r CREATE_DIR
    if [[ "$CREATE_DIR" == "yes" ]]; then
        mkdir -p "$BACKUP_DIR"
        if [[ $? -ne 0 ]]; then
            echo -e "${RED}Не удалось создать директорию '$BACKUP_DIR'. Используется директория по умолчанию: $DEFAULT_BACKUP_DIR${NC}"
            BACKUP_DIR=$DEFAULT_BACKUP_DIR
        else
            echo -e "${GREEN}Директория '$BACKUP_DIR' успешно создана.${NC}"
        fi
    else
        echo -e "${YELLOW}Используется директория по умолчанию: $DEFAULT_BACKUP_DIR${NC}"
        BACKUP_DIR=$DEFAULT_BACKUP_DIR
    fi
fi

# Убедимся, что директория доступна для записи
if [[ ! -w "$BACKUP_DIR" ]]; then
    echo -e "${RED}Нет прав на запись в директорию '$BACKUP_DIR'. Используется директория по умолчанию: $DEFAULT_BACKUP_DIR${NC}"
    BACKUP_DIR=$DEFAULT_BACKUP_DIR
fi

echo -e "${GREEN}Бэкапы будут сохраняться в директории: $BACKUP_DIR${NC}"

# Проверка подключения к ClickHouse
print_header "Проверка подключения к ClickHouse"
CHECK_CONNECTION=$(curl -sS $CURL_OPTS "$PROTOCOL://$HOST:$PORT/?query=SELECT+1" 2>/dev/null)
if [[ "$CHECK_CONNECTION" == "1" ]]; then
    echo -e "${GREEN}Подключение к ClickHouse успешно установлено.${NC}"
else
    echo -e "${RED}Не удалось подключиться к ClickHouse. Проверьте параметры подключения.${NC}"
    exit 1
fi

# Получение списка баз данных
print_header "Анализ доступных баз данных"
DATABASES_INFO=$(curl -sS $CURL_OPTS "$PROTOCOL://$HOST:$PORT/?query=SHOW+DATABASES" 2>/dev/null)
if [ $? -ne 0 ]; then
    echo -e "${RED}Не удалось получить список баз данных. Проверьте подключение.${NC}"
    exit 1
fi

# Вывод списка баз данных
echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${GREEN}Список доступных баз данных:${NC}"
for DATABASE in $DATABASES_INFO; do
    echo -e "$(date '+%Y-%m-%d %H:%M:%S')   - $DATABASE"
done

# Выбор баз данных для бэкапа
contains_element() {
    local element="$1"
    shift
    for e in "$@"; do
        [[ "$e" == "$element" ]] && return 0
    done
    return 1
}

while true; do
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${BLUE}Введите названия баз данных для бэкапа через пробел:${NC}"
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${YELLOW}- или 'all' для бекапа всех пользовательских таблиц${NC}"
    read -r DB_SELECTION

    if [[ "$DB_SELECTION" == "all" ]]; then
        SELECTED_DATABASES=()
        for DATABASE in $DATABASES_INFO; do
            if [[ "$DATABASE" != "system" && "$DATABASE" != "default" ]]; then
                SELECTED_DATABASES+=("$DATABASE")
            fi
        done
        break
    else
        read -ra SELECTED_DATABASES <<< "$DB_SELECTION"
        INVALID_DATABASES=()
        for DATABASE in "${SELECTED_DATABASES[@]}"; do
            if ! contains_element "$DATABASE" $DATABASES_INFO; then
                INVALID_DATABASES+=("$DATABASE")
            fi
        done
        if [ ${#INVALID_DATABASES[@]} -ne 0 ]; then
            echo -e "${RED}Некорректные базы данных: ${INVALID_DATABASES[*]}. Пожалуйста, повторите выбор.${NC}"
        else
            break
        fi
    fi
done

# Функция для получения статистики по таблицам
get_table_stats() {
    local DATABASE=$1
    local TABLE=$2
    ROWS_COUNT=$(curl -sS $CURL_OPTS "$PROTOCOL://$HOST:$PORT/?database=$DATABASE&query=SELECT+COUNT(*)+FROM+$TABLE" 2>/dev/null)
    ROWS_COUNT=${ROWS_COUNT:-N/A}
    TABLE_SIZE_BYTES=$(curl -sS $CURL_OPTS "$PROTOCOL://$HOST:$PORT/?query=SELECT+sum(bytes)+FROM+system.parts+WHERE+database='$DATABASE'+AND+table='$TABLE'+AND+active=1" 2>/dev/null)
    TABLE_SIZE_MB=${TABLE_SIZE_BYTES:-N/A}
    if [[ "$TABLE_SIZE_MB" =~ ^[0-9]+$ ]]; then
        TABLE_SIZE_MB=$(echo "scale=2; $TABLE_SIZE_BYTES / (1024 * 1024)" | bc 2>/dev/null || echo "N/A")
    fi
    echo "$ROWS_COUNT|$TABLE_SIZE_MB"
}

# Парсинг таблиц для выбранных баз данных
declare -A DATABASE_TABLES
declare -A TABLE_STATS
for DATABASE in "${SELECTED_DATABASES[@]}"; do
    TABLES_INFO=$(curl -sS $CURL_OPTS "$PROTOCOL://$HOST:$PORT/?database=$DATABASE&query=SHOW+TABLES" 2>/dev/null)
    if [ $? -eq 0 ]; then
        DATABASE_TABLES["$DATABASE"]="$TABLES_INFO"
        for TABLE in $TABLES_INFO; do
            STATS=$(get_table_stats "$DATABASE" "$TABLE")
            TABLE_STATS["$DATABASE:$TABLE"]=$STATS
        done
    else
        echo -e "${RED}Не удалось получить список таблиц для базы '$DATABASE'. Пропускаем...${NC}"
    fi
done

# Вывод информации о таблицах в выбранных базах данных
echo -e "${GREEN}Список таблиц в выбранных базах данных:${NC}"
for DATABASE in "${!DATABASE_TABLES[@]}"; do
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${YELLOW}База данных: $DATABASE${NC}"
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') Таблицы:"
    for TABLE in ${DATABASE_TABLES["$DATABASE"]}; do
        STATS=${TABLE_STATS["$DATABASE:$TABLE"]}
        ROWS_COUNT=$(echo "$STATS" | cut -d'|' -f1)
        TABLE_SIZE_MB=$(echo "$STATS" | cut -d'|' -f2)
        echo -e "$(date '+%Y-%m-%d %H:%M:%S')   - $TABLE (строк: ${ROWS_COUNT:-N/A}, размер: ${TABLE_SIZE_MB:-N/A} MB)"
    done
done

# Выбор таблиц для каждой базы данных
declare -A SELECTED_TABLES
for DATABASE in "${SELECTED_DATABASES[@]}"; do
    while true; do
        echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${BLUE}Выберите таблицы для бэкапа в базе ${GREEN}'$DATABASE':${NC}"
        echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${YELLOW}- или 'all' для бекапа всех таблиц${NC}"
        echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${YELLOW}- или '-' для отказа от бекапа таблиц этой базы:${NC}"
        read -r TABLE_SELECTION

        if [[ "$TABLE_SELECTION" == "-" ]]; then
            echo -e "${YELLOW}Бэкап таблиц базы '$DATABASE' пропущен.${NC}"
            break
        elif [[ "$TABLE_SELECTION" == "all" ]]; then
            SELECTED_TABLES["$DATABASE"]="${DATABASE_TABLES[$DATABASE]}"
            break
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
                echo -e "${RED}Некорректные таблицы: ${INVALID_TABLES[*]}. Пожалуйста, повторите выбор.${NC}"
            else
                SELECTED_TABLES["$DATABASE"]="${SELECTED_TABLES_ARRAY[@]}"
                break
            fi
        fi
    done
done

# Запрос на архивацию бэкапов
while true; do
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${BLUE}Хотите архивировать бэкапы?${NC}"
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${YELLOW}- Введите 'yes' для создания архива${NC}"
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${YELLOW}- Введите 'no' для сохранения файлов без архивации:${NC}"
    read -r ARCHIVE_BACKUP
    if [[ "$ARCHIVE_BACKUP" == "yes" || "$ARCHIVE_BACKUP" == "no" ]]; then
        break
    else
        echo -e "${RED}Пожалуйста, введите 'yes' или 'no'.${NC}"
    fi
done

# Функция для бэкапа одной таблицы
backup_table() {
    DATABASE=$1
    TABLE=$2
    BACKUP_FILE="$TEMP_BACKUP_DIR/$DATABASE-$TABLE-$TIMESTAMP.sql"

    # Проверка корректности имён базы данных и таблицы
    if [[ ! "$DATABASE" =~ ^[a-zA-Z0-9_]+$ || ! "$TABLE" =~ ^[a-zA-Z0-9_]+$ ]]; then
        echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${RED}Ошибка: Некорректное имя базы данных или таблицы ('$DATABASE', '$TABLE').${NC}"
        return 1
    fi

    # Формирование URL с экранированием символов
    QUERY_URL="$PROTOCOL://$HOST:$PORT/?database=$DATABASE&query=SELECT+*+FROM+$TABLE+FORMAT+SQLInsert"

    echo -e "$(date '+%Y-%m-%d %H:%M:%S') Выполняется бэкап таблицы '$TABLE' из базы '$DATABASE'..."
    curl -sS $CURL_OPTS "$QUERY_URL" > "$BACKUP_FILE"
    if [ $? -ne 0 ]; then
        echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${RED}Ошибка при бэкапе таблицы '$TABLE' из базы '$DATABASE'.${NC}"
        return 1
    else
        echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${GREEN}Бэкап таблицы '$TABLE' из базы '$DATABASE' успешно завершен.${NC}"
        return 0
    fi
}

# Выполнение бэкапа последовательно
print_header "Выполняется бэкап выбранных таблиц..."
TIMESTAMP=$(date +"%Y%m%d%H%M%S")
TEMP_BACKUP_DIR=$(mktemp -d)
SUCCESSFUL_BACKUPS=0
FAILED_BACKUPS=()
BACKUP_FILES=() # Массив для хранения имён файлов бэкапа

for DATABASE in "${!SELECTED_TABLES[@]}"; do
    for TABLE in ${SELECTED_TABLES["$DATABASE"]}; do
        if backup_table "$DATABASE" "$TABLE"; then
            SUCCESSFUL_BACKUPS=$((SUCCESSFUL_BACKUPS + 1))
        else
            FAILED_BACKUPS+=("$DATABASE:$TABLE")
        fi
    done
done

# Архивация бэкапов
if [[ "$ARCHIVE_BACKUP" == "yes" ]]; then
    # Создаем архив непосредственно в указанной директории
    BACKUP_ARCHIVE="$BACKUP_DIR/backup-$TIMESTAMP.tar.gz"
    echo -e "${YELLOW}Архивация бэкапов в файл: $BACKUP_ARCHIVE${NC}"
    tar -czf "$BACKUP_ARCHIVE" -C "$TEMP_BACKUP_DIR" .
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Архив успешно создан: $BACKUP_ARCHIVE${NC}"
        BACKUP_FILES=("$BACKUP_ARCHIVE") # Сохраняем имя архива
    else
        echo -e "${RED}Ошибка при создании архива.${NC}"
        BACKUP_FILES=() # Оставляем пустым в случае ошибки
    fi
else
    # Перемещаем файлы бэкапа в указанную директорию
    echo -e "${YELLOW}Бэкапы оставлены в виде отдельных файлов в директории: $BACKUP_DIR${NC}"
    mv "$TEMP_BACKUP_DIR"/* "$BACKUP_DIR/"
    BACKUP_FILES=("$BACKUP_DIR"/*) # Собираем список файлов
fi

# Удаление временной директории
rm -rf "$TEMP_BACKUP_DIR"

# Конец отсчета времени выполнения
END_TIME=$(date +%s)
EXECUTION_TIME=$((END_TIME - START_TIME))

# Легенда
print_header "Отчёт о работе скрипта"

# Вычисление размера бэкапа
if [[ "$ARCHIVE_BACKUP" == "yes" ]]; then
    BACKUP_SIZE=$(du -sh "$BACKUP_ARCHIVE" 2>/dev/null | cut -f1)
else
    BACKUP_SIZE=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
fi

# Вычисление размера файла лога
LOG_FILE_SIZE=$(du -sh "$LOG_FILE" 2>/dev/null | cut -f1)

# Вывод результатов
echo -e "${GREEN}Результаты работы скрипта:${NC}"
echo -e "Успешно забэкапировано таблиц: ${SUCCESSFUL_BACKUPS}"
if [ ${#FAILED_BACKUPS[@]} -ne 0 ]; then
    echo -e "${RED}Ошибки при бэкапе таблиц: ${FAILED_BACKUPS[*]}${NC}"
fi
if [[ "$ARCHIVE_BACKUP" == "yes" ]]; then
    echo -e "Архив бэкапа: $BACKUP_ARCHIVE"
else
    echo -e "Бэкапы находятся в директории: $BACKUP_DIR"
fi
echo -e "Список файлов бэкапа:"
for FILE in "${BACKUP_FILES[@]}"; do
    echo -e "  - $(basename "$FILE")"
done
echo -e "Общий объём бэкапа: ${BACKUP_SIZE}"
echo -e "Размер файла лога: ${LOG_FILE_SIZE}"
echo -e "Файл логов: $(pwd)/${LOG_FILE}"
echo -e "Время выполнения скрипта: ${EXECUTION_TIME} секунд"

print_header "Завершение работы скрипта"