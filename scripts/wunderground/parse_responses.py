#!/usr/bin/env python3

import argparse
import glob
import json
import os
import psycopg2
from utils import exec_stat, save_in_db


api_to_db_field = {
    'tempm': 'temperature',
    'hum': 'humidity',
    'pressurem': 'pressure ',
    'wspdm': 'wind_speed ',
    'wdird': 'wind_dir_deg ',
    'wdire': 'wind_dir_word',
    'precip_totalm': 'precip_total ',
    'precip_ratem': 'precip_rate ',
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
                        default=os.path.join('responses', '*'))
    args = vars(parser.parse_args())

    global_config = None
    stations = None
    with open('config.json', 'r') as config_file:
        global_config = json.load(config_file)

    connection = None
    try:
        for service_name, config in global_config['services'].items():
            connection = psycopg2.connect(**config['db-connection'])

            # Delete the old station table
            print('Deleting the stations table')
            del_stations_stat = 'DROP TABLE IF EXISTS ' \
                + config['stations-table']
            exec_stat(connection, del_stations_stat)

            print('Creating stations table')
            create_stations_stat = """
                CREATE TABLE wunderground_stations (
                    id CHAR(20) PRIMARY KEY,
                    type CHAR(5),
                    city CHAR(20),
                    neighborhood CHAR(50),
                    lat NUMERIC(9, 6),
                    lon NUMERIC(9, 6)
                );
            """
            exec_stat(connection, create_stations_stat)

            with open(config['stations-file']) as stations_file:
                print('Saving stations in the DB')
                stations = json.load(stations_file)['stations']
                stat_template = 'INSERT INTO ' + config['stations-table'] \
                    + '({cols}) VALUES({vals})'
                for station in stations:
                    save_in_db(connection, station, stat_template)

        # Parse the responses and save them in the DB
        del_obs_stat = 'DROP TABLE IF EXISTS ' + config['observations-table']
        exec_stat(connection, del_obs_stat)
        create_obs_stat = """
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
        """
        stat_template = 'INSERT INTO ' + config['observations-table'] \
            + '({cols}) VALUES({vals})'

        for dirpath in glob.glob(args['dir']):
            station_id = dirpath.split(os.path.sep)[-1]

            for fpath in glob.glob(os.path.join(dirpath, '*')):
                with open(fpath, 'r') as in_file:
                    history = json.load(in_file)['history']
                    dt = history['utcdate']
                    date = '-'.join([dt['year'], dt['mon'], dt['mday']])

                    for obs in history['observations']:
                        record = map_keys(obs, api_to_db_field)

    finally:
        if connection:
            connection.close()