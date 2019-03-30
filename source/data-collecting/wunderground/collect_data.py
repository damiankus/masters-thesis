#!/usr/bin/env python3


from datetime import datetime as dt
from datetime import timedelta as tdelta
import json
import logging
import os.path
import psycopg2
import time
import urllib.error
import urllib.parse
import urllib.request


# Logger initiation is performed before imports
# in order to make sure that import errors will
# be caught and logged (helpful while deploying
# to an AWS Elasticbeanstalk instance)

logger = logging.getLogger('weather-data-collector')
logger.setLevel(logging.DEBUG)
log_separator = ''.join(['\n', '=' * 50, '\n' * 5, '=' * 50])


def init_logger(log_filename='/opt/python/log/collector.log'):
    # create file handler which logs even debug messages
    fh = logging.FileHandler(log_filename)
    fh.setLevel(logging.DEBUG)
    # create console handler with a higher log level
    ch = logging.StreamHandler()
    ch.setLevel(logging.ERROR)
    # create formatter and add it to the handlers
    formatter = logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    fh.setFormatter(formatter)
    ch.setFormatter(formatter)
    # add the handlers to the logger
    logger.addHandler(fh)
    logger.addHandler(ch)


def log_all_errors(type, value, tb):
    logger.error("Uncaught exception: {0}".format(str(value)))


def load_stations(in_path, out_path, city='Krakow'):
    with open(in_path, 'r') as in_file:
        neighbors = json.load(in_file)['location']['nearby_weather_stations']
        common_keys = ['city', 'lat', 'lon']
        pws_keys = common_keys[:] + ['id', 'neighborhood']
        station_ids = set({})

        # Historical data API does not seem to work
        # for airports IDs, thus we use query
        # for measurements taken by only personal stations
        personal_stations = []
        for pws in neighbors['pws']['station']:
            if (pws['id'] not in station_ids):
                station_ids.add(pws['id'])
                personal_station = dict([(key, pws[key]) for key in pws_keys])
                personal_station['type'] = 'pws'
                personal_stations.append(personal_station)

        with open(out_path, 'w+') as out_file:
            stations = {'stations': personal_stations}
            json.dump(stations, out_file, indent=4)
            logger.info('Saved list of stations in: [{}]'.format(out_path))
            return stations


def get_and_save(url, out_path):
    logger.debug('Connecting to: {}'.format(url))
    try:
        with urllib.request.urlopen(url) as res:
            json_string = str(res.read(), 'utf-8')
            result = json.loads(json_string)
            if len(result['history']['observations']) > 0:
                with open(out_path, 'w+') as out_file:
                    json.dump(result, out_file, indent=4)
                    logger.debug('Saved under {}'.format(out_path))
    except Exception as e:
        logger.error(e)


def apath(rel_path):
    return os.path.join(os.path.dirname(__file__), rel_path)


if __name__ == '__main__':
    config = None
    stations = None
    with open(apath('config.json'), 'r') as config_file:
        config = json.load(config_file)

    init_logger(apath(config['log-file']))
    logger.debug(config['log-file'])
    DATE_FORMAT = '%Y-%m-%d'

    endpoint = config['api-endpoint']
    api_keys = config['api-keys']
    max_calls = config['max-calls'] * len(api_keys)
    retry_period_s = config['retry-period-s'] + 1
    performed_calls = 0

    connection = None
    try:
        connection = psycopg2.connect(**config['db-connection'])

        def get_stations(config):
            if 'stations-file' in config:
                if os.path.isfile(apath(config['stations-file'])):
                    stations_path = apath(config['stations-file'])
                    with open(stations_path, 'r') as stations_file:
                        return json.load(stations_file)['stations']
                else:
                    logger.debug('Parsing a sample response from API')
                    return load_stations(
                        apath(config['response-file']),
                        apath(config['stations-file'])
                    )['stations']
            else:
                return []

        def get_requested_stations(config):
            stations = get_stations(config)
            id_set = set(config['station-ids']
                         ) if ('station-ids' in config) else set()
            is_valid = (lambda station: station['id'] in id_set) if (
                'station-ids' in config) else (lambda station: True)
            return list(filter(is_valid, stations))

        for station in get_requested_stations(config):
            start_date = dt.strptime(config['date-start'], DATE_FORMAT)
            end_date = dt.strptime(config['date-end'], DATE_FORMAT)
            date = start_date
            const_params = dict([(param, station[param])
                                 for param in config['url-params']])
            url_template = endpoint.format(**const_params)
            target_dir = os.path.join(
                config['target-dir'], station['id'])
            if not os.path.exists(target_dir):
                os.makedirs(target_dir)

            while date != end_date:
                key_idx = performed_calls % len(api_keys)
                var_params = {
                    'date': date.strftime(DATE_FORMAT).replace('-', ''),
                    'api_key': api_keys[key_idx]
                }
                url = url_template.format(**var_params)
                date = date + tdelta(days=1)
                get_and_save(url, os.path.join(
                    target_dir,
                    'observation_' + var_params['date'] + '.json')
                )

                performed_calls += 1
                if performed_calls % max_calls == 0 and \
                        performed_calls >= max_calls:

                    logger.info(
                        'Waiting [{} s] to prevent\
                            max API calls exceedance'
                        .format(retry_period_s))
                    time.sleep(retry_period_s)

            logger.debug(log_separator)
    finally:
        if connection is not None:
            connection.close()
