DROP TABLE IF EXISTS agh_meteo_observations;
CREATE TABLE agh_meteo_observations (
    id SERIAL PRIMARY KEY,
    time TIMESTAMP,
    averageAirPressure NUMERIC(7, 2),
    averageAirTemp NUMERIC(7, 2),
    averageRelativeHumidity NUMERIC(7, 2),
    averageWindDirection NUMERIC(7, 2),
    averageWindSpeed NUMERIC(7, 2),
    rainIntensity NUMERIC(7, 2)
);


-- Files downloaded from http://meteo.ftj.agh.edu.pl/meteo/archiwalneDaneMeteo have extra trailing delimiters which must be removed!
-- You can use the remove_trailing_char.py script from this directory
\copy agh_meteo_observations (time, averageAirPressure, averageAirTemp, averageRelativeHumidity, averageWindDirection, averageWindSpeed, rainIntensity) FROM 'agh_meteo_2012_2018.csv' WITH HEADER DELIMITER ';' CSV;