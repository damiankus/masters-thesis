DROP TABLE IF EXISTS observations;
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

INSERT INTO stations(
	source, id, city,
	latitude, longitude,
	manufacturer, uuid)
SELECT	'airly', 'airly_' || id::text, 'Kraków',
	lattitude, longitude,
	'airly', 'Airly_' || id
FROM airly_stations
ORDER BY id;

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
	source, id, address, city, latitude, longitude,
	manufacturer, uuid)
SELECT 'looko2', 'looko2_' || id::text, station_name, 'Kraków',
	latitude, longitude,
	'looko2', 'Looko2_' || id::text
FROM looko2_stations AS s
WHERE s.station_name IN
(
SELECT MIN(station_name) FROM looko2_stations
GROUP BY id
)
AND latitude IS NOT NULL
AND longitude IS NOT NULL
ORDER BY s.id;

INSERT INTO stations(
	source, id, address, city, latitude, longitude,
	manufacturer, uuid)
SELECT source, id, address, city, latitude, longitude,
	manufacturer, uuid
FROM gios_stations;

CREATE INDEX ON stations(id);

-- Fill the geographical coordinates 
-- of LookO2 stations using the update_geo_coordinates.py script!

-- ===================================
--
-- ===================================

/*
WARNING: it is assumed that the timestamp of observations
refer to the UTC time standard - thus the default TIMESTAMP type 
used in the table (without the time zone)
*/

DROP TABLE IF EXISTS observations;
CREATE TABLE observations (
	id SERIAL PRIMARY KEY,
	station_id CHAR(20) REFERENCES stations(id),
	timestamp TIMESTAMP,
	pm2_5 NUMERIC(9, 5),
	pm10 NUMERIC(9, 5),
	wind_speed NUMERIC(7, 3),
	wind_dir_deg NUMERIC(6, 3),
	precip_total NUMERIC(7, 3),
	precip_rate NUMERIC(7, 3),
	solradiation NUMERIC(8, 3),
	temperature NUMERIC(6, 3),
	humidity NUMERIC(6, 3), 
	pressure NUMERIC(7, 3)
);

-- =====================================

INSERT INTO observations (
	station_id, timestamp,
	temperature, pressure, humidity,
	pm2_5, pm10
)
SELECT 'airly_' || station_id, utc_time, temperature, (pressure / 100.0), humidity, pm2_5, pm10
FROM airly_observations
ORDER BY station_id, utc_time;

-- Note that timestamps are cast to ts in the UTC timezone
INSERT INTO observations (
	station_id, timestamp,
	temperature, pressure, humidity,
	pm2_5, pm10
)
SELECT 'agh_' || station_id, to_timestamp(measurementmillis / 1000) AT time zone 'UTC',
	temperature, (pressure / 100.0), humidity,
	pm2_5, pm10
FROM monitoring_agh_observations AS o
JOIN monitoring_agh_stations AS s
ON o.station_id = s.id
WHERE s.manufacturer <> 'Airly'
ORDER BY station_id, measurementmillis;

INSERT INTO observations (
	station_id, timestamp,
	pm2_5, pm10
)
SELECT 'looko2_' || station_id, format('%s %s:00', date, hour)::timestamp,
	pm2_5, pm10
FROM looko2_observations
JOIN stations AS s 
ON s.id = 'looko2_' || station_id
ORDER BY station_id, date, hour;

INSERT INTO observations (
	station_id, timestamp,
	pm2_5, pm10
)
SELECT station_id, timestamp, pm2_5, pm10
FROM gios_observations
ORDER BY station_id, timestamp;

UPDATE observations 
SET timestamp = date_trunc('hour', timestamp);

/* 
There might be duplicated rows for the same station and timestamp
(not sure why)
*/

DELETE FROM observations
WHERE id IN (
SELECT MIN(id)
FROM observations
GROUP BY station_id, timestamp
HAVING COUNT(*) > 1
);

-- ===================================
-- Removing invalid and missing measurements
-- ===================================

/*
It is assumed that the PMx levels should never
be equal exactly to 0.00. LookO2 data seems to use
this value as an equivalent of an empty measurement
*/

/*
UPDATE observations 
SET pm1 = NULL
WHERE pm1 <= 0;
*/

UPDATE observations 
SET pm2_5 = NULL
WHERE pm2_5 <= 0;

UPDATE observations 
SET pm10 = NULL
WHERE pm10 <= 0;

-- Air quality stations

