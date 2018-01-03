USE dakus1;
DROP TABLE services;
CREATE TABLE services (
	ID int NOT NULL AUTO_INCREMENT,
    NAME char(20) NOT NULL,
    PRIMARY KEY(ID)
);
    
INSERT INTO services (NAME) VALUES('OpenWeatherMap');
SELECT * FROM services;

DROP TABLE IF EXISTS observations;
CREATE TABLE observations (
	ID INTEGER NOT NULL AUTO_INCREMENT,
    wind_speed NUMERIC(5, 2),
    sys_sunset INT(11),
    sys_type INTEGER,
    sys_sunrise INT(11),
    sys_message NUMERIC(6, 4),
    sys_country CHAR(3),
    sys_id INTEGER,
    main_temp_min NUMERIC(4, 2),
    main_humidity NUMERIC(5, 3),
    main_temp_max NUMERIC(4, 2),
    main_pressure NUMERIC(6, 2),
    main_temp NUMERIC(4, 2),
    visibility NUMERIC(6, 2),
    name CHAR(20),
    coord_lon NUMERIC(5, 2),
    coord_lat NUMERIC(5, 2),
    clouds_all INTEGER,
    weather_main CHAR(36),
    weather_description CHAR(36),
    weather_id INTEGER,
    dt INT(11),
    PRIMARY KEY(ID)
);
ALTER TABLE observations CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

SELECT * FROM observations order by dt desc;