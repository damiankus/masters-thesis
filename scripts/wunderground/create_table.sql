DROP TABLE IF EXISTS wunderground_observations;
DROP TABLE IF EXISTS wunderground_stations;

CREATE TABLE wunderground_stations (
	id CHAR(20) PRIMARY KEY,
	type CHAR(5),
	city CHAR(20),
	neighborhood CHAR(50),
	lat NUMERIC(9, 6),
	lon NUMERIC(9, 6)
);

/*
"observations": [
{
	"tempi": "15.3",
	"precip_totalm": "-2539.7",
	"solarradiation": "",
	"wgustm": "-1607.4",
	"heatindexi": "-9999",
	"heatindexm": "-9999",
	"UV": "",
	"wdird": "-9999",
	"wdire": "North",
	"hum": "67",
	"wgusti": "-999.0",
	"precip_totali": "-99.99",
	"utcdate": {
		"mon": "01",
		"mday": "08",
		"year": "2017",
		"tzname": "UTC",
		"min": "08",
		"pretty": "11:08 PM GMT on January 08, 2017",
		"hour": "23"
	},
	"precip_ratei": "-99.99",
	"pressurei": "30.24",
	"dewptm": "-14.3",
	"dewpti": "6.2",
	"softwaretype": "Netatmo",
	"wspdi": "-999.9",
	"wspdm": "-1608.8",
	"pressurem": "1023.9",
	"precip_ratem": "-2539.7",
	"windchilli": "-999",
	"date": {
		"mon": "01",
		"mday": "09",
		"year": "2017",
		"tzname": "Europe/Warsaw",
		"min": "08",
		"pretty": "12:08 AM CET on January 09, 2017",
		"hour": "00"
	},
	"windchillm": "-999",
	"tempm": "-9.3"
}
}
*/

CREATE TABLE wunderground_observations (
	ID SERIAL PRIMARY KEY,
	station_id CHAR(20) REFERENCES wunderground_stations(id),
	timestamp TIMESTAMP,
	temperature NUMERIC(5, 3), -- tempm
	humidity NUMERIC(6, 3), -- hum
	pressure NUMERIC(7, 3), -- pressurem
	wind_speed NUMERIC(7, 3), -- wspdm
	wind_dir_deg NUMERIC(6, 3), -- wdird
	wind_dir_word CHAR(25), -- wdire
	precip_total NUMERIC(7, 3), -- precip_totalm
	precip_rate NUMERIC(7, 3), -- precip_ratem
	solradiation NUMERIC(6, 3) -- solarradiation
);

SELECT * FROM wunderground_stations;
SELECT * FROM wunderground_observations WHERE station_id = 'IKRAKW81' LIMIT 1000;
SELECT COUNT(*) FROM wunderground_observations WHERE wind_speed IS NOT NULL;
SELECT COUNT(*) FROM wunderground_observations WHERE temperature IS NOT NULL;
SELECT COUNT(*) FROM wunderground_observations WHERE pressure IS NOT NULL;