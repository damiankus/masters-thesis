DROP TABLE observations;
DROP TABLE stations;

CREATE TABLE stations (
    id INT PRIMARY KEY,
    lattitude NUMERIC(9, 6),
    longitude NUMERIC(9, 6)
);

CREATE TABLE observations (
    id SERIAL PRIMARY KEY,
    utc_time TIMESTAMP,
    station_id INT NOT NULL REFERENCES stations(id),
    temperature INT,
    humidity INT,
    pressure INT,
    pm1 INT,
    pm2_5 INT,
    pm10 INT
);