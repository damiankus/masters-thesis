#!/usr/bin/env python3


from datetime import datetime as dt
from datetime import timedelta as tdelta
import json
import logging
import os.path
import psycopg2
import string
import sys
import time
import urllib.error
import urllib.parse
import urllib.request


class InvalidSchemaTypeException(Exception):
    pass


class MissingDictException(Exception):
    pass


# Logger initiation is performed before imports
# in order to make sure that import errors will
# be caught and logged (helpful while deploying
# to an AWS Elasticbeanstalk instance)

logger = logging.getLogger('weather-data-collector')
logger.setLevel(logging.DEBUG)


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
        airport_keys = common_keys + ['icao']
        pws_keys = common_keys[:] + ['id', 'neighborhood']
        station_ids = set({})

        airports = []
        # Historical data API seems to not work
        # for airports IDs

        # for a in neighbors['airport']['station']:
        #     if (a['icao'] not in station_ids) \
        #             and (a['city'] == city):
        #         station_ids.add(a['icao'])
        #         airport = dict([(key, a[key]) for key in airport_keys])
        #         airport['type'] = 'icao'
        #         airport['id'] = airport.pop('icao')
        #         airports.append(airport)

        personal_stations = []
        for pws in neighbors['pws']['station']:
            if (pws['id'] not in station_ids):
                station_ids.add(pws['id'])
                personal_station = dict([(key, pws[key]) for key in pws_keys])
                personal_station['type'] = 'pws'
                personal_stations.append(personal_station)

        with open(out_path, 'w+') as out_file:
            stations = {'stations': airports + personal_stations}
            json.dump(stations, out_file, indent=4)
            logger.info('Saved list of stations in: [{}]'.format(out_path))
            return stations


def traverse_dict(d, schema):
    result = None
    if (type(d) == dict or type(d) == list) and type(d) != type(schema):
        raise InvalidSchemaTypeException
    if isinstance(schema, dict):
        if d is None:
            raise MissingDictException
        result = {}
        for key, item in schema.items():
            result[key] = traverse_dict(d[key], item)
    elif isinstance(schema, list):
        if d is None:
            raise MissingDictException
        result = []
        for idx, item in enumerate(schema):
            result.append(traverse_dict(d[idx], item))
    else:
        result = d
    return result


def flatten_dict(d, key='', sep='_'):
    result = {}
    prefix = key + sep if (key != '') else ''
    if isinstance(d, dict):
        for child_key, item in d.items():
            i = flatten_dict(item, prefix + child_key)
            result.update(i)
    elif isinstance(d, list):
        if len(d) == 1:
            result = flatten_dict(d[0], key)
        else:
            for idx, item in enumerate(d):
                i = flatten_dict(item, prefix + str(idx))
                result.update(i)
    elif key != 'id':
        # Delete ID attributes in order to
        # prevent conflict while iinserting them
        # into a database
        result[key] = d
    return result


def save_in_db(connection, d, stat_template, cols=[]):
    if len(cols) == 0:
        cols = list(d.keys())
    vals = [d[col] for col in cols]
    statement = stat_template.format(
        cols=','.join(cols), vals=','.join(['%s'] * len(cols)))
    cursor = connection.cursor()
    cursor.execute(statement, vals)
    connection.commit()


def get_and_save(url, out_path):
    logger.debug('Connecting to: {}'.format(url))
    try:
        with urllib.request.urlopen(url) as res:
            json_string = str(res.read(), 'utf-8')
            result = json.loads(json_string)
            with open(out_path, 'w+') as out_file:
                json.dump(result, out_file, indent=4)
        logger.debug('Saved under {}'.format(out_path))
    except Exception as e:
        logger.error(e)


def apath(rel_path):
    return os.path.join(os.path.dirname(__file__), rel_path)


if __name__ == '__main__':
    global_config = None
    stations = None
    with open(apath('config.json'), 'r') as config_file:
        global_config = json.load(config_file)

    init_logger(apath(global_config['log-file']))
    logger.debug(global_config['log-file'])
    DATE_FORMAT = '%Y-%m-%d'

    for service_name, config in global_config['services'].items():
        logger.info('Gathering data for {}'.format(service_name))
        endpoint = config['api-endpoint']
        api_keys = config['api-keys']
        max_calls = config['max-calls'] * len(api_keys)
        retry_period_s = config['retry-period-s'] + 1
        performed_calls = 0
        connection = None
        insert_template = 'INSERT INTO ' + config['observations-table'] \
            + '({cols}) VALUES({vals})'

        try:
            connection = psycopg2.connect(**config['db-connection'])
            stations = []
            if not os.path.isfile(apath(config['stations-file'])):
                logger.debug('Parsing a sample response from API')
                stations = load_stations(apath(config['response-file']),
                                         apath(config['stations-file']))['stations']
                logger.debug('Saving stations in the DB [{}]'
                             .format(config['stations-table']))
                stat_template = 'INSERT INTO ' + config['stations-table'] \
                    + '({cols}) VALUES({vals})'
                for station in stations:
                    save_in_db(connection, station, stat_template)
            else:
                with open(apath(config['stations-file'])) as stations_file:
                    stations = json.load(stations_file)['stations']

            for station in stations:
                start_date = dt.strptime(config['date-start'], DATE_FORMAT)
                end_date = dt.strptime(config['date-end'], DATE_FORMAT)
                date = start_date
                const_params = dict([(param, station[param])
                                     for param in config['url-params']])
                url_template = endpoint.format(**const_params)
                target_dir = os.path.join(config['target-dir'], station['id'])
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
                        target_dir, 'observation_' + var_params['date'] + '.json'))

                    performed_calls += 1
                    if performed_calls % max_calls == 0 \
                            and performed_calls >= max_calls:
                        logger.info(
                            'Waiting [{} s] to prevent max API calls exceedance'
                            .format(retry_period_s))
                        time.sleep(retry_period_s)
        finally:
            if connection is not None:
                connection.close()
12045
