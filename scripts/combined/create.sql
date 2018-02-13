﻿DROP TABLE IF EXISTS observations;
DROP TABLE IF EXISTS stations;

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
select * from monitoring_agh_stations;
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

-- Be careful to skip the duplicates (Airly sensors)
-- TODO: there are Airly stations in the AGH db that have no equivalents
-- in the Airly db
-- Include them (in which db?) or ignore them?
INSERT INTO stations(
	source, id, address, city,
	latitude, longitude,
	manufacturer, uuid)
SELECT	'agh', 'agh_' || id::text, location_address, location_city,
	location_latitude, location_longitude,
	manufacturer, uuid
FROM monitoring_agh_stations
WHERE manufacturer <> 'Airly'
ORDER BY id;

INSERT INTO stations(
	source, id, address, city,
	manufacturer, uuid)
SELECT 'looko2', 'looko2_' || id::text, station_name, 'Kraków',
	'looko2', 'Looko2_' || id::text
FROM looko2_stations AS s
WHERE s.station_name IN
(
SELECT MIN(station_name) FROM looko2_stations
GROUP BY id
)
ORDER BY s.id;

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
SELECT pressure FROM monitoring_agh_observations WHERE pressure > 0 LIMIT 100;
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

-- Note that timestamps are cast to ts in the UTC timezone
INSERT INTO observations (
	station_id, timestamp,
	temperature, pressure, humidity,
	pm1, pm2_5, pm10, co, no2, o3, so2, c6h6
)
SELECT 'agh_' || station_id, to_timestamp(measurementmillis / 1000) AT time zone 'UTC', temperature, (pressure / 100.0), humidity,
	pm1, pm2_5, pm10, co, no2, o3, so2, c6h6
FROM monitoring_agh_observations AS o
JOIN monitoring_agh_stations AS s
ON o.station_id = s.id
WHERE s.manufacturer <> 'Airly'
ORDER BY measurementmillis;

INSERT INTO observations (
	station_id, timestamp,
	pm1, pm2_5, pm10
)
SELECT 'looko2_' || station_id, format('%s %s:00', date, hour)::timestamp,
	pm1, pm2_5, pm10
FROM looko2_observations
ORDER BY date, hour, station_id;

SELECT * FROM pg_indexes WHERE tablename = 'observations';
CREATE INDEX ON observations(timestamp);
CREATE INDEX ON observations(station_id);
CLUSTER observations USING "observations_timestamp_idx";

-- ======================================================================
-- METEO OBSERVATIONS
-- ======================================================================

DROP TABLE IF EXISTS meteo_observations;
DROP TABLE IF EXISTS meteo_stations;

CREATE TABLE meteo_stations (
	id CHAR(20) PRIMARY KEY,
        address CHAR(100),
        city CHAR(20),
        latitude NUMERIC(9, 6),
        longitude NUMERIC(9, 6),
        source CHAR(20)
);

/*
Be careful while specifying the latitude and longitude
According to: http://meteo.ftj.agh.edu.pl/meteo/
the AGH meteo station is located at 50° 04' N 19° 57' E.
That's approximately: 50.066667 °N, 19.95 °E

A tool for casting degrees and minutes to a float number
https://stevemorse.org/nearest/distance.php
*/

INSERT INTO meteo_stations (id, address, city, latitude, longitude, source)
VALUES('agh_meteo', 'Akademia Górniczo-Hutnicza Wydział Fizyki i Informatyki Stosowanej ul. Reymonta 19, budynek D-10',
'Kraków', 50.066667, 19.95, 'agh');

INSERT INTO meteo_stations (id, address, city, latitude, longitude, source)
SELECT id, neighborhood, city, lat, lon, 'wunderground' 
FROM wunderground_stations 
ORDER BY id;

DROP TABLE IF EXISTS meteo_observations;
CREATE TABLE meteo_observations (
	ID SERIAL PRIMARY KEY,
	station_id CHAR(20) REFERENCES meteo_stations(id),
	timestamp TIMESTAMP,
	temperature NUMERIC(6, 3),
	humidity NUMERIC(6, 3), 
	pressure NUMERIC(7, 3), 
	wind_speed NUMERIC(7, 3),
	wind_dir_deg NUMERIC(6, 3),
	precip_total NUMERIC(7, 3),
	precip_rate NUMERIC(7, 3),
	solradiation NUMERIC(8, 3)
);

