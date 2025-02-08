CREATE DATABASE IF NOT EXISTS example_db2;

USE example_db2;

CREATE TABLE IF NOT EXISTS cars (
    id UInt32,
    name String,
    horse UInt8
) ENGINE = MergeTree()
ORDER BY id;

INSERT INTO cars (id, name, horse) VALUES
(1, 'VW', 180),
(2, 'FORD', 121),
(3, 'Dodge', 555);