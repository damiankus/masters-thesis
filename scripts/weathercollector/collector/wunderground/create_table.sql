CREATE DATABASE dakus;
USE dakus;
DROP TABLE services;
CREATE TABLE services (
	ID int NOT NULL AUTO_INCREMENT,
    NAME char(20) NOT NULL,
    PRIMARY KEY(ID)
);
    
INSERT INTO services (NAME) VALUES('WUNDERGROUND');
SELECT * FROM services;


DROP TABLE IF EXISTS observations;
CREATE TABLE observations (
	ID SERIAL NOT NULL,
	observation_location_city CHAR(36),
	observation_location_latitude NUMERIC(9, 6),
	observation_location_longitude NUMERIC(9, 6),
	observation_location_elevation CHAR(10),
    observation_time_rfc822 CHAR(36),
	observation_epoch NUMERIC(11),
	local_time_rfc822 CHAR(36),
	local_epoch NUMERIC(11),
	weather CHAR(20),
	temp_c NUMERIC(3, 1),
	relative_humidity CHAR(5),
	wind_string CHAR(36),
	wind_dir CHAR(20),
	wind_degrees NUMERIC(6, 2),
	wind_kph NUMERIC(5, 2),
	wind_gust_kph NUMERIC(5, 2),
	pressure_mb NUMERIC(6, 2),
	pressure_in NUMERIC(5, 2),
	dewpoint_c NUMERIC(3, 1),
	heat_index_c CHAR(20),
	windchill_c CHAR(5),
	feelslike_c CHAR(5),
	visibility_km CHAR(5),
	solarradiation CHAR(5),
	UV CHAR(5),
	precip_1hr_metric CHAR(5),
	precip_today_metric CHAR(5),
    PRIMARY KEY(ID)
);
ALTER TABLE observations CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;


SELECT * FROM observations