-- 2016-03-07	8	7	3	2016	18FE34CF51A3	43.2105	55.9474	63.9474	KRAKOW_MYDLNIKI
-- (date, hour, day, month, year, station_code, pm1, pm2_5, pm10, station_name)

DROP TABLE IF EXISTS looko2_observations;
CREATE TABLE looko2_observations (
    id SERIAL PRIMARY KEY,
    date DATE,
    hour NUMERIC(2),
    day NUMERIC(2),
    month NUMERIC(2),
    year NUMERIC(4),
    station_id CHAR(15),
    pm1 NUMERIC(8, 4),
    pm2_5 NUMERIC(8, 4),
    pm10 NUMERIC(8, 4),
    station_name CHAR(50)
);
-- run this command in the psql shell (running COPY in script results in access denial)
-- psql -d pollution
\copy looko2_observations (date, hour, day, month, year, station_id, pm1, pm2_5, pm10, station_name) FROM 'looko2.csv' WITH HEADER DELIMITER ',' CSV;


DROP TABLE IF EXISTS looko2_stations;
SELECT station_id as id, station_name,
	CAST(NULL AS NUMERIC) AS latitude,
	CAST(NULL AS NUMERIC) AS longitude
INTO looko2_stations
FROM
(
	SELECT station_id, MAX(station_name) as station_name, MAX(LOWER(station_name)) AS name
	FROM looko2_observations
	GROUP BY station_id
	ORDER BY station_id
) AS krk_stations
WHERE name LIKE '%krakow%'
OR name LIKE '%kraków%'
OR name LIKE '%krk%'
OR name LIKE '%ruczaj%'
OR name LIKE '%podhalanska%'
OR name ='przedszkolegalaktyka3'
OR name = 'smogoweinfotest'
OR name ='LOOKO2_AC117'
OR name ='poddebowiec'
OR name ='ww_piaski_v3_atmo'
ORDER BY station_id;

DELETE FROM looko2_observations
WHERE station_name NOT IN
(
	SELECT station_name FROM looko2_stations
);

select * from looko2_stations;
select * from looko2_observations limit 1000;

-- Now run the update_geo_coordinates.py script to update the geographical coordinates of stations!
