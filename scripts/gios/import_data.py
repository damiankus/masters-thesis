#!/usr/bin/env python3

import argparse
import json
import logging
import os
from glob import glob
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from models import Station, Observation, SqlBase
from readers import YearlyDataReader, MonthlyDataReader


def setup_logger(fpath='import.log'):
    logger = logging.getLogger('GIOS data importer')
    logger.setLevel(logging.DEBUG)
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')

    fh = logging.FileHandler(fpath)
    fh.setLevel(logging.DEBUG)
    fh.setFormatter(formatter)

    ch = logging.StreamHandler()
    ch.setLevel(logging.ERROR)
    ch.setFormatter(formatter)

    logger.addHandler(fh)
    logger.addHandler(ch)
    return logger


if __name__ == '__main__':
    logger = setup_logger()

    config = None
    with open('config.json', 'r') as config_file:
        config = json.load(config_file)

    url = config['db-connection-template']
    engine = create_engine(url.format(**config['db-connection']))
    SqlBase.metadata.bind = engine
    DbSession = sessionmaker()
    DbSession.bind = engine
    session = DbSession()

    # Recreate all the necessary tables
    Observation.__table__.drop(engine, checkfirst=True)
    Station.__table__.drop(engine, checkfirst=True)
    SqlBase.metadata.create_all(engine)

    for tbl in SqlBase.metadata.sorted_tables:
        logger.debug('Created ' + str(tbl))

    stations = [Station(**s) for s in config['stations']]
    session.add_all(stations)
    session.commit()
    logger.debug('Saved stations')

    station_ids = [s['id'] for s in config['stations']]
    uuids = [s['uuid'] for s in config['stations']]

    # Yearly data
    reader = YearlyDataReader(station_ids, uuids, config['var-names'])
    for fpath in sorted(config['yearly-paths']):
        logger.debug('Reading file {}'.format(fpath))
        observations = reader.read_data(fpath)
        session.add_all(observations)
        session.commit()
        logger.debug('Saved a batch of yearly observations')

    # Monthly data
    for d in config['monthly-dirs']:
        for i, s in enumerate(station_ids):
            reader = MonthlyDataReader(
                [s], [uuids[i]], config['var-names'],
                delimiter=';', quotechar='')
            for fpath in glob(os.path.join(d, s, '*')):
                logger.debug('Reading file {}'.format(fpath))
                observations = reader.read_data(fpath)
                session.add_all(observations)
                session.commit()
                logger.debug('Saved a batch of monthly observations')
