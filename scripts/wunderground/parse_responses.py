#!/usr/bin/env python3

import argparse
import glob
import json
import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from models import Station, Observation, SqlBase


api_to_db_field = {
    'tempm': 'temperature',
    'hum': 'humidity',
    'pressurem': 'pressure',
    'wspdm': 'wind_speed',
    'wdird': 'wind_dir_deg',
    'wdire': 'wind_dir_word',
    'precip_totalm': 'precip_total',
    'precip_ratem': 'precip_rate',
    'solarradiation': 'solradiation'
}


def map_keys(d, mapping):
    mapped = {}
    for orig_key, mapped_key in mapping.items():
        mapped[mapped_key] = d[orig_key]
    return mapped


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Parsing Wunderground \
        history API responses')
    parser.add_argument('--dir', '-d', help='Path to directory containing \
        the responses grouped in subdirectories named after the station IDs',
                        default=os.path.join('responses'))
    args = vars(parser.parse_args())

    global_config = None
    stations = None
    with open('config.json', 'r') as config_file:
        global_config = json.load(config_file)

    for service_name, config in global_config['services'].items():
        url = 'postgres://{user}:{password}@{host}:5432/{database}'
        engine = create_engine(url.format(**config['db-connection']))
        SqlBase.metadata.bind = engine
        DbSession = sessionmaker()
        DbSession.bind = engine
        session = DbSession()

        # Recreate all the necessary tables
        # Observation.__table__.drop(engine, checkfirst=True)
        # Station.__table__.drop(engine, checkfirst=True)
        # SqlBase.metadata.create_all(engine)

        # with open(config['stations-file']) as stations_file:
        #     stations = [Station(**s) for s in
        #                 json.load(stations_file)['stations']]
        #     session.add_all(stations)
        #     session.commit()

    padding_vals = ['', '-573.3', '-1608.8', '-2539.7', '-3386.0', '-9999']
    timestamp_format = '{year}-{mon}-{mday} {hour}:{min}'
    for dirpath in glob.glob(os.path.join(args['dir'], '*')):
        station_id = dirpath.split(os.path.sep)[-1]
        print('Saving data for station: ' + station_id)

        for fpath in glob.glob(os.path.join(dirpath, '*')):
            with open(fpath, 'r') as in_file:
                observations = []
                append = observations.append
                for o in json.load(in_file)['history']['observations']:
                    time = o['utcdate']
                    time = time['hour'] + ':' + time['min']
                    record = map_keys(o, api_to_db_field)
                    for key, val in record.items():
                        if val in padding_vals:
                            record[key] = None
                    record['station_id'] = station_id
                    record['timestamp'] = timestamp_format.format(
                        **o['utcdate'])
                    append(Observation(**record))
                session.add_all(observations)
                session.commit()
