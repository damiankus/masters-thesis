DROP TABLE observations;
DROP TABLE stations;

CREATE TABLE stations (
	id CHAR(20) PRIMARY KEY,
        address CHAR(100),
        city CHAR(20),
        latitude NUMERIC(9, 6),
        longitude NUMERIC(9, 6),
        manufacturer CHAR(20),
        source CHAR(10),
        uuid CHAR(20)
);

-- =====================================

select * from airly_stations;
select * from airy_stations;
select * from looko2_stations;

-- =====================================

INSERT INTO stations(
	source, id, city,
	latitude, longitude,
	manufacturer, uuid)
SELECT	'airly', 'airly_' || id::text, 'Kraków',
	lattitude, longitude,
	'airly', 'Airly_' || id
FROM airly_stations;

INSERT INTO stations(
	source, id, address, city,
	latitude, longitude,
	manufacturer, uuid)
SELECT	'airy', 'airy_' || id::text, location_address, location_city,
	location_latitude, location_longitude,
	manufacturer, uuid
FROM airy_stations;

INSERT INTO stations(
	source, id, city,
	manufacturer, uuid)
SELECT DISTINCT 'looko2', 'looko2_' || id::text, 'Kraków',
	'looko2', 'Looko2_' || id::text
FROM looko2_stations;

CREATE INDEX ON stations USING HASH (id);

-- ===================================
--
-- ===================================

CREATE TABLE observations (
	id SERIAL PRIMARY KEY,
	station_id CHAR(20) REFERENCES stations(id),
	timestamp TIMESTAMP,
	temperature NUMERIC(22, 15),
	pressure NUMERIC(22, 15),	
	humidity NUMERIC(22, 15),
	pm1 NUMERIC(22, 15),
	pm2_5 NUMERIC(22, 15),
	pm10 NUMERIC(22, 15),
	co NUMERIC(22, 15),
	no2 NUMERIC(22, 15), 
	o3 NUMERIC(22, 15), 
	so2 NUMERIC(22, 15), 
	c6h6 NUMERIC(22, 15)
);

-- =====================================


SELECT * FROM airly_observations ORDER BY temperature ASC LIMIT 1;
SELECT pressure FROM airy_observations WHERE pressure > 0 LIMIT 100;
SELECT * FROM looko2_observations LIMIT 1;

-- =====================================

INSERT INTO observations (
	station_id, timestamp,
	temperature, pressure, humidity,
	pm1, pm2_5, pm10
)
SELECT 'airly_' || station_id, utc_time, temperature, (pressure / 100.0), humidity,
	pm1, pm2_5, pm10
FROM airly_observations
ORDER BY utc_time;

INSERT INTO observations (
	station_id, timestamp,
	temperature, pressure, humidity,
	pm1, pm2_5, pm10, co, no2, o3, so2, c6h6
)
SELECT 'airy_' || station_id, to_timestamp(measurementmillis / 1000), temperature, (pressure / 100.0), humidity,
	pm1, pm2_5, pm10, co, no2, o3, so2, c6h6
FROM airy_observations
ORDER BY measurementmillis;

INSERT INTO observations (
	station_id, timestamp,
	pm1, pm2_5, pm10
)
SELECT 'looko2_' || station_id, format('%s %s:00', date, hour)::timestamp,
	pm1, pm2_5, pm10
FROM looko2_observations
ORDER BY station_id, date, hour;

select * from pg_indexes where tablename = 'observations';
CREATE INDEX ON observations(timestamp);
CREATE INDEX ON observations(station_id);
CLUSTER observations USING "observations_timestamp_idx";


-- ===================================
--
-- ===================================

SELECT * FROM observations AS o
JOIN stations AS s ON s.id = o.station_id
WHERE s.uuid = 'Airly_3'
AND timestamp::date = '2017-03-01'
AND timestamp > '2017-03-01 17:00:00';

