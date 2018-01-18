#!/usr/bin/env python3

import json
import logging
import os.path
import psycopg2
import sys
import time
import datetime
from api_utils import get, get_token, revoke_token
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


def transform_observation(observation):
    res = {}
    res['measurementMillis'] = observation['measurementTime']
    for d in observation['details']:
        res[d['type']] = d['value']
        res[d['type'] + '_' + 'unit'] = d['unit']
    res['station_id'] = observation['station_id']
    return res


def save_in_db(connection, d, stat_template, cols=[]):
    if len(cols) == 0:
        cols = list(d.keys())
    vals = [d[col] for col in cols]
    statement = stat_template.format(
        cols=','.join(cols), vals=','.join(['%s'] * len(cols)))
    cursor = connection.cursor()
    try:
        cursor.execute(statement, vals)
        connection.commit()
    except Exception as e:
        connection.rollback()
        logger.error(str(e))


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

        token, refresh_token = get_token(config['auth-endpoint'])
        endpoint = config['api-endpoint']
        max_calls = config['max-calls']
        retry_period_s = config['retry-period-s'] + 1
        performed_calls = 0
        connection = None

        try:
            connection = psycopg2.connect(**config['db-connection'])
            if should_save_stations:
                for station in stations:
                    template = 'INSERT INTO monitoring_agh_stations({cols}) VALUES({vals})'
                    save_in_db(connection, station, template)
                    logger.debug('Station [{}] has been saved in the DB'
                                 .format(station['id']))

            for station in stations:
                token = revoke_token(
                    config['auth-refresh-endpoint'], refresh_token)
                insert_template = 'INSERT INTO ' + config['table'] \
                    + '({cols}) VALUES({vals})'

                date_step = (config['date-to'] - config['date-since']) \
                    // config['date-steps']
                for start_date in range(config['date-since'],
                                        config['date-to'],
                                        date_step):
                    params = [station[param] for param in config['url-params']]
                    params.extend([start_date, start_date + date_step])
                    url = endpoint.format(*params)
                    logger.debug('Connecting to {}'.format(url))
                    for observation in get(url, config['schema'], token):
                        observation['station_id'] = station['id']
                        save_in_db(connection, transform_observation(
                            observation), insert_template)

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