/*
AGH meteo records 
dm_hour_avg	wind direction
pa_hour_avg	pressure
rc_hour_avg	precipitation
ri_hour_avg	precipitation (intensity)
sm_hour_avg	wind speed (average)
ta_hour_avg	temperature
ua_hour_avg	humidity

The TIME column is already a UTC timestamp
*/

INSERT INTO meteo_observations(station_id, timestamp, temperature,
	 humidity, pressure, wind_speed, wind_dir_deg, 
	 precip_total, precip_rate)
SELECT 'agh_meteo', time, ta_hour_avg, ua_hour_avg, pa_hour_avg,
	sm_hour_avg, dm_hour_avg, rc_hour_avg,
	ri_hour_avg
FROM meteo_agh_observations
ORDER BY time;

-- Wunderground records
INSERT INTO meteo_observations(station_id, timestamp, temperature,
	 humidity, pressure, wind_speed, wind_dir_deg, 
	 precip_total, precip_rate, solradiation)
SELECT station_id, date_trunc('hour', timestamp),
	AVG(temperature), AVG(humidity), AVG(pressure), AVG(wind_speed),
	AVG(wind_dir_deg), AVG(precip_total), AVG(precip_rate), AVG(solradiation)
FROM wunderground_observations 
GROUP BY 1, 2
ORDER BY 1, 2;

/*
It is assumed that the hourly mean values
are calculated for a period before the time stored in
the record e.g. mean values for 12:00 are calculated based on
measurements for 11:05, 11:30, 11:55
Thus we need to add one hour (UPDATE query)
*/
UPDATE meteo_observations AS mo
SET timestamp = timestamp + INTERVAL '1 hour'
WHERE mo.station_id IN 
(
SELECT id
FROM meteo_stations
WHERE source = 'wunderground'
);

/*
Copy meteo data from observations in order to make
filling missing values easier
*/

INSERT INTO meteo_stations (id, address, city, latitude, longitude, source)
SELECT DISTINCT s.id, s.address, s.city, s.latitude, s.longitude, s.source
FROM observations AS o
JOIN stations AS s ON s.id = o.station_id
WHERE temperature IS NOT NULL 
OR pressure IS NOT NULL
OR humidity IS NOT NULL
ORDER BY s.id;

INSERT INTO meteo_observations(station_id, timestamp, temperature,
	 humidity, pressure)
SELECT o.station_id, o.timestamp, o.temperature,
	o.humidity, o.pressure
FROM observations AS o
WHERE temperature IS NOT NULL 
OR pressure IS NOT NULL
OR humidity IS NOT NULL
ORDER BY station_id, timestamp;

/*
Each day at 10 p.m. the AGH station 
saves an empty record (probably because of
the maintanance) which should be removed.
*/

DELETE FROM meteo_observations 
WHERE temperature IS NULL
AND humidity IS NULL
AND pressure IS NULL
AND wind_speed IS NULL
AND wind_dir_deg IS NULL
AND precip_total IS NULL
AND precip_rate IS NULL
AND solradiation IS NULL;

SELECT * FROM pg_indexes WHERE tablename = 'meteo_observations';
CREATE INDEX ON meteo_observations(timestamp);
CREATE INDEX ON meteo_observations(station_id);
CLUSTER meteo_observations USING "meteo_observations_timestamp_idx";

/*
A table storing complete records
*/

DROP TABLE IF EXISTS complete_data;
CREATE TABLE complete_data (
	id SERIAL PRIMARY KEY,
	station_id CHAR(20) REFERENCES stations(id),
	timestamp TIMESTAMP,
	pm1 NUMERIC(22, 15),
	pm2_5 NUMERIC(22, 15),
	pm10 NUMERIC(22, 15),
/*
	co NUMERIC(22, 15),
	no2 NUMERIC(22, 15), 
	o3 NUMERIC(22, 15), 
	so2 NUMERIC(22, 15), 
	c6h6 NUMERIC(22, 15),
*/
	wind_speed NUMERIC(7, 3),
	wind_dir_deg NUMERIC(6, 3),
	precip_total NUMERIC(7, 3),
	precip_rate NUMERIC(7, 3),
	solradiation NUMERIC(8, 3),
	temperature NUMERIC(6, 3),
	humidity NUMERIC(6, 3), 
	pressure NUMERIC(7, 3)
);

