CREATE DATABASE IF NOT EXISTS example_db3;

USE example_db3;

CREATE TABLE IF NOT EXISTS dogs (
    id UInt32,
    name String,
    type String
) ENGINE = MergeTree()
ORDER BY id;

INSERT INTO dogs (id, name, type) VALUES
(1, 'GavGav1', 'Rottie'),
(2, 'GavGav2', 'Shepard'),
(3, 'GavGav3', 'Bully');