DROP TABLE IF EXISTS airly_observations;
DROP TABLE IF EXISTS airly_stations;

CREATE TABLE airly_stations (
    id INT PRIMARY KEY,
    lattitude NUMERIC(9, 6),
    longitude NUMERIC(9, 6)
);

CREATE TABLE airly_observations (
    id SERIAL PRIMARY KEY,
    utc_time TIMESTAMP,
    station_id INT NOT NULL REFERENCES airly_stations(id),
    temperature INT,
    humidity INT,
    pressure INT,
    pm1 INT,
    pm2_5 INT,
    pm10 INT
);