INSERT INTO complete_data(station_id, timestamp, pm1, pm2_5, pm10,
	-- co, no2, o3, so2, c6h6,
	temperature, humidity, pressure)
SELECT station_id, timestamp, pm1, pm2_5, pm10,
	-- co, no2, o3, so2, c6h6,
	 temperature, humidity, pressure
FROM observations
ORDER BY station_id, timestamp;

-- ===================================
--
-- ===================================

ALTER TABLE complete_data DROP COLUMN is_holiday;
ALTER TABLE complete_data ADD COLUMN is_holiday INT DEFAULT 0;

UPDATE complete_data 
SET is_holiday = 1
WHERE EXTRACT(DOW FROM timestamp) = 0 
OR EXTRACT(DOW FROM timestamp) = 6	
OR (EXTRACT(MONTH FROM timestamp) = 1 AND EXTRACT(DAY FROM timestamp) = 1)
OR (EXTRACT(MONTH FROM timestamp) = 1 AND EXTRACT(DAY FROM timestamp) = 6)
OR (EXTRACT(MONTH FROM timestamp) = 5 AND EXTRACT(DAY FROM timestamp) = 1)
OR (EXTRACT(MONTH FROM timestamp) = 5 AND EXTRACT(DAY FROM timestamp) = 3)
OR (EXTRACT(MONTH FROM timestamp) = 8 AND EXTRACT(DAY FROM timestamp) = 15)
OR (EXTRACT(MONTH FROM timestamp) = 11 AND EXTRACT(DAY FROM timestamp) = 1)
OR (EXTRACT(MONTH FROM timestamp) = 11 AND EXTRACT(DAY FROM timestamp) = 11)
OR (EXTRACT(MONTH FROM timestamp) = 12 AND EXTRACT(DAY FROM timestamp) = 25)
OR (EXTRACT(MONTH FROM timestamp) = 12 AND EXTRACT(DAY FROM timestamp) = 26);

-- ===================================
--
-- ===================================

ALTER TABLE complete_data DROP COLUMN period_of_day;
ALTER TABLE complete_data ADD COLUMN period_of_day INT;

UPDATE complete_data 
SET period_of_day = 0
WHERE EXTRACT(HOUR FROM timestamp) BETWEEN 0 AND 5;
UPDATE complete_data 
SET period_of_day = 1
WHERE EXTRACT(HOUR FROM timestamp) BETWEEN 6 AND 11;
UPDATE complete_data 
SET period_of_day = 2
WHERE EXTRACT(HOUR FROM timestamp) BETWEEN 12 AND 17;
UPDATE complete_data
SET period_of_day = 3
WHERE EXTRACT(HOUR FROM timestamp) BETWEEN 18 AND 23;

-- ===================================
--
-- ===================================

ALTER TABLE complete_data DROP COLUMN is_heating_season;
ALTER TABLE complete_data ADD COLUMN is_heating_season BOOLEAN DEFAULT FALSE;
UPDATE complete_data 
SET is_heating_season = TRUE
WHERE EXTRACT(MONTH FROM timestamp) BETWEEN 1 AND 3
OR EXTRACT(MONTH FROM timestamp) BETWEEN 9 AND 12;

-- ===================================
--
-- ===================================

ALTER TABLE complete_data DROP COLUMN day_of_week;
ALTER TABLE complete_data ADD COLUMN day_of_week INT;
UPDATE complete_data 
SET day_of_week = EXTRACT(DOW FROM timestamp);

-- ===================================
--
-- ===================================

/*
Find the distances between stations 
in order to specify the order of seeking
for a value to fill the missing column 
in the original record

The distance column contains an approximated
distance between stations (in kilometers)
found by applting the formula of the
Spherical Law of Cosines:

distance = ACOS( SIN(lat1)*SIN(lat2) + COS(lat1)*COS(lat2)*COS(lon2-lon1) ) * 6371000
Value 6371000 is the Earth's radius in meters.
The formula assumes that the lat and lon values are expressed in RADIANS!

For reference see: https://www.movable-type.co.uk/scripts/latlong.html
*/

