# Примеры использования ClickHouse в компаниях

## 1. Яндекс.Метрика [Source link](https://clickhouse.com/docs/ru/introduction/history)

Задача:  
Хранение и анализ данных о посещениях веб-сайтов, включая информацию о браузерах, устройствах, географии и поведении пользователей.

Использование ClickHouse:  
ClickHouse используется для хранения и обработки огромных объемов данных (петабайты) в режиме реального времени. Благодаря высокой производительности ClickHouse, Яндекс.Метрика может предоставлять пользователям быстрые и точные отчеты, а также строить сложные сегменты аудитории.

## 2. Cloudflare [Source link](https://blog.cloudflare.com/http-analytics-for-6m-requests-per-second-using-clickhouse/)
Задача:  
Анализ трафика и мониторинг безопасности на глобальной сети серверов.

Использование ClickHouse:  
Cloudflare использует ClickHouse для хранения и анализа данных о миллионах запросов в секунду, поступающих на их сеть. ClickHouse позволяет Cloudflare быстро обнаруживать и блокировать вредоносные запросы, а также получать ценные аналитические данные о трафике.

## 3. Сбербанк [Source link](https://platformv.sbertech.ru/products/analitika-dannyh/sdp-analytics)
Задача:  
Аналитика финансовых операций и клиентского поведения.

Использование ClickHouse:  
Сбербанк использует ClickHouse для хранения и анализа данных о миллионах транзакций, совершаемых ежедневно. ClickHouse помогает Сбербанку выявлять мошеннические операции, анализировать потребности клиентов и разрабатывать новые финансовые продукты.

## Общие преимущества ClickHouse для этих компаний

* Высокая производительность:  ClickHouse позволяет обрабатывать огромные объемы данных в режиме реального времени.
* Масштабируемость:  ClickHouse легко масштабируется горизонтально, что позволяет обрабатывать еще большие объемы данных.
* Гибкость:  ClickHouse поддерживает множество типов данных и запросов, что делает его универсальным инструментом для анализа данных.
* Экономичность:  ClickHouse использует ресурсы сервера эффективно, что делает его экономически выгодным решением для хранения и анализа больших данных.

Важно отметить:  Приведенные примеры демонстрируют лишь некоторые из возможностей ClickHouse. В зависимости от конкретных задач, компании могут использовать ClickHouse по-разному.

---

## Дополнительные вопросы и ответы

### К каким классам систем относится ClickHouse?

ClickHouse относится к классу колоночных систем управления базами данных (СУБД), специализированных для аналитических запросов. Он оптимизирован для выполнения сложных запросов на больших объемах данных с высокой скоростью.

### Какую проблему вы бы решили используя ClickHouse, а какую бы не стали?

Проблемы, которые можно решить с помощью ClickHouse:

* Аналитика больших данных:  ClickHouse идеально подходит для хранения и анализа больших объемов структурированных данных, таких как логи, события, транзакции и т.д.
* Реальное время аналитики:  ClickHouse позволяет выполнять запросы в режиме реального времени, что полезно для мониторинга, отчетности и принятия решений на основе данных.
* Сложные запросы:  ClickHouse поддерживает широкий спектр операций и функций, что позволяет выполнять сложные аналитические запросы.

Проблемы, которые не стоит решать с помощью ClickHouse:

* OLTP (оперативная обработка транзакций):  ClickHouse не предназначен для выполнения большого количества небольших транзакций, таких как вставка, обновление и удаление данных.
* Неструктурированные данные:  ClickHouse лучше всего работает со структурированными данными, такими как числа, строки и даты. Он не предназначен для работы с неструктурированными данными, такими как текст, изображения и видео.
* Высокая конкурентность:  ClickHouse не оптимизирован для работы в условиях высокой конкурентности, когда множество пользователей одновременно выполняют запросы.

### Где можно получить помощь по ClickHouse и куда сообщать о багах?

Получение помощи:
* Официальная документация:  [ClickHouse Documentation](https://clickhouse.com/docs/en/)
* Форум:  [ClickHouse Forum](https://forum.clickhouse.com/)
* GitHub Issues:  [ClickHouse GitHub Issues](https://github.com/ClickHouse/ClickHouse/issues)
* Telegram чат:  [ClickHouse Russian Community](https://t.me/clickhouse_ru)

Сообщение о багах:

* GitHub Issues:  [ClickHouse GitHub Issues](https://github.com/ClickHouse/ClickHouse/issues) - лучшее место для сообщения о багах. Убедитесь, что вы предоставили подробное описание проблемы, шаги для воспроизведения и любые соответствующие логи.

Важно:  Перед сообщением о баге убедитесь, что проблема не была уже зарегистрирована. Вы можете использовать поиск по GitHub Issues, чтобы проверить это.
