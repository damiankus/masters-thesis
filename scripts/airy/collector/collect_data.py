#!/usr/bin/env python3

import json
import logging
import os.path
import psycopg2
import sys
import time
from api_utils import get, get_token
from dict_utils import flatten_dict
from logging_utils import init_logger, logging_hook


# Setup logging
logger = logging.getLogger('airy-collector')
logger.setLevel(logging.DEBUG)
init_logger(logger)
# sys.excepthook = logging_hook(logger)


def load_stations(in_path, out_path, city='Kraków'):
    with open(in_path, 'r') as in_file:
        stations = [flatten_dict(s) for s in json.load(in_file)
                    if s['location']['city'] == city]
        with open(out_path, 'w+', encoding='utf-8') as out_file:
            json.dump(stations, out_file, indent=4)
            logger.info('List of stations saved in: [{}]'.format(out_path))
            return stations


def save_in_db(connection, d, stat_template, cols=[]):
    if len(cols) == 0:
        cols = list(d.keys())
    vals = [d[col] for col in cols]
    statement = stat_template.format(
        cols=','.join(cols), vals=','.join(['%s'] * len(cols)))
    cursor = connection.cursor()
    cursor.execute(statement, vals)
    connection.commit()


def apath(rel_path):
    return os.path.join(os.path.dirname(__file__), rel_path)


if __name__ == "__main__":
    logger.debug('=== A NEW SESSION HAS BEEN INITIALIZED ===')
    global_config = None
    stations = []

    with open(apath('config.json'), 'r') as config_file:
        global_config = json.load(config_file)

    config = global_config['services']['airy']
    should_save_stations = False
    if not os.path.isfile(apath(config['stations'])):
        should_save_stations = True
        stations = load_stations(apath(config['stations-raw']),
                                 apath(config['stations']))

    for service_name, config in global_config['services'].items():
        logger.info('Gathering data for {}'.format(service_name))

        with open(apath(config['stations'])) as stations_file:
            stations = json.load(stations_file)

        token, _ = get_token(config['auth-endpoint'])
        endpoint = config['api-endpoint']
        max_calls = config['max-calls']
        retry_period_s = config['retry-period-s'] + 1
        performed_calls = 0
        connection = None
        date_since = config['date-since']
        date_to = config['date-to']
        date_step = config['date-step']
        insert_template = 'INSERT INTO ' + config['table'] \
            + '({cols}) VALUES({vals})'
        try:
            connection = psycopg2.connect(**config['db-connection'])
            if should_save_stations:
                for station in stations:
                    template = 'INSERT INTO stations({cols}) VALUES({vals})'
                    save_in_db(connection, station, template)
                    logger.debug('Station [{}] has been saved in the DB'
                                 .format(station['id']))

            for station in stations:
                params = [station[param] for param in config['url-params']]
                url = endpoint.format(*params)
                print(url)
                for observation in get(url, config['schema'], token):
                    save_in_db(connection, observation, insert_template)

                performed_calls += 1
                if performed_calls >= max_calls:
                    logger.info(
                        'Waiting [{} s] to prevent max API calls exceedance'
                        .format(retry_period_s))
                    time.sleep(retry_period_s)
                    performed_calls = 0

        # except Exception as e:
        #     logger.error(str(e))
        finally:
            if connection is not None:
                connection.close()