UPDATE observations 
SET temperature = NULL
WHERE temperature < -25
OR temperature > 40;

UPDATE observations 
SET humidity = NULL
WHERE humidity > 100;

UPDATE observations 
SET pressure = NULL
WHERE pressure < 970
OR PRESSURE > 1050;

UPDATE observations 
SET humidity = NULL
WHERE humidity < 0
OR humidity > 100;

UPDATE observations 
SET wind_speed = NULL
WHERE wind_speed < 0;

UPDATE observations 
SET precip_rate = NULL
WHERE precip_rate < 0;

UPDATE observations 
SET precip_total = NULL
WHERE precip_total < 0;

-- Deleting empty records

/*
It is assumed that the main pollution type to be forecasted
is PM2.5. Records with missing values of PM2.5 won't be 
filled with measurements from other stations because obsevations
can vary vastly based on the environment of the sensor.

UPDATE: On the other hand the missing PM values
can be approximated based on other values in from
the same station, so maybe it is reasonable to leave
them in the dataset
*/ 

/*
DELETE FROM observations
WHERE pm2_5 IS NULL;

DELETE FROM observations
WHERE pm1 IS NULL
AND pm2_5 IS NULL
AND pm10 IS NULL
AND temperature IS NULL
AND humidity IS NULL
AND pressure IS NULL
AND wind_dir_deg IS NULL
AND precip_total IS NULL
AND precip_rate IS NULL
AND solradiation IS NULL;
*/

-- ===================================
-- Indexes on observations

DROP INDEX IF EXISTS observations_timestamp_idx;
DROP INDEX IF EXISTS observations_station_id_idx;
CREATE INDEX ON observations(timestamp);
CREATE INDEX ON observations(station_id);

/*
SELECT date_trunc('day', timestamp) AS date, MIN(temperature), MAX(temperature), AVG(temperature), STDDEV_POP(temperature) 
FROM observations
GROUP BY 1
ORDER BY 1;

SELECT MIN(temperature), MAX(temperature),
	MIN(pressure), MAX(pressure),
	MIN(humidity), MAX(humidity)
FROM observations;

SELECT MIN(temperature), MAX(temperature),
	MIN(pressure), MAX(pressure),
	MIN(humidity), MAX(humidity)
FROM meteo_observations;
*/

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
'Kraków', 50.066667, 19.95, 'agh_meteo');

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
	wind_speed NUMERIC(7, 3), -- m/s!
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
FROM agh_meteo_observations
ORDER BY time;

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

/* Only for GIOS stations there are pre-2017 observations */

DELETE FROM observations
WHERE station_id NOT IN (
	SELECT id FROM gios_stations
);
DELETE FROM stations
WHERE id NOT IN (
	SELECT id FROM gios_stations
);

/*
Deleting outliers
*/

/*
Iniial outlier elimination for specific factors
*/

UPDATE meteo_observations 
SET temperature = NULL
WHERE temperature < -25
OR temperature > 40;

UPDATE meteo_observations 
SET humidity = NULL
WHERE humidity > 100;

UPDATE meteo_observations 
SET pressure = NULL
WHERE pressure < 970
OR PRESSURE > 1050;

UPDATE meteo_observations 
SET humidity = NULL
WHERE humidity <= 0
OR humidity > 100;

UPDATE meteo_observations 
SET precip_rate = NULL
WHERE precip_rate < 0;

UPDATE meteo_observations 
SET precip_total = NULL
WHERE precip_total < 0;

UPDATE meteo_observations 
SET wind_dir_deg = NULL
WHERE wind_dir_deg < 0
OR wind_dir_deg > 360;

UPDATE meteo_observations 
SET wind_speed = NULL
WHERE wind_speed < 0;

/*
Based on the number of row with wind speed equal to 0 it seems
it can be a value meaning the lack of measurement.
The precip_* variables are a similar case but it's actually
possible that a large portion of measurements is 0-valued
(there might be no rain for long periods of time).
*/

-- Deleting outliers based on the percentile thresholds for a single hour
DROP FUNCTION IF EXISTS delete_hourly_percentile_outliers(text, text, real, real);
CREATE OR REPLACE FUNCTION delete_hourly_percentile_outliers(
	tabname text, colname text, lower_threshold real, upper_threshold real)
RETURNS VOID AS $$
DECLARE
	query text;
	temp_table_query text;
