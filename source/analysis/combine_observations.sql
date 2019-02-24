SET TIME ZONE 'UTC';

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

-- Because of the availability of data spanning multiple years
-- only the observations from the GIOS database are used for research

INSERT INTO stations(
	source, id, address, city, latitude, longitude,
	manufacturer, uuid)
SELECT source, id, address, city, latitude, longitude,
	manufacturer, uuid
FROM gios_stations;

CREATE INDEX ON stations(id);

-- ===================================
--
-- ===================================

/*
WARNING: Be careful while handling time data
For the purpose of the thesis it is assumed that 
the timestamp column should represent the UTC time 
which an observation was taken at. The GIOS time data
are specified for the CET time zone so they must be
cast to UTC before being used
*/

DROP TABLE IF EXISTS observations;
CREATE TABLE observations (
	id SERIAL PRIMARY KEY,
	station_id CHAR(20) REFERENCES stations(id),
	measurement_time TIMESTAMP,
	pm2_5 NUMERIC(9, 5),
	pm10 NUMERIC(9, 5),
	wind_speed NUMERIC(7, 3),
	wind_dir_deg NUMERIC(6, 3),
	precip_rate NUMERIC(7, 3),
	solradiation NUMERIC(8, 3),
	temperature NUMERIC(6, 3),
	humidity NUMERIC(6, 3), 
	pressure NUMERIC(7, 3)
);


-- =====================================

INSERT INTO observations(station_id, measurement_time, pm2_5, pm10)
SELECT station_id, date_trunc('hour', measurement_time), pm2_5, pm10
FROM gios_observations
ORDER BY measurement_time, station_id;

-- ===================================
-- Indexes on observations
-- ===================================

DROP INDEX IF EXISTS observations_measurement_time_idx;
DROP INDEX IF EXISTS observations_station_id_idx;
CREATE INDEX ON observations(measurement_time);
CREATE INDEX ON observations(station_id);

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

INSERT INTO meteo_stations(
	id, city, latitude, longitude, source)
SELECT	'airly_' || id::text, 'Kraków', latitude, longitude, 'airly'
FROM airly_stations
ORDER BY id;

