USE airy;

DROP TABLE stations;
CREATE TABLE stations (	
	id INT PRIMARY KEY,
	configuration_isEnabled BOOLEAN,
        configuration_isPublic BOOLEAN,
        configuration_useDefaultPosition BOOLEAN,
        configuration_useLabel BOOLEAN,
        initDate NUMERIC(15),
        location_address CHAR(60),
        location_city CHAR(20),
        location_latitude NUMERIC(9, 6),
        location_longitude NUMERIC(9, 6),
        manufacturer CHAR(20),
        types CHAR(20),
        label CHAR(50),
        uuid CHAR(20)
);

select * from stations;

CREATE TABLE observations (

);