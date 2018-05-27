DROP TABLE IF EXISTS agh_meteo_observations;
CREATE TABLE agh_meteo_observations (
    id SERIAL PRIMARY KEY,
    time TIMESTAMP,
    sm_hour_avg NUMERIC(7, 2),
    dm_hour_avg NUMERIC(7, 2),
    ta_hour_avg NUMERIC(7, 2),
    pa_hour_avg NUMERIC(7, 2),
    ua_hour_avg NUMERIC(7, 2),
    rc_hour_avg NUMERIC(7, 2),
    ri_hour_avg NUMERIC(7, 2)
);

-- Files downloaded from http://meteo.ftj.agh.edu.pl/meteo/archiwalneDaneMeteo have extra trailing delimiters which must be removed!
-- You can use the remove_trailing_char.py script from this directory
\copy agh_meteo_observations (time,sm_hour_avg,dm_hour_avg,ta_hour_avg,pa_hour_avg,ua_hour_avg,rc_hour_avg,ri_hour_avg) FROM 'agh_meteo_2014.csv' WITH HEADER DELIMITER ',' CSV;
\copy agh_meteo_observations (time,sm_hour_avg,dm_hour_avg,ta_hour_avg,pa_hour_avg,ua_hour_avg,rc_hour_avg,ri_hour_avg) FROM 'agh_meteo_2015.csv' WITH HEADER DELIMITER ',' CSV;
\copy agh_meteo_observations (time,sm_hour_avg,dm_hour_avg,ta_hour_avg,pa_hour_avg,ua_hour_avg,rc_hour_avg,ri_hour_avg) FROM 'agh_meteo_2016.csv' WITH HEADER DELIMITER ',' CSV;
\copy agh_meteo_observations (time,sm_hour_avg,dm_hour_avg,ta_hour_avg,pa_hour_avg,ua_hour_avg,rc_hour_avg,ri_hour_avg) FROM 'agh_meteo_2017.csv' WITH HEADER DELIMITER ',' CSV;
\copy agh_meteo_observations (time,sm_hour_avg,dm_hour_avg,ta_hour_avg,pa_hour_avg,ua_hour_avg,rc_hour_avg,ri_hour_avg) FROM 'agh_meteo_2018.csv' WITH HEADER DELIMITER ',' CSV;
