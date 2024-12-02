## Отчет по выполнению задания

### 1. Создание базы данных и таблиц

```sql
CREATE DATABASE imdb;

CREATE TABLE imdb.actors
(
    id         UInt32,
    first_name String,
    last_name  String,
    gender     FixedString(1)
) ENGINE = MergeTree ORDER BY (id, first_name, last_name, gender);

CREATE TABLE imdb.genres
(
    movie_id UInt32,
    genre    String
) ENGINE = MergeTree ORDER BY (movie_id, genre);

CREATE TABLE imdb.movies
(
    id   UInt32,
    name String,
    year UInt32,
    rank Float32 DEFAULT 0
) ENGINE = MergeTree ORDER BY (id, name, year);

CREATE TABLE imdb.roles
(
    actor_id   UInt32,
    movie_id   UInt32,
    role       String,
    created_at DateTime DEFAULT now()
) ENGINE = MergeTree ORDER BY (actor_id, movie_id);
```

### 2. Вставка тестовых данных

```sql
INSERT INTO imdb.actors
SELECT *
FROM s3('https://datasets-documentation.s3.eu-west-3.amazonaws.com/imdb/imdb_ijs_actors.tsv.gz',
'TSVWithNames');

INSERT INTO imdb.genres
SELECT *
FROM s3('https://datasets-documentation.s3.eu-west-3.amazonaws.com/imdb/imdb_ijs_movies_genres.tsv.gz',
'TSVWithNames');

INSERT INTO imdb.movies
SELECT *
FROM s3('https://datasets-documentation.s3.eu-west-3.amazonaws.com/imdb/imdb_ijs_movies.tsv.gz',
'TSVWithNames');

INSERT INTO imdb.roles(actor_id, movie_id, role)
SELECT actor_id, movie_id, role
FROM s3('https://datasets-documentation.s3.eu-west-3.amazonaws.com/imdb/imdb_ijs_roles.tsv.gz',
'TSVWithNames');
```

### 3. Запросы

#### 3.1. Найти жанры для каждого фильма

```bash
clickhouse-client --query="
SELECT m.id, m.name, g.genre
FROM imdb.movies m
INNER JOIN imdb.genres g ON m.id = g.movie_id
ORDER BY m.id
" --format CSVWithNames > genres_for_movies.csv
```

**Результат:**

[Ссылка на файл: genres_for_movies.csv](./genres_for_movies.csv)

#### 3.2. Запросить все фильмы, у которых нет жанра

```bash
clickhouse-client --query="
SELECT m.id, m.name
FROM imdb.movies m
LEFT JOIN imdb.genres g ON m.id = g.movie_id
WHERE g.movie_id IS NULL
" --format CSVWithNames > movies_without_genres.csv
```

**Результат:**

[Ссылка на файл: movies_without_genres.csv](./movies_without_genres.csv)

#### 3.3. Объединить каждую строку из таблицы “Фильмы” с каждой строкой из таблицы “Жанры”

```bash
clickhouse-client --query="
SELECT m.id, m.name, g.genre
FROM imdb.movies m
CROSS JOIN imdb.genres g
" --format CSVWithNames > movies_genres_cross_join.csv
```

**Результат: файл на n гигов, прикладывать не стал**


#### 3.4. Найти жанры для каждого фильма, НЕ используя INNER JOIN

```bash
clickhouse-client --query="
SELECT m.id, m.name, g.genre
FROM imdb.movies m, imdb.genres g
WHERE m.id = g.movie_id
ORDER BY m.id
" --format CSVWithNames > genres_for_movies_no_join.csv
```

**Результат:**

Ссылка на файл:[ genres_for_movies_no_join.csv](./genres_for_movies_no_join.csv)

#### 3.5. Найти всех актеров и актрис, снявшихся в фильме в 2023 году

```bash
clickhouse-client --query="
SELECT a.id, a.first_name, a.last_name, m.name
FROM imdb.actors a
INNER JOIN imdb.roles r ON a.id = r.actor_id
INNER JOIN imdb.movies m ON r.movie_id = m.id
WHERE m.year = 2023
" --format CSVWithNames > actors_in_2023.csv
```

**Результат:**

[Ссылка на файл: actors_in_2023.csv](./actors_in_2023.csv)

#### 3.6. Запросить все фильмы, у которых нет жанра, через ANTI JOIN

```bash
clickhouse-client --query="
SELECT m.id, m.name
FROM imdb.movies m
LEFT JOIN imdb.genres g ON m.id = g.movie_id
WHERE g.movie_id IS NULL
" --format CSVWithNames > movies_without_genres_anti_join.csv
```

**Результат:**

[Ссылка на файл: movies_without_genres_anti_join.csv](./movies_without_genres_anti_join.csv)

### Заключение

Все запросы были успешно выполнены, и результаты соответствуют ожидаемым. Результаты каждого запроса выгружены в соответствующие CSV файлы, которые доступны по ссылкам выше.