DROP TABLE IF EXISTS meteo_distance;
CREATE TABLE meteo_distance AS (
SELECT s1.id AS id1, s2.id AS id2, 
	(ACOS(
		SIN(radians(s1.latitude)) * SIN(radians(s2.latitude)) 
		+ COS(radians(s1.latitude)) * COS(radians(s2.latitude)) 
		* COS(radians(s1.longitude) - radians(s2.longitude))
	) * 6371000) AS dist,
	s1.latitude AS latitude1, s1.longitude AS longitude1,
	s2.latitude AS latitude2, s2.longitude AS longitude2
FROM stations AS s1
CROSS JOIN meteo_stations AS s2
WHERE s1.id <> s2.id
ORDER BY 1, 3, 2
);

SELECT * FROM pg_indexes WHERE tablename = 'meteo_distance';
CREATE INDEX ON meteo_distance(id1);
CREATE INDEX ON meteo_distance(id2);
CLUSTER meteo_distance USING "meteo_distance_id1_idx";

/*
Similarly, calculate the distance between
the stations measuring air quality.
*/

DROP TABLE IF EXISTS air_quality_distance;
CREATE TABLE air_quality_distance AS (
SELECT s1.id AS id1, s2.id AS id2, 
	(ACOS(
		SIN(radians(s1.latitude)) * SIN(radians(s2.latitude)) 
		+ COS(radians(s1.latitude)) * COS(radians(s2.latitude)) 
		* COS(radians(s1.longitude) - radians(s2.longitude))
	) * 6371000) AS dist,
	s1.latitude AS latitude1, s1.longitude AS longitude1,
	s2.latitude AS latitude2, s2.longitude AS longitude2
FROM stations AS s1
CROSS JOIN stations AS s2
WHERE s1.id <> s2.id
ORDER BY 1, 3, 2
);

SELECT * FROM pg_indexes WHERE tablename = 'air_quality_distance';
CREATE INDEX ON air_quality_distance(id1);
CREATE INDEX ON air_quality_distance(id2);
CLUSTER air_quality_distance USING "air_quality_distance_id1_idx";

/*
A function filling missing values by 
copying them from the nearest meteo station
containing the desired value
*/

/*
Backup SELECT query

SELECT o.*, m.station_id, m.%s
FROM observations AS o
JOIN %s AS d
ON d.id1 = o.station_id
AND d.id2 = (
	SELECT station_id
	FROM %s AS obs
	JOIN %s AS dist
	ON dist.id1 = o.station_id
	AND dist.id2 = obs.station_id
	WHERE obs.%s IS NOT NULL
	LIMIT 1
)
JOIN (SELECT station_id, timestamp, %s FROM %s) AS m
ON m.station_id = d.id2
AND m.timestamp = o.timestamp
WHERE o.%s IS NULL		
*/

CREATE OR REPLACE FUNCTION fill_missing()
RETURNS VOID AS $$
DECLARE
	meteo_cols text[];
	air_quality_cols text[];
	col text;
	query text;
BEGIN
	query := '
		UPDATE complete_data AS cd
		SET %s = (
			SELECT obs.%s
			FROM %s AS obs
			JOIN %s AS dist
			ON dist.id1 = cd.station_id
			AND dist.id2 = obs.station_id
			WHERE obs.timestamp = cd.timestamp
			AND obs.%s IS NOT NULL
			LIMIT 1
	) WHERE %s IS NOT NULL';
		
        air_quality_cols := ARRAY['pm1', 'pm2_5', 'pm10'];
	FOREACH col IN ARRAY air_quality_cols
	LOOP	
		RAISE NOTICE 'Filling missing % values', col;
		EXECUTE format(query, col, col, 'observations', 
		 'air_quality_distance', col, col);
	END LOOP;
	
        meteo_cols := ARRAY['wind_speed', 'wind_dir_deg', 'precip_total',
		'precip_rate', 'solradiation', 'temperature', 'humidity', 'pressure'];
	FOREACH col IN ARRAY meteo_cols
	LOOP
		RAISE NOTICE 'Filling missing % values', col;
		EXECUTE format(query, col, col, 'meteo_observations',
		 'meteo_distance', col, col);
	END LOOP;
END;
$$  LANGUAGE plpgsql;

select fill_missing();