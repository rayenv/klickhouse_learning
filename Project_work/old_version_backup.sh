#!/bin/bash

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

# Логирование
LOG_FILE="backup_clickhouse.log"
log_message() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
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
if [[ "$USE_INSECURE_SSL" == "yes" ]]; then
    PROTOCOL="https"
    CURL_OPTS="--user $USER:$PASSWORD --insecure" # Игнорировать проверку SSL-сертификата
else
    PROTOCOL="http"
    CURL_OPTS="--user $USER:$PASSWORD" # Без SSL/TLS
fi

# Получение списка баз данных
print_header "Анализ доступных баз данных"

DATABASES_INFO=$(curl -sS $CURL_OPTS "$PROTOCOL://$HOST:$PORT/?query=SHOW+DATABASES")
if [ $? -ne 0 ]; then
    log_message "${RED}Не удалось получить список баз данных. Проверьте подключение. ${NC}"
    exit 1
fi

# Парсинг баз данных
declare -A DATABASE_TABLES
for DATABASE in $DATABASES_INFO; do
    TABLES_INFO=$(curl -sS $CURL_OPTS "$PROTOCOL://$HOST:$PORT/?database=$DATABASE&query=SHOW+TABLES")
    if [ $? -eq 0 ]; then
        DATABASE_TABLES["$DATABASE"]="$TABLES_INFO"
    fi
done

# Вывод информации о базах данных и таблицах
log_message 
echo -e al"${GREEN} Список доступных баз данных и таблиц: ${NC}"
for DATABASE in "${!DATABASE_TABLES[@]}"; do
    echo -e "${YELLOW}База данных: $DATABASE ${NC}"
    echo -e "Таблицы:"
    for TABLE in ${DATABASE_TABLES["$DATABASE"]}; do
        echo -e "  - $TABLE"
    done
done


# Выбор баз данных для бэкапа
while true; do
    echo -e "${YELLOW}Введите названия баз данных для бэкапа через пробел: ${NC}"
    echo -e "${YELLOW}- или 'all' для бекапа всех баз ${NC}"
    read -r DB_SELECTION

    # Если выбрано 'all', выбираем все пользовательские базы данных
    if [[ "$DB_SELECTION" == "all" ]]; then
        SELECTED_DATABASES=()
        for DATABASE in "${!DATABASE_TABLES[@]}"; do
            if [[ "$DATABASE" != "system" && "$DATABASE" != "default" ]]; then
                SELECTED_DATABASES+=("$DATABASE")
            fi
        done
        break
    # TBD - доработать обработку связки всё+системные таблицы
    # # Если выбрано 'all+system', выбираем все базы данных, включая системные
    # elif [[ "$DB_SELECTION" == "all+system" ]]; then
    #     SELECTED_DATABASES=("${!DATABASE_TABLES[@]}")
    #     break
    else
        # Разбиваем ввод на массив
        read -ra SELECTED_DATABASES <<< "$DB_SELECTION"

        # Проверяем корректность выбранных баз данных
        INVALID_DATABASES=()
        for DATABASE in "${SELECTED_DATABASES[@]}"; do
            if [[ -z "${DATABASE_TABLES[$DATABASE]}" ]]; then
                INVALID_DATABASES+=("$DATABASE")
            fi
        done

        if [ ${#INVALID_DATABASES[@]} -ne 0 ]; then
            log_message "${RED}Некорректные базы данных: ${INVALID_DATABASES[*]}. Пожалуйста, повторите выбор. ${NC}"
        else
            break
        fi
    fi
done

# Выбор таблиц для каждой базы данных
declare -A SELECTED_TABLES
for DATABASE in "${SELECTED_DATABASES[@]}"; do
    echo -e "${YELLOW}Выберите таблицы для бэкапа в базе '$DATABASE': ${NC}"
    echo -e "${YELLOW}- или 'all' для бекапа всех таблиц ${NC}"
    echo -e "${YELLOW}- или '-' для отказа от бекапа таблиц этой базы: ${NC}"
    read -r TABLE_SELECTION

    if [[ "$TABLE_SELECTION" == "-" ]]; then
        log_message  "${YELLOW}Бэкап таблиц базы '$DATABASE' пропущен. ${NC}"
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
            log_message "${RED}Некорректные таблицы: ${INVALID_TABLES[*]}. Пожалуйста, повторите выбор. ${NC}"
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
        log_message "${RED}Пожалуйста, введите 'yes' или 'no'. ${NC}"
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
        log_message "${RED}Пожалуйста, введите 'yes' или 'no'. ${NC}"
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
    curl -sS $CURL_OPTS "$PROTOCOL://$HOST:$PORT/?database=$DATABASE&query=SELECT+*+FROM+$TABLE+FORMAT+SQLInsert" > "$BACKUP_FILE"
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
    log_message "${YELLOW}Архивация бэкапов в файл: $BACKUP_ARCHIVE ${NC}"
    tar -czf "$BACKUP_ARCHIVE" -C "$TEMP_BACKUP_DIR" .
    if [ $? -eq 0 ]; then
        log_message "${GREEN}Архив успешно создан: $BACKUP_ARCHIVE ${NC}"
    else
        log_message "${RED}Ошибка при создании архива. ${NC}"
    fi
    # Удаление временной директории
    rm -rf "$TEMP_BACKUP_DIR"
else
    log_message "${YELLOW}Бэкапы оставлены в виде отдельных файлов в директории: $TEMP_BACKUP_DIR ${NC}"
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
    echo -e "Бэкапы находятся в директории: ${BACKUP_DIR} "
fi
echo -e "Файл логов: $(pwd)/${LOG_FILE} "
echo -e "Время выполнения скрипта: ${EXECUTION_TIME} секунд "

print_header "Завершение работы скрипта"