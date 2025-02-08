CREATE DATABASE IF NOT EXISTS test_db;

USE test_db;

CREATE TABLE IF NOT EXISTS guitars (
    id UInt32,
    name String,
    strings UInt8
) ENGINE = MergeTree()
ORDER BY id;

INSERT INTO guitars (id, name, strings) VALUES
(1, 'Jackson', 6),
(2, 'Schecter', 7),
(3, 'Caparison', 365);