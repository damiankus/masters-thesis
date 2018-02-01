SELECT s1.id, s2.id, s1.latitude, s2.latitude, s1.longitude, s2.longitude 
FROM stations AS s1
INNER JOIN stations AS s2 
ON s1.uuid = s2.uuid AND s1.id <> s2.id;

/*
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
*/

select * from looko2_observations limit 1;


select COUNT(*) from stations 
where source = 'airly';

select COUNT(*) from stations 
where source = 'looko2';

select COUNT(*) from stations 
where source = 'agh';

select * from monitoring_agh_observations limit 100;