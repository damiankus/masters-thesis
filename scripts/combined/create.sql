DROP TABLE IF EXISTS observations;
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
WHERE manufacturer <> 'Airly';

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
);

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

select * from pg_indexes where tablename = 'observations';
CREATE INDEX ON observations(timestamp);
CREATE INDEX ON observations(station_id);
CLUSTER observations USING "observations_timestamp_idx";


-- ===================================
--
-- ===================================

ALTER TABLE observations DROP COLUMN is_holiday;
ALTER TABLE observations ADD COLUMN is_holiday INT DEFAULT 0;

UPDATE observations 
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

ALTER TABLE observations DROP COLUMN period_of_day;
ALTER TABLE observations ADD COLUMN period_of_day INT;

UPDATE observations 
SET period_of_day = 0
WHERE EXTRACT(HOUR FROM timestamp) BETWEEN 0 AND 5;
UPDATE observations 
SET period_of_day = 1
WHERE EXTRACT(HOUR FROM timestamp) BETWEEN 6 AND 11;
UPDATE observations 
SET period_of_day = 2
WHERE EXTRACT(HOUR FROM timestamp) BETWEEN 12 AND 17;
UPDATE observations 
SET period_of_day = 3
WHERE EXTRACT(HOUR FROM timestamp) BETWEEN 18 AND 23;

-- ===================================
--
-- ===================================

ALTER TABLE observations DROP COLUMN is_heating_season;
ALTER TABLE observations ADD COLUMN is_heating_season BOOLEAN DEFAULT FALSE;
UPDATE observations 
SET is_heating_season = TRUE
WHERE EXTRACT(MONTH FROM timestamp) BETWEEN 1 AND 3
OR EXTRACT(MONTH FROM timestamp) BETWEEN 9 AND 12;

-- ===================================
--
-- ===================================

ALTER TABLE observations DROP COLUMN day_of_week;
ALTER TABLE observations ADD COLUMN day_of_week INT;
UPDATE observations 
SET day_of_week = EXTRACT(DOW FROM timestamp);

-- ===================================
--
-- ===================================


DROP TABLE combined_observations;
CREATE TABLE combined_observations AS (
	SELECT o.*, mo.avg_wind_speed, mo.avg_wind_dir
	FROM observations AS o
	INNER JOIN (SELECT time, sm_hour_avg AS avg_wind_speed, dm_hour_avg AS avg_wind_dir
	FROM meteo_observations) AS mo
	ON mo.time = o.timestamp
);

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

INSERT INTO meteo_stations (id, address, city, latitude, longitude, source)
VALUES('AGH_METEO', 'Akademia Górniczo-Hutnicza Wydział Fizyki i Informatyki Stosowanej ul. Reymonta 19, budynek D-10',
'Kraków', 50.04, 19.57, 'agh');

INSERT INTO meteo_stations (id, address, city, latitude, longitude, source)
SELECT id, neighborhood, city, lat, lon, 'wunderground' 
FROM wunderground_stations 
ORDER BY id;

DROP TABLE IF EXISTS meteo_observations;
CREATE TABLE meteo_observations (
	ID SERIAL PRIMARY KEY,
	station_id CHAR(20) REFERENCES meteo_stations(id),
	timestamp TIMESTAMP,
	temperature NUMERIC(5, 3),
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
SELECT 'AGH_METEO', time, ta_hour_avg, ua_hour_avg, pa_hour_avg,
	sm_hour_avg, dm_hour_avg, rc_hour_avg,
	ri_hour_avg
FROM meteo_agh_observations
ORDER BY time;
select * from meteo_observations

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

select * from meteo_observations 
where timestamp = '2017-01-01 12:00:00'