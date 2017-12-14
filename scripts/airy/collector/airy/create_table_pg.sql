DROP TABLE observations;
DROP TABLE stations;

CREATE TABLE stations (	
	id INT PRIMARY KEY,
	configuration_isEnabled BOOLEAN,
        configuration_isPublic BOOLEAN,
        configuration_useDefaultPosition BOOLEAN,
        configuration_useLabel BOOLEAN,
        initDate NUMERIC(15),
        location_address CHAR(100),
        location_city CHAR(20),
        location_latitude NUMERIC(9, 6),
        location_longitude NUMERIC(9, 6),
        manufacturer CHAR(20),
        types_1 CHAR(20),
        description CHAR(30),
        label CHAR(50),
        uuid CHAR(20)
);
select * from stations;

CREATE TABLE observations (
	id SERIAL PRIMARY KEY,
	station_id INT REFERENCES stations(id),
	temperature_unit CHAR(5),
	temperature NUMERIC(22, 15), 
	co_unit CHAR(5),
	co NUMERIC(22, 15),
	no2_unit CHAR(5),
	no2 NUMERIC(22, 15), 
	pm1_unit CHAR(5),
	pm1 NUMERIC(22, 15),
	o3_unit CHAR(5),
	o3 NUMERIC(22, 15), 
	so2_unit CHAR(5),
	so2 NUMERIC(22, 15), 
	pm10_unit CHAR(5),
	pm10 NUMERIC(22, 15),
	pm2_5_unit CHAR(5),
	pm2_5 NUMERIC(22, 15),
	pressure_unit CHAR(5),
	pressure NUMERIC(22, 15),	
	humidity_unit CHAR(5),
	humidity NUMERIC(22, 15),
	c6h6_unit CHAR(5),
	c6h6 NUMERIC(22, 15),	
	measurementMillis NUMERIC(15)
);

select * from observations where station_id = 234;

ALTER TABLE observations ADD COLUMN timeReadable TIMESTAMP;
UPDATE observations SET timeReadable = 	to_timestamp(measurementMillis / 1000);

-- DAY OF THE WEEK 0 - Sunday, 6 - Saturday
ALTER TABLE observations ADD COLUMN dow int;
UPDATE observations SET dow = EXTRACT(DOW FROM timeReadable);

CREATE TEMP TABLE units AS 
(
SELECT DISTINCT 'temperature' AS temperature, temperature_unit,
'co' as co, co_unit,
'o3' as o3, o3_unit,
'no2' as no2, no2_unit,
'so2' as so2, so2_unit,
'pressure' as pressure, pressure_unit,
'humidity' as humidity, humidity_unit,
'pm1' as pm1, pm1_unit,
'pm10' as pm10, pm10_unit,
'pm2_5' as pm2_5, pm2_5_unit,
'c6h6' as c6h6, c6h6_unit
FROM observations
);
drop table units;

WITH tmp_pol (type, unit) AS
(
SELECT temperature, temperature_unit FROM units
UNION ALL
SELECT co, co_unit FROM units
UNION ALL
SELECT o3, o3_unit FROM units
UNION ALL
SELECT no2, no2_unit FROM units
UNION ALL
SELECT so2, so2_unit FROM units
UNION ALL
SELECT pressure, pressure_unit FROM units
UNION ALL
SELECT humidity, humidity_unit FROM units
UNION ALL
SELECT pm1, pm1_unit FROM units
UNION ALL
SELECT pm10, pm10_unit FROM units
UNION ALL
SELECT pm2_5, pm2_5_unit FROM units
UNION ALL
SELECT c6h6, c6h6_unit  FROM units
) 
SELECT * INTO type_unit FROM tmp_pol;
