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
        types CHAR(20),
        label CHAR(50),
        uuid CHAR(20)
);
select * from stations;

DROP TABLE observations;
CREATE TABLE observations (
	id SERIAL PRIMARY KEY,
	station_id INT REFERENCES stations(id),
	details_1_type CHAR(15),
	details_1_unit CHAR(5),
	details_1_value NUMERIC(22, 15), 
	details_2_type CHAR(15),
	details_2_unit CHAR(5),
	details_2_value NUMERIC(22, 15),
	details_3_type CHAR(15),
	details_3_unit CHAR(5),
	details_3_value NUMERIC(22, 15), 
	details_4_type CHAR(15),
	details_4_unit CHAR(5),
	details_4_value NUMERIC(22, 15),
	details_5_type CHAR(15),
	details_5_unit CHAR(5),
	details_5_value NUMERIC(22, 15), 
	details_6_type CHAR(15),
	details_6_unit CHAR(5),
	details_6_value NUMERIC(22, 15), 
	details_7_type CHAR(15),
	details_7_unit CHAR(5),
	details_7_value NUMERIC(22, 15),
	details_8_type CHAR(15),
	details_8_unit CHAR(5),
	details_8_value NUMERIC(22, 15), 
	measurementTime NUMERIC(15)
);
SELECT MIN(measurementtime), MAX(measurementtime) FROM observations;