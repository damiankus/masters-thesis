#!/usr/bin/env python3

from sqlalchemy import CHAR, NUMERIC, INTEGER, TIMESTAMP, \
    Column, ForeignKey, Sequence
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship

SqlBase = declarative_base()


class Station(SqlBase):
    __tablename__ = 'wunderground_stations'

    id = Column(CHAR(20), primary_key=True)
    type = Column(CHAR(5))
    city = Column(CHAR(20))
    neighborhood = Column(CHAR(50))
    lat = Column(NUMERIC(9, 6))
    lon = Column(NUMERIC(9, 6))


class Observation(SqlBase):
    __tablename__ = 'wunderground_observations'

    id = Column(INTEGER,
                Sequence('wunderground_observations_pk'),
                primary_key=True)
    station_id = Column(CHAR(20), ForeignKey('wunderground_stations.id'))
    station = relationship(Station)
    timestamp = Column(TIMESTAMP)
    temperature = Column(NUMERIC(5, 3))
    humidity = Column(NUMERIC(6, 3))
    pressure = Column(NUMERIC(7, 3))
    wind_speed = Column(NUMERIC(7, 3))
    wind_dir_deg = Column(NUMERIC(6, 3))
    wind_dir_word = Column(CHAR(25))
    precip_total = Column(NUMERIC(7, 3))
    precip_rate = Column(NUMERIC(7, 3))
    solradiation = Column(NUMERIC(8, 3))