DROP TABLE IF EXISTS meteo_observations;
CREATE TABLE meteo_observations (
	ID SERIAL PRIMARY KEY,
	station_id CHAR(20) REFERENCES meteo_stations(id),
	measurement_time TIMESTAMP,
	temperature NUMERIC(6, 3),
	humidity NUMERIC(6, 3), 
	pressure NUMERIC(7, 3), 
	wind_speed NUMERIC(7, 3), -- m/s!
	wind_dir_deg NUMERIC(6, 3),
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

INSERT INTO meteo_observations(station_id, measurement_time, temperature,
	 humidity, pressure, wind_speed, wind_dir_deg, precip_rate)
SELECT 'agh_meteo', time, ta_hour_avg, ua_hour_avg, pa_hour_avg,
	sm_hour_avg, dm_hour_avg, ri_hour_avg
FROM agh_meteo_observations
ORDER BY time;


/*
It is assumed that the hourly mean values
are calculated for a period from the beginning to the end 
of the given hour e.g. mean values for 12:00 are calculated based on
measurements from 12:00 to 12:59
*/

INSERT INTO meteo_observations(station_id, measurement_time, temperature,
	 humidity, pressure, wind_speed, wind_dir_deg,
	 precip_rate, solradiation)
SELECT station_id, date_trunc('hour', timestamp),
	AVG(temperature), AVG(humidity), AVG(pressure), AVG(wind_speed),
	AVG(wind_dir_deg), AVG(precip_rate), AVG(solradiation)
FROM wunderground_observations 
GROUP BY 1, 2
ORDER BY 1, 2;

-- Pressure for Airly stations is expressed in pascals (not hectopascals)
INSERT INTO meteo_observations (
	station_id, measurement_time,
	temperature, pressure, humidity
)
SELECT 'airly_' || station_id, utc_time, temperature, (pressure / 100.0), humidity
FROM airly_observations
WHERE (temperature IS NOT NULL OR
pressure IS NOT NULL OR
humidity IS NOT NULL) AND
-- Airly data contain some weird humidity measurements e.g. < -10 000
(humidity IS NULL OR (humidity BETWEEN 0 AND 100))
ORDER BY station_id, utc_time;

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
	cur_station_id CHAR(20);
	min_ts timestamp;
	max_ts timestamp;
	min_ts_for_station timestamp;
	max_ts_for_station timestamp;
BEGIN
	min_ts := (SELECT MIN(measurement_time) FROM observations);
	max_ts := (SELECT MAX(measurement_time) FROM observations);
	RAISE NOTICE '% %', min_ts, max_ts;
	DROP TABLE IF EXISTS ts_seq;
	CREATE TEMP TABLE ts_seq AS (
		SELECT generate_series AS measurement_time FROM generate_series(min_ts, max_ts, '1 hour'::interval)
	);
	CREATE INDEX ON ts_seq(measurement_time);
	
	FOR cur_station_id IN SELECT id FROM stations
	LOOP
		RAISE NOTICE '%', cur_station_id;
		INSERT INTO observations (station_id, measurement_time) (
			SELECT cur_station_id AS station_id, measurement_time FROM ts_seq
			EXCEPT SELECT station_id, measurement_time FROM observations WHERE station_id = cur_station_id
		);
	END LOOP;
END;
$$  LANGUAGE plpgsql;

SELECT create_empty_records();

-- ===================================
-- Creating auxilliary variables
-- ===================================

ALTER TABLE observations DROP COLUMN IF EXISTS is_holiday;
ALTER TABLE observations ADD COLUMN is_holiday INT DEFAULT 0;
UPDATE observations 
SET is_holiday = 1 WHERE
-- Sunday
EXTRACT(DOW FROM measurement_time) = 0 
-- Saturday
OR EXTRACT(DOW FROM measurement_time) = 6	
-- New Year
OR (EXTRACT(MONTH FROM measurement_time) = 1 AND EXTRACT(DAY FROM measurement_time) = 1)
-- Epiphany (Catholic holiday)
OR (EXTRACT(MONTH FROM measurement_time) = 1 AND EXTRACT(DAY FROM measurement_time) = 6)
-- Labour Day
OR (EXTRACT(MONTH FROM measurement_time) = 5 AND EXTRACT(DAY FROM measurement_time) = 1)
-- Constitution Day
OR (EXTRACT(MONTH FROM measurement_time) = 5 AND EXTRACT(DAY FROM measurement_time) = 3)
-- Assumption of Mary (Catholic holiday)
OR (EXTRACT(MONTH FROM measurement_time) = 8 AND EXTRACT(DAY FROM measurement_time) = 15)
-- All Saints' Day (Catholic holiday)
OR (EXTRACT(MONTH FROM measurement_time) = 11 AND EXTRACT(DAY FROM measurement_time) = 1)
-- Independence Day
OR (EXTRACT(MONTH FROM measurement_time) = 11 AND EXTRACT(DAY FROM measurement_time) = 11)
-- Christmas
OR (EXTRACT(MONTH FROM measurement_time) = 12 AND EXTRACT(DAY FROM measurement_time) = 25)
-- Christmas - 2nd day
OR (EXTRACT(MONTH FROM measurement_time) = 12 AND EXTRACT(DAY FROM measurement_time) = 26);

-- ===================================

ALTER TABLE observations DROP COLUMN IF EXISTS is_heating_season;
ALTER TABLE observations ADD COLUMN is_heating_season smallint DEFAULT 0;
UPDATE observations 
SET is_heating_season = 1
WHERE EXTRACT(MONTH FROM measurement_time) BETWEEN 1 AND 3
OR EXTRACT(MONTH FROM measurement_time) BETWEEN 9 AND 12;

-- ===================================

ALTER TABLE observations DROP COLUMN IF EXISTS year;
ALTER TABLE observations ADD COLUMN year INT;
UPDATE observations 
SET year = EXTRACT(YEAR FROM measurement_time);

-- ===================================

ALTER TABLE observations DROP COLUMN IF EXISTS season;
ALTER TABLE observations ADD COLUMN season INT;

UPDATE observations 
SET season = 1
WHERE to_char(measurement_time::date, 'MM-dd') < '03-21'
OR to_char(measurement_time::date, 'MM-dd') > '12-21';
UPDATE observations 
SET season = 2
WHERE to_char(measurement_time::date, 'MM-dd') BETWEEN '03-21' AND '06-21';
UPDATE observations 
SET season = 3
WHERE to_char(measurement_time::date, 'MM-dd') BETWEEN '06-22' AND '09-22';
UPDATE observations
SET season = 4
WHERE to_char(measurement_time::date, 'MM-dd') BETWEEN '09-23' AND '12-21';

-- ===================================

ALTER TABLE observations DROP COLUMN IF EXISTS month;
ALTER TABLE observations ADD COLUMN month INT;
UPDATE observations
SET month = EXTRACT(MONTH FROM measurement_time);

ALTER TABLE observations DROP COLUMN IF EXISTS month_scaled;
ALTER TABLE observations ADD COLUMN month_scaled FLOAT;
UPDATE observations
SET month_scaled = COS(2 * PI() * month / 12.0);

-- ===================================

ALTER TABLE observations DROP COLUMN IF EXISTS day_of_week;
ALTER TABLE observations ADD COLUMN day_of_week INTEGER;
UPDATE observations
SET day_of_week = EXTRACT(DOW FROM measurement_time);

ALTER TABLE observations DROP COLUMN IF EXISTS day_of_week_scaled;
ALTER TABLE observations ADD COLUMN day_of_week_scaled FLOAT;
UPDATE observations
SET day_of_week_scaled = COS(2 * PI() * day_of_week / 6.0);

-- ===================================

-- Transform the date to a continuous value

ALTER TABLE observations DROP COLUMN IF EXISTS day_of_year;
ALTER TABLE observations ADD COLUMN day_of_year INTEGER;
UPDATE observations 
SET day_of_year = EXTRACT(DOY FROM measurement_time);

ALTER TABLE observations DROP COLUMN IF EXISTS day_of_year_scaled;
ALTER TABLE observations ADD COLUMN day_of_year_scaled FLOAT;
UPDATE observations 
SET day_of_year_scaled = COS(2 * PI() * day_of_year / 365.0);

-- Transform the hour of day to a continuous value
-- Transform the hour of day to a continuous value

ALTER TABLE observations DROP COLUMN IF EXISTS hour_of_day;
ALTER TABLE observations ADD COLUMN hour_of_day INTEGER;
UPDATE observations 
SET hour_of_day = EXTRACT(HOUR FROM measurement_time);

ALTER TABLE observations DROP COLUMN IF EXISTS hour_of_day_scaled;
ALTER TABLE observations ADD COLUMN hour_of_day_scaled FLOAT;
UPDATE observations 
SET hour_of_day_scaled = -COS(2 * PI() * hour_of_day / 24.0);

-- ===================================

ALTER TABLE observations DROP COLUMN IF EXISTS period_of_day;
ALTER TABLE observations ADD COLUMN period_of_day INT;

UPDATE observations 
SET period_of_day = 1
WHERE hour_of_day BETWEEN 0 AND 5;

UPDATE observations 
SET period_of_day = 2
WHERE hour_of_day BETWEEN 6 AND 11;

UPDATE observations 
SET period_of_day = 3
WHERE hour_of_day BETWEEN 12 AND 17;

UPDATE observations
SET period_of_day = 4
WHERE hour_of_day BETWEEN 18 AND 23;

-- ===================================

--------------------------------
COPY observations TO '/tmp/observations_raw.csv' WITH CSV HEADER DELIMITER ';';
COPY meteo_observations TO '/tmp/meteo_observations_raw.csv' WITH CSV HEADER DELIMITER ';';
--------------------------------

/*
Some variables have well defined min and max values
We can remove any observation being outside the allowed 
range
*/

UPDATE observations SET pm2_5 = NULL WHERE pm2_5 < 0;
UPDATE observations SET pm10 = NULL WHERE pm10 < 0;

UPDATE meteo_observations SET humidity = NULL WHERE humidity < 0 OR humidity > 100;
UPDATE meteo_observations SET pressure = NULL WHERE pressure < 970 OR pressure > 1050;
UPDATE meteo_observations SET precip_rate = NULL WHERE precip_rate < 0;
UPDATE meteo_observations SET temperature = NULL WHERE temperature < -25 OR temperature > 40;
UPDATE meteo_observations SET wind_dir_deg = NULL WHERE wind_dir_deg < 0 OR wind_dir_deg > 360;
UPDATE meteo_observations SET wind_speed = NULL WHERE wind_speed < 0;

/*
IQR is the difference between the 3rd and 1st quartile
outliers are assumed to be those observations which are
< Q1 - 1.5 * IQR
OR
> Q3 + 1.5 * IQR
Quantiles are calculated for each month (although observations may
have been taken during different years and at different stations)
e.g. Jan 2014, Jan 2015, Jan 2016, Jan 2017
*/

DROP FUNCTION IF EXISTS delete_outliers_based_on_iqr(TEXT, TEXT[]);
CREATE OR REPLACE FUNCTION delete_outliers_based_on_iqr(table_name TEXT, column_names TEXT[])
RETURNS VOID AS $$
DECLARE
	column_name TEXT;
	query_template TEXT;
	query TEXT;
BEGIN
	query_template := '
		DELETE FROM %1$s WHERE id IN (
			SELECT id
			FROM %1$s AS observations_table
			JOIN (
				SELECT 	stats.measurement_month, 
					stats.q1 - 1.5 * stats.iqr AS min,
					stats.q3 + 1.5 * stats.iqr AS max
				FROM (
					SELECT quartiles.measurement_month, quartiles.q1, quartiles.q3, quartiles.q3 - quartiles.q1 AS iqr 
					FROM (
						SELECT EXTRACT(MONTH FROM measurement_time) AS measurement_month,
							percentile_cont(0.25) WITHIN GROUP (ORDER BY %2$s ASC) AS q1,
							percentile_cont(0.75) WITHIN GROUP (ORDER BY %2$s ASC) AS q3
						FROM %1$s
						GROUP BY 1
						ORDER BY 1
					) AS quartiles
				) AS stats
			) AS thresholds ON thresholds.measurement_month = EXTRACT(MONTH FROM observations_table.measurement_time)
			WHERE %2$s < thresholds.min OR thresholds.max < %2$s
		)
	';
	FOREACH column_name IN ARRAY column_names
	LOOP
		RAISE NOTICE 'DROPPING OUTLIERS FOR %', column_name;
		query := format(query_template, table_name, column_name);
		RAISE NOTICE 'QUERY: %', query;
		EXECUTE query;
	END LOOP;
END;
$$  LANGUAGE plpgsql;

SELECT delete_outliers_based_on_iqr('observations', ARRAY['pm2_5', 'pm10']);

-- Removing outliers based on the IQR doesn't seem to be a good idea for variables
-- that the IQR is close to 0, e.g. precipitation rate and total precipitation, since
-- the large majority of observations is close to 0. Because of that the above function
-- leaves pretty much only observations with precip_rate equal to 0.
-- Additionally it has been assumed that using this method for variables with well defined 
-- boundaries is redundant and can potentially lead to removing valid values
-- (for example relative humisity which takes values between 0 and 100, or wind direction expressed in degrees)
SELECT delete_outliers_based_on_iqr('meteo_observations', ARRAY['temperature', 'pressure', 'solradiation']);

--------------------------------
COPY observations TO '/tmp/observations_no_outliers.csv' WITH CSV HEADER DELIMITER ';';
COPY meteo_observations TO '/tmp/meteo_observations_no_outliers.csv' WITH CSV HEADER DELIMITER ';';
--------------------------------

CREATE INDEX ON meteo_observations(measurement_time);
CREATE INDEX ON meteo_observations(station_id);
CREATE INDEX ON meteo_observations(temperature) WHERE temperature IS NOT NULL;
CREATE INDEX ON meteo_observations(pressure) WHERE pressure IS NOT NULL;
CREATE INDEX ON meteo_observations(humidity) WHERE humidity IS NOT NULL;
CREATE INDEX ON meteo_observations(wind_speed) WHERE wind_speed IS NOT NULL;
CREATE INDEX ON meteo_observations(wind_dir_deg) WHERE wind_dir_deg IS NOT NULL;
CREATE INDEX ON meteo_observations(precip_rate) WHERE precip_rate IS NOT NULL;
CREATE INDEX ON meteo_observations(solradiation) WHERE solradiation IS NOT NULL;
CLUSTER meteo_observations USING "meteo_observations_measurement_time_idx";

CREATE INDEX ON observations(temperature) WHERE temperature IS NULL;
CREATE INDEX ON observations(pressure) WHERE pressure IS NULL;
CREATE INDEX ON observations(humidity) WHERE humidity IS NULL;
CREATE INDEX ON observations(wind_speed) WHERE wind_speed IS NULL;
CREATE INDEX ON observations(wind_dir_deg) WHERE wind_dir_deg IS NULL;
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

DROP TABLE IF EXISTS air_quality_meteo_distance;
CREATE TABLE air_quality_meteo_distance AS (
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

ALTER TABLE air_quality_meteo_distance ADD PRIMARY KEY (id);
CREATE INDEX ON air_quality_meteo_distance(station_id1);
CREATE INDEX ON air_quality_meteo_distance(station_id2);
CLUSTER air_quality_meteo_distance USING "air_quality_meteo_distance_station_id1_idx";

/*
Similarly, calculate the distance between
the stations measuring air quality.
*/

DROP TABLE IF EXISTS air_quality_cross_distance;
CREATE TABLE air_quality_cross_distance AS (
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

ALTER TABLE air_quality_cross_distance ADD PRIMARY KEY (id);
CREATE INDEX ON air_quality_cross_distance(station_id1);
CREATE INDEX ON air_quality_cross_distance(station_id2);
CLUSTER air_quality_cross_distance USING "air_quality_cross_distance_station_id1_idx";

/*
A function filling missing values by 
copying them from the nearest meteo station
containing the desired value
*/

DROP FUNCTION IF EXISTS fill_missing(TEXT, TEXT, TEXT, TEXT[]);
CREATE OR REPLACE FUNCTION fill_missing(target_table_name TEXT, source_table_name TEXT, distance_table_name TEXT, column_names TEXT[])
RETURNS VOID AS $$
DECLARE
	air_quality_cols text[];
	column_name text;
	query text;
	query_template text;
BEGIN
	/*
	The following query is based on the assumption that
	the rows in the distance tables are sorted ascendingly
	by the distance between stations
	parameters: 
	%1$s - target table,
	%2$s - source table,
	%3$s - distance table,
	%4$s - column name
	*/
	query_template := '
		UPDATE %1$s AS obs
		SET %4$s = nearest.%4$s
		FROM (
		    SELECT dist_rows.station_id, dist_rows.measurement_time, nearest_other.%4$s 
		    FROM (
		    SELECT obs.measurement_time, obs.station_id, MIN(dist.id) AS row_id
		    FROM %1$s as obs
		    JOIN %3$s as dist ON dist.station_id1 = obs.station_id
		    JOIN %2$s as other ON other.station_id = dist.station_id2 AND other.measurement_time = obs.measurement_time
		    WHERE obs.%4$s IS NULL
		    AND other.%4$s IS NOT NULL
		    GROUP BY obs.station_id, obs.measurement_time
		    ) AS dist_rows
		    JOIN %3$s AS dist ON dist.id = dist_rows.row_id
		    JOIN %2$s AS nearest_other ON nearest_other.station_id = dist.station_id2 AND nearest_other.measurement_time = dist_rows.measurement_time
		) AS nearest
		WHERE nearest.station_id = obs.station_id
		AND nearest.measurement_time = obs.measurement_time
	';
	
	FOREACH column_name IN ARRAY column_names
	LOOP
		query := format(query_template, target_table_name, source_table_name, distance_table_name, column_name);
		RAISE NOTICE 'Filling missing % values', column_name;
		RAISE NOTICE '%', query;
		EXECUTE query;
	END LOOP;
END;
$$  LANGUAGE plpgsql;

SELECT fill_missing('observations', 'observations', 'air_quality_cross_distance', ARRAY['pm2_5', 'pm10']);
SELECT fill_missing('observations', 'meteo_observations', 'air_quality_meteo_distance', ARRAY['temperature', 'humidity', 'pressure', 'wind_speed', 'wind_dir_deg', 'precip_rate', 'solradiation']);


DROP FUNCTION IF EXISTS fill_missing_from_station(TEXT, TEXT, TEXT, TEXT[]);
CREATE OR REPLACE FUNCTION fill_missing_from_station(target_table_name TEXT, source_table_name TEXT, station_id TEXT, column_names TEXT[])
RETURNS VOID AS $$
DECLARE
	air_quality_cols text[];
	column_name text;
	query text;
	query_template text;
BEGIN
	/*
	The following query is based on the assumption that
	the rows in the distance tables are sorted ascendingly
	by the distance between stations
	parameters: 
	%1$s - target table,
	%2$s - source table,
	%4$s - column name
	%5%s - source station id
	*/
	query_template := '
		UPDATE %1$s AS obs
		SET %4$s = source_station.%4$s
		FROM (
		    SELECT measurement_time, %4$s FROM %2$s
		    WHERE %4$s IS NOT NULL
		) AS source_station
		WHERE obs.%4$s IS NULL
		AND source_station.measurement_time = obs.measurement_time
	';
	
	FOREACH column_name IN ARRAY column_names
	LOOP
		query := format(query_template, target_table_name, source_table_name, station_id, column_name);
		 
		RAISE NOTICE 'Filling missing % values from station: %', column_name, station_id;
		RAISE NOTICE '%', query;
		EXECUTE query;
	END LOOP;
END;
$$  LANGUAGE plpgsql;


--------------------------------
COPY observations TO '/tmp/observations.csv' WITH CSV HEADER DELIMITER ';';
COPY meteo_observations TO '/tmp/meteo_observations.csv' WITH CSV HEADER DELIMITER ';';
--------------------------------

DROP INDEX "observations_temperature_idx";
DROP INDEX "observations_pressure_idx";
DROP INDEX "observations_humidity_idx";
DROP INDEX "observations_wind_speed_idx";
DROP INDEX "observations_wind_dir_deg_idx";
DROP INDEX "observations_precip_rate_idx";
DROP INDEX "observations_solradiation_idx";