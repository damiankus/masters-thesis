#!/usr/bin/env python3

from sqlalchemy import INTEGER, CHAR, TIMESTAMP, NUMERIC, \
    Column, ForeignKey, Sequence
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship

SqlBase = declarative_base()


class Station(SqlBase):
    __tablename__ = 'gios_stations'

    id = Column(CHAR(20), primary_key=True)
    address = Column(CHAR(100))
    city = Column(CHAR(20))
    latitude = Column(NUMERIC(9, 6))
    longitude = Column(NUMERIC(9, 6))
    manufacturer = Column(CHAR(20))
    source = Column(CHAR(10))

    # UUID is assumed to be equal to the original
    # ID provided by the source of data
    uuid = Column(CHAR(20))

    def __repr__(self):
        print(vars(self))
        return 'Station[{id}]({address}, {latitude}, {longitude})' \
               .format(**vars(self))


class Observation(SqlBase):
    __tablename__ = 'gios_observations'

    id = Column(INTEGER,
                Sequence('gios_observations_pk'),
                primary_key=True)
    station_id = Column(CHAR(20), ForeignKey('gios_stations.id'))
    station = relationship(Station)
    timestamp = Column(TIMESTAMP)
    pm2_5 = Column(NUMERIC(precision=9, scale=5))
    pm10 = Column(NUMERIC(precision=9, scale=5))

    def __init__(self, **kwargs):
        super(Observation, self).__init__(**kwargs)
        if 'pm2_5' not in kwargs:
            self.pm2_5 = None
        if 'pm10' not in kwargs:
            self.pm10 = None

    def __repr__(self):
        return 'Observation({station_id}, {timestamp}, {pm2_5}, {pm10})' \
               .format(**vars(self))