BEGIN
	DROP TABLE IF EXISTS thresholds;
	temp_table_query := format('
	CREATE TEMP TABLE thresholds AS(
	SELECT timestamp,
	percentile_cont(%1$s) WITHIN GROUP (ORDER BY %3$s) AS lower,
	percentile_cont(%2$s) WITHIN GROUP (ORDER BY %3$s) AS upper
	FROM %4$s
	GROUP BY timestamp
	)', lower_threshold, upper_threshold, colname, tabname);

	RAISE NOTICE '%', temp_table_query;
	EXECUTE temp_table_query;
	CREATE INDEX ON thresholds(timestamp);
	
	query := format('
	UPDATE %1$s
	SET %2$s = NULL
	WHERE id IN (
		SELECT obs.id
		FROM %1$s as obs
		JOIN thresholds AS th ON th.timestamp = obs.timestamp
		WHERE obs.%2$s < th.lower
		OR obs.%2$s > th.upper
	)', tabname, colname);
	
	RAISE NOTICE 'Deleting outlier values from column %', colname;
	RAISE NOTICE '%', query;
	EXECUTE query;
	DROP TABLE thresholds;
END;
$$  LANGUAGE plpgsql;

-- SELECT delete_hourly_percentile_outliers('meteo_observations', 'temperature', 0, 0.99);
-- SELECT delete_hourly_percentile_outliers('meteo_observations', 'pressure', 0, 0.99);


-- Deleting outliers based on the monthly percentile thresholds
DROP FUNCTION IF EXISTS delete_monthly_percentile_outliers(text, text, int, int, real, real);
CREATE OR REPLACE FUNCTION delete_monthly_percentile_outliers(
	tabname text, colname text, year int, month int, lower_threshold real, upper_threshold real)
RETURNS VOID AS $$
DECLARE
	query text;
	temp_table_query text;
BEGIN
	DROP TABLE IF EXISTS thresholds;
	temp_table_query := format('
	CREATE TEMP TABLE thresholds AS(
	SELECT date_trunc(''month'', timestamp) as month,
	percentile_cont(%1$s) WITHIN GROUP (ORDER BY %3$s) AS lower,
	percentile_cont(%2$s) WITHIN GROUP (ORDER BY %3$s) AS upper
	FROM %4$s
	GROUP BY 1
	)', lower_threshold, upper_threshold, colname, tabname);

	RAISE NOTICE '%', temp_table_query;
	EXECUTE temp_table_query;
	CREATE INDEX ON thresholds(month);
	
	query := format('
	UPDATE %1$s
	SET %2$s = NULL
	WHERE id IN (
		SELECT obs.id
		FROM %1$s as obs
		JOIN thresholds AS th ON th.month = date_trunc(''month'', obs.timestamp)
		WHERE EXTRACT(year FROM obs.timestamp) = %3$s 
		AND EXTRACT(month FROM obs.timestamp) = %4$s
		AND (obs.%2$s < th.lower OR obs.%2$s > th.upper)
	)', tabname, colname, year, month);
	
	RAISE NOTICE 'Deleting outlier values from column %', colname;
	RAISE NOTICE '%', query;
	EXECUTE query;
	DROP TABLE thresholds;
END;
$$  LANGUAGE plpgsql;

SELECT delete_monthly_percentile_outliers('meteo_observations', 'temperature', 2016, 12, 0, 0.99);
SELECT delete_monthly_percentile_outliers('meteo_observations', 'temperature', 2017, 1, 0, 0.98);
SELECT delete_monthly_percentile_outliers('meteo_observations', 'temperature', 2017, 2, 0, 0.98);
SELECT delete_monthly_percentile_outliers('meteo_observations', 'temperature', 2017, 3, 0, 0.98);

/*
Deleting empty records
Note: Each day at 10 p.m. the AGH station 
saves an empty record (probably because of
the maintanance) which should be removed.
*/

/*
DELETE FROM meteo_observations
WHERE temperature IS NULL
AND humidity IS NULL
AND pressure IS NULL
AND wind_speed IS NULL
AND wind_dir_deg IS NULL
AND precip_total IS NULL
AND precip_rate IS NULL
AND solradiation IS NULL;
*/

CREATE INDEX ON meteo_observations(timestamp);
CREATE INDEX ON meteo_observations(station_id);
CREATE INDEX ON meteo_observations(temperature) WHERE temperature IS NOT NULL;
CREATE INDEX ON meteo_observations(pressure) WHERE pressure IS NOT NULL;
CREATE INDEX ON meteo_observations(humidity) WHERE humidity IS NOT NULL;
CREATE INDEX ON meteo_observations(wind_speed) WHERE wind_speed IS NOT NULL;
CREATE INDEX ON meteo_observations(wind_dir_deg) WHERE wind_dir_deg IS NOT NULL;
CREATE INDEX ON meteo_observations(precip_total) WHERE precip_total IS NOT NULL;
CREATE INDEX ON meteo_observations(precip_rate) WHERE precip_rate IS NOT NULL;
CREATE INDEX ON meteo_observations(solradiation) WHERE solradiation IS NOT NULL;
CLUSTER meteo_observations USING "meteo_observations_timestamp_idx";

CREATE INDEX ON observations(temperature) WHERE temperature IS NULL;
CREATE INDEX ON observations(pressure) WHERE pressure IS NULL;
CREATE INDEX ON observations(humidity) WHERE humidity IS NULL;
CREATE INDEX ON observations(wind_speed) WHERE wind_speed IS NULL;
CREATE INDEX ON observations(wind_dir_deg) WHERE wind_dir_deg IS NULL;
CREATE INDEX ON observations(precip_total) WHERE precip_total IS NULL;
CREATE INDEX ON observations(precip_rate) WHERE precip_rate IS NULL;
CREATE INDEX ON observations(solradiation) WHERE solradiation IS NULL;

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
SELECT row_number() OVER() AS id, dist.*
FROM (
	SELECT s1.id AS station_id1, s2.id AS station_id2, 
		(ACOS(
			SIN(radians(s1.latitude)) * SIN(radians(s2.latitude)) 
			+ COS(radians(s1.latitude)) * COS(radians(s2.latitude)) 
			* COS(radians(s2.longitude) - radians(s1.longitude))
		) * 6371000) AS dist,
		s1.latitude AS latitude1, s1.longitude AS longitude1,
		s2.latitude AS latitude2, s2.longitude AS longitude2
	FROM stations AS s1
	CROSS JOIN meteo_stations AS s2
	WHERE s1.id <> s2.id
	ORDER BY 1, 3, 2
) AS dist
);

ALTER TABLE meteo_distance ADD PRIMARY KEY (id);
CREATE INDEX ON meteo_distance(station_id1);
CREATE INDEX ON meteo_distance(station_id2);
CLUSTER meteo_distance USING "meteo_distance_station_id1_idx";

/*
Similarly, calculate the distance between
the stations measuring air quality.
*/

DROP TABLE IF EXISTS air_quality_distance;
CREATE TABLE air_quality_distance AS (
SELECT row_number() OVER() AS id, dist.*
FROM (
	SELECT s1.id AS station_id1, s2.id AS station_id2, 
		(ACOS(
			SIN(radians(s1.latitude)) * SIN(radians(s2.latitude)) 
			+ COS(radians(s1.latitude)) * COS(radians(s2.latitude)) 
			* COS(radians(s2.longitude) - radians(s1.longitude))
		) * 6371000) AS dist,
		s1.latitude AS latitude1, s1.longitude AS longitude1,
		s2.latitude AS latitude2, s2.longitude AS longitude2
	FROM stations AS s1
	CROSS JOIN stations AS s2
	WHERE s1.id <> s2.id
	ORDER BY 1, 3, 2
) AS dist
);

ALTER TABLE air_quality_distance ADD PRIMARY KEY (id);
CREATE INDEX ON air_quality_distance(station_id1);
CREATE INDEX ON air_quality_distance(station_id2);
CLUSTER air_quality_distance USING "air_quality_distance_station_id1_idx";

/*
A function creating empty records for timestamps not
present in the data set. Columns will then be imputed
(wherever possible) with the fill_missing function.
The remaining empty values will be imputed in an R script,
using the MICE package.
*/

DROP FUNCTION IF EXISTS create_empty_records();
CREATE OR REPLACE FUNCTION create_empty_records()
RETURNS VOID AS $$
DECLARE
	sid CHAR(20);
	min_ts timestamp;
	max_ts timestamp;
	min_ts_for_station timestamp;
	max_ts_for_station timestamp;
BEGIN
	min_ts := (SELECT MIN(timestamp) FROM observations);
	max_ts := (SELECT MAX(timestamp) FROM observations);
	raise notice '% %', min_ts, max_ts;
	DROP TABLE IF EXISTS ts_seq;
	CREATE TEMP TABLE ts_seq AS (
		SELECT generate_series AS timestamp FROM generate_series(min_ts, max_ts, '1 hour'::interval)
	);
	CREATE INDEX ON ts_seq(timestamp);
	
	FOR sid IN SELECT id FROM stations
	LOOP
		RAISE NOTICE '%', sid;
		min_ts_for_station := (SELECT MIN(timestamp) FROM observations WHERE station_id = sid);
		max_ts_for_station := (SELECT MAX(timestamp) FROM observations WHERE station_id = sid);
		INSERT INTO observations (station_id, timestamp) (
			SELECT sid AS station_id, timestamp FROM ts_seq
				WHERE timestamp BETWEEN min_ts_for_station AND max_ts_for_station
			EXCEPT
			SELECT station_id, timestamp FROM observations WHERE station_id = sid);
			
	END LOOP;
	DROP TABLE ts_seq;
END;
$$  LANGUAGE plpgsql;

SELECT create_empty_records();

/*
A function filling missing values by 
copying them from the nearest meteo station
containing the desired value
*/

DROP FUNCTION IF EXISTS fill_missing(TEXT[]);
CREATE OR REPLACE FUNCTION fill_missing(meteo_cols TEXT[])
RETURNS VOID AS $$
DECLARE
	air_quality_cols text[];
	col text;
	query text;
	query_template text;
BEGIN
	/*
	The following query is based on the assumption that
	the rows in the distance tables are sorted ascending
	by the distance between stations
	parameters: 
	target table, source table, distance table, column name
	*/
	query_template := '
	UPDATE %1$s AS obs
	SET %4$s = nearest.%4$s
	FROM (
		SELECT dist_rows.station_id, dist_rows.timestamp, nearest.%4$s 
		FROM (
			SELECT obs.timestamp, obs.station_id, MIN(dist.id) AS row_id
			FROM %1$s as obs
			JOIN %3$s as dist
			ON dist.station_id1 = obs.station_id
			JOIN %2$s as other
			ON other.station_id = dist.station_id2
			AND other.timestamp = obs.timestamp
			WHERE obs.%4$s IS NULL
			AND other.%4$s IS NOT NULL
			GROUP BY obs.station_id, obs.timestamp
		) AS dist_rows
		JOIN %3$s AS dist
		ON dist.id = dist_rows.row_id
		JOIN %2$s as nearest
		ON nearest.station_id = dist.station_id2
		AND nearest.timestamp = dist_rows.timestamp
	) AS nearest
	WHERE nearest.station_id = obs.station_id
	AND nearest.timestamp = obs.timestamp';

	/* 
	Filling missing PM data with measurements from another station
	can be risky because they can be vastly different depending
	on the location of the station 
	
        air_quality_cols := ARRAY['pm1', 'pm2_5', 'pm10'];
	FOREACH col IN ARRAY air_quality_cols
	LOOP	
		query := format(query_template, 'observations', 'observations', 
		 'air_quality_distance', col);
		 
		RAISE NOTICE 'Filling missing % values', col;
		RAISE NOTICE '%', query;
		EXECUTE query;
	END LOOP;
	*/
	
	FOREACH col IN ARRAY meteo_cols
	LOOP
		query := format(query_template, 'observations', 'meteo_observations',
		 'meteo_distance', col);
		 
		RAISE NOTICE 'Filling missing % values', col;
		RAISE NOTICE '%', query;
		EXECUTE query;
	END LOOP;
END;
$$  LANGUAGE plpgsql;

SELECT fill_missing(ARRAY['temperature', 'humidity', 'pressure', 'wind_speed', 'wind_dir_deg', 'precip_total',
		'precip_rate', 'solradiation']);

-- ===================================
-- Creating auxilliary variables
-- ===================================

ALTER TABLE observations DROP COLUMN IF EXISTS is_holiday;
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
	OR (EXTRACT(MONTH FROM timestamp) = 12 AND EXTRACT(DAY FROM timestamp) = 26)
	-- Easter Mondays
	OR date_trunc('day', timestamp) = '2017-04-17'
	OR date_trunc('day', timestamp) = '2017-03-28'
	OR date_trunc('day', timestamp) = '2017-04-02';

-- ===================================

ALTER TABLE observations DROP COLUMN IF EXISTS period_of_day;
ALTER TABLE observations ADD COLUMN period_of_day INT;

-- Winter is split into two periods: January - Match and December
UPDATE observations 
SET period_of_day = 1
WHERE EXTRACT(HOUR FROM timestamp) BETWEEN 0 AND 5;
UPDATE observations 
SET period_of_day = 2
WHERE EXTRACT(HOUR FROM timestamp) BETWEEN 6 AND 11;
UPDATE observations 
SET period_of_day = 3
WHERE EXTRACT(HOUR FROM timestamp) BETWEEN 12 AND 17;
UPDATE observations
SET period_of_day = 4
WHERE EXTRACT(HOUR FROM timestamp) BETWEEN 18 AND 23;

-- ===================================

ALTER TABLE observations DROP COLUMN IF EXISTS season;
ALTER TABLE observations ADD COLUMN season INT;

UPDATE observations 
SET season = 1
WHERE to_char(timestamp::date, 'MM-dd') < '03-21'
OR to_char(timestamp::date, 'MM-dd') > '12-21';
UPDATE observations 
SET season = 2
WHERE to_char(timestamp::date, 'MM-dd') BETWEEN '03-21' AND '06-21';
UPDATE observations 
SET season = 3
WHERE to_char(timestamp::date, 'MM-dd') BETWEEN '06-22' AND '09-22';
UPDATE observations
SET season = 4
WHERE to_char(timestamp::date, 'MM-dd') BETWEEN '09-23' AND '12-21';

-- ===================================

ALTER TABLE observations DROP COLUMN IF EXISTS is_heating_season;
ALTER TABLE observations ADD COLUMN is_heating_season smallint DEFAULT 0;
UPDATE observations 
SET is_heating_season = 1
WHERE EXTRACT(MONTH FROM timestamp) BETWEEN 1 AND 3
OR EXTRACT(MONTH FROM timestamp) BETWEEN 9 AND 12;

-- ===================================

ALTER TABLE observations DROP COLUMN IF EXISTS month;
ALTER TABLE observations ADD COLUMN month INT;
UPDATE observations 
SET month = EXTRACT(MONTH FROM timestamp);

ALTER TABLE observations DROP COLUMN IF EXISTS year;
ALTER TABLE observations ADD COLUMN year INT;
UPDATE observations 
SET year = EXTRACT(YEAR FROM timestamp);

-- ===================================

ALTER TABLE observations DROP COLUMN IF EXISTS day_of_week;
ALTER TABLE observations ADD COLUMN day_of_week INT;
UPDATE observations 
SET day_of_week = -0.5 * COS(2 * PI() * EXTRACT(DOW FROM timestamp) / 6) + 0.5;

-- ===================================

-- Transform the date to a continuous value

ALTER TABLE observations DROP COLUMN IF EXISTS day_of_year;
ALTER TABLE observations ADD COLUMN day_of_year FLOAT;
UPDATE observations 
SET day_of_year = -0.5 * COS(2 * PI() * EXTRACT(DOY FROM timestamp) / 365.0) + 0.5;

-- Transform the hour of day to a continuous value

ALTER TABLE observations DROP COLUMN IF EXISTS hour_of_day;
ALTER TABLE observations ADD COLUMN hour_of_day FLOAT;
UPDATE observations 
SET hour_of_day = -0.5 * COS(2 * PI() * EXTRACT(HOUR FROM timestamp) / 24.0) + 0.5;

-- ===================================

ALTER TABLE observations DROP COLUMN IF EXISTS wind_dir_rad;
ALTER TABLE observations ADD COLUMN wind_dir_rad FLOAT;
UPDATE observations 
SET wind_dir_rad = wind_dir_deg * PI() / 180;

/* WARNING:
 EW component should be calculated as SIN(rads) 
 NS component should be calculated as COS(rads)
 
 It hasn't been changed yet to preserve the original 
 transformations used to obtain thesis results.
 
 This error stems from not taking into account the fact that
 the North direction corresponds to the beginning of the coordinate system.
 
              E (90 deg)
              ^  /
              | /
              |/alpha
       S------|------>N (0 deg)  
              |
              |
              W
              
 which corresponds to directions on a compass dial
 
	      N (0)
              ^
              |
              |            
 (270) W------|------>E (90)
              |
              |
              S (180)
        
  Originally it was assumed that wind direction scale starts from Eeast and goes counter-clockwise
  ENWS, like this:
  
              N (90)
              ^  /
              | /
              |/alpha
       W------|------>E (0)
              |
              |
              S
*/
ALTER TABLE observations DROP COLUMN IF EXISTS wind_dir_ew;
ALTER TABLE observations ADD COLUMN wind_dir_ew FLOAT;
UPDATE observations 
SET wind_dir_ew = COS(wind_dir_rad);

ALTER TABLE observations DROP COLUMN IF EXISTS wind_dir_ns;
ALTER TABLE observations ADD COLUMN wind_dir_ns FLOAT;
UPDATE observations 
SET wind_dir_ns = SIN(wind_dir_rad);

/*
Values in this column are linearly dependent on the values
in the wind_dir_deg column which is problematic while finding
the best subsets for regression.
*/
ALTER TABLE observations DROP COLUMN IF EXISTS wind_dir_rad;

-- SELECT * FROM pg_indexes WHERE tablename = 'observations';
DROP INDEX "observations_temperature_idx";
DROP INDEX "observations_pressure_idx";
DROP INDEX "observations_humidity_idx";
DROP INDEX "observations_wind_speed_idx";
DROP INDEX "observations_wind_dir_deg_idx";
DROP INDEX "observations_precip_total_idx";
DROP INDEX "observations_precip_rate_idx";
DROP INDEX "observations_solradiation_idx";

-- ===================================
-- Adding time-lagged PM level values
-- ===================================

DROP FUNCTION IF EXISTS add_time_lagged(TEXT, INT, INT, INT);
CREATE OR REPLACE FUNCTION add_time_lagged(colname TEXT, start_idx INT, end_idx INT, step INT)
RETURNS VOID AS $$
DECLARE
	lag INT;
	lagged_colname TEXT;
	query TEXT;
	drop_temp TEXT;
	create_temp TEXT;
	update_temp TEXT;
BEGIN
	drop_temp := 'ALTER TABLE observations DROP COLUMN IF EXISTS %s';
	create_temp := 'ALTER TABLE observations ADD COLUMN %s NUMERIC(22, 15)';
	update_temp := '
		UPDATE observations AS upd_obs
		SET %s = upd_obs%s.%s
		FROM observations AS upd_obs%s
		WHERE upd_obs%s.timestamp = upd_obs.timestamp - INTERVAL ''%s hours''
		AND upd_obs%s.station_id = upd_obs.station_id';
	FOR lag IN start_idx..end_idx BY step
	LOOP	
		lagged_colname := colname || '_minus_' || lag;		
		RAISE NOTICE 'Creating a time-lagged column %', lagged_colname;
		query := format(drop_temp, lagged_colname);
		EXECUTE query;
		query := format(create_temp, lagged_colname);
		EXECUTE query;
		query := format(update_temp, lagged_colname, lag, colname, lag, lag, lag, lag);
		EXECUTE query;
	END LOOP;
END;
$$  LANGUAGE plpgsql;

-- ===================================
-- Dropping time-lagged columns
-- ===================================

DROP FUNCTION IF EXISTS drop_time_lagged(TEXT, INT, INT, INT);
CREATE OR REPLACE FUNCTION drop_time_lagged(colname TEXT, start_idx INT, end_idx INT, step INT)
RETURNS VOID AS $$
DECLARE
	lag INT;
	lagged_colname TEXT;
	query TEXT;
	query_template TEXT;
BEGIN
	query_template := 'ALTER TABLE observations DROP COLUMN IF EXISTS %s';
	FOR lag IN start_idx..end_idx BY step
	LOOP	
		lagged_colname := colname || '_minus_' || lag;
		query := format(query_template, lagged_colname);
		
		RAISE NOTICE 'Dropping a time-lagged column %', lagged_colname;
		RAISE NOTICE '%', query;
		EXECUTE query;
	END LOOP;
END;
$$  LANGUAGE plpgsql;

/*
SELECT add_time_lagged('pm2_5', 1, 3, 1);
SELECT drop_time_lagged('pm2_5', 1, 3, 1);
*/
 
-- ===================================
-- Adding future PM level values
-- ===================================

DROP FUNCTION IF EXISTS add_future_vals(TEXT, INT[]);
CREATE OR REPLACE FUNCTION add_future_vals(colname TEXT, time_deltas INT[])
RETURNS VOID AS $$
DECLARE
	lag INT;
	lagged_colname TEXT;
	query TEXT;
	drop_temp TEXT;
	create_temp TEXT;
	update_temp TEXT;
	fill_temp TEXT;
BEGIN
	drop_temp := 'ALTER TABLE observations DROP COLUMN IF EXISTS %s';
	create_temp := 'ALTER TABLE observations ADD COLUMN %s NUMERIC(22, 15)';
	update_temp := '
		UPDATE observations AS upd_obs
		SET %s = upd_obs%s.%s
		FROM observations AS upd_obs%s
		WHERE upd_obs%s.timestamp = upd_obs.timestamp + INTERVAL ''%s hours''
		AND upd_obs%s.station_id = upd_obs.station_id';
		
	FOREACH lag IN ARRAY time_deltas
	LOOP	
		lagged_colname := colname || '_plus_' || lag;		
		RAISE NOTICE 'Creating a time-lagged column %', lagged_colname;
		query := format(drop_temp, lagged_colname);
		EXECUTE query;
		query := format(create_temp, lagged_colname);
		EXECUTE query;
		query := format(update_temp, lagged_colname, lag, colname, lag, lag, lag, lag);
		EXECUTE query;
	END LOOP;
END;
$$  LANGUAGE plpgsql;

-- ===================================
-- Dropping time-lagged columns
-- ===================================

DROP FUNCTION IF EXISTS drop_future_vals(TEXT, INT[]);
CREATE OR REPLACE FUNCTION drop_future_vals(colname TEXT, time_deltas INT[])
RETURNS VOID AS $$
DECLARE
	lag INT;
	lagged_colname TEXT;
	query TEXT;
	query_template TEXT;
BEGIN
	query_template := 'ALTER TABLE observations DROP COLUMN IF EXISTS %s';
	FOREACH lag IN ARRAY time_deltas
	LOOP	
		lagged_colname := colname || '_plus_' || lag;
		query := format(query_template, lagged_colname);
		
		RAISE NOTICE 'Dropping a time-lagged column %', lagged_colname;
		RAISE NOTICE '%', query;
		EXECUTE query;
	END LOOP;
END;
$$  LANGUAGE plpgsql;

/*
SELECT add_future_vals('pm2_5', ARRAY[24]);
SELECT drop_future_vals('pm2_5', ARRAY[12]);
*/

DROP FUNCTION IF EXISTS add_daily_aggr_vals(TEXT, TEXT[]);
CREATE OR REPLACE FUNCTION add_daily_aggr_vals(tabname TEXT, colnames TEXT[])
RETURNS VOID AS $$
DECLARE
	drop_temp TEXT;
	create_temp TEXT;
	update_temp TEXT;
	query TEXT;
	colname TEXT;
	aggr_type TEXT;
	aggr_types TEXT[];
BEGIN
	drop_temp := 'ALTER TABLE %1$s DROP COLUMN IF EXISTS %3$s_daily_%2$s';
	create_temp := 'ALTER TABLE %1$s ADD COLUMN %3$s_daily_%2$s NUMERIC(22, 15)';
	aggr_types := ARRAY['min', 'avg', 'max'];

	FOREACH colname IN ARRAY colnames
	LOOP	
		FOREACH aggr_type IN ARRAY aggr_types
		LOOP	
			EXECUTE format(drop_temp, tabname, colname, aggr_type);
			--EXECUTE format(create_temp, tabname, colname, aggr_type);
		END LOOP;
	END LOOP;

	update_temp := '
		UPDATE %1$s AS obs
		SET min_daily_%2$s = aggr_obs.min_daily_%2$s, avg_daily_%2$s = aggr_obs.avg_daily_%2$s, max_daily_%2$s = aggr_obs.max_daily_%2$s
		FROM (
			SELECT station_id, date_trunc(''day'', timestamp) AS timestamp, 
				MIN(%2$s) AS min_daily_%2$s,
				AVG(%2$s) AS avg_daily_%2$s,
				MAX(%2$s) AS max_daily_%2$s
			FROM %1$s
			GROUP BY 1, 2
			ORDER BY 1, 2
		) AS aggr_obs
		WHERE aggr_obs.station_id = obs.station_id
		AND aggr_obs.timestamp = date_trunc(''day'', obs.timestamp)';
		
	FOREACH colname IN ARRAY colnames
	LOOP	
		query := format(update_temp, tabname, colname);
		RAISE NOTICE '%', query;
		EXECUTE query;
	END LOOP;
END;
$$  LANGUAGE plpgsql;

SELECT add_daily_aggr_vals('observations', 
	ARRAY['temperature', 'pressure', 'humidity', 'wind_speed',
	      'wind_dir_deg', 'wind_dir_ew', 'wind_dir_ns']);