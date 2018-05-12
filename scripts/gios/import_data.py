#!/usr/bin/env python3

import argparse
import glob
import json
import logging
import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from models import Station, Observation, SqlBase


def get_component_for_name(component_name):
    if component_name is None or component_name == '':
        raise ValueError('Invalid component name')
    parts = component_name.split('.')
    component = __import__(parts[0])
    for child in parts[1:]:
        component = getattr(component, child)
    return component


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
    parser = argparse.ArgumentParser(description='Parsing Wunderground \
        history API responses')
    parser.add_argument('--dir', '-d', help='Path to directory containing \
        the responses grouped in subdirectories named after the station IDs',
                        default=os.path.join('responses'))
    args = vars(parser.parse_args())
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

    stations = list(map(lambda s: Station(**s), config['stations']))
    session.add_all(stations)
    session.commit()
