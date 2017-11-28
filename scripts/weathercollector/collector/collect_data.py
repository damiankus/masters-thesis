#!/usr/bin/env python3


import logging
import sys


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


init_logger()
sys.excepthook = log_all_errors


import json
import mysql.connector as sql
import os.path
import time
import urllib.error
import urllib.parse
import urllib.request


def load_stations(in_path, out_path, city='Krakow'):
    with open(in_path, 'r') as in_file:
        neighbors = json.load(in_file)['location']['nearby_weather_stations']
        common_keys = ['city', 'lat', 'lon']
        airport_keys = common_keys + ['icao']
        pws_keys = common_keys[:] + ['id', 'neighborhood']
        airports = [dict([(key, station[key]) for key in airport_keys])
                    for station in neighbors['airport']['station']
                    if station['city'] == city]
        pwss = [dict([(key, station[key]) for key in pws_keys])
                for station in neighbors['pws']['station']]
        for airport in airports:
            airport['type'] = 'icao'
            airport['id'] = airport.pop('icao')
        for pws in pwss:
            pws['type'] = 'pws'

        with open(out_path, 'w+') as out_file:
            stations = {'stations': airports + pwss}
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


def get(url, schema):
    """
    @type url: string
    @param url: A complete URL to the API endpoint.
    @type schema: dict
    @param schema: A sample response used for finding
        the way to traverse other responses based on
        the structure of nested JSON objects.
    """

    logger.info('Connecting to: {}'.format(url))
    with urllib.request.urlopen(url) as res:
        json_string = str(res.read(), 'utf-8')
        observation = json.loads(json_string)
        observation = traverse_dict(observation, schema)
        if len(observation) == 1:
            _, observation = observation.popitem()
        return flatten_dict(observation)


def apath(rel_path):
    return os.path.join(os.path.dirname(__file__), rel_path)


if __name__ == "__main__":
    logger.debug('=== A NEW SESSION HAS BEEN INITIALIZED ===')

    global_config = None
    stations = None
    with open(apath('config.json'), 'r') as config_file:
        global_config = json.load(config_file)

    # Requests to the Wunderground API
    config = global_config['services']['wunderground']
    if not os.path.isfile(apath(config['stations-file'])):
        print('Parsing a sample response from API')
        stations = load_stations(apath(config['response-file']),
                                 apath(config['stations-file']))

    init_logger(apath(global_config['log-file']))
    logger.debug('=== A NEW SESSION HAS BEEN INITIALIZED ===')
    logger.debug(global_config['log-file'])

    for service_name, config in global_config['services'].items():
        logger.info('Gathering data for {}'.format(service_name))

        with open(apath(config['stations-file'])) as stations_file:
            stations = json.load(stations_file)

        stations = stations['stations']
        endpoint = config['api-endpoint']
        max_calls = config['max-calls']
        retry_period_s = config['retry-period-s'] + 1
        performed_calls = 0
        connection = None
        insert_template = 'INSERT INTO ' + config['table'] \
            + '({cols}) VALUES({vals})'

        try:
            connection = sql.connect(**config['db-connection'])
            for station in stations:
                params = [station[param] for param in config['url-params']]
                observation = get(endpoint.format(*params), config['schema'])
                save_in_db(connection, observation, insert_template)
                performed_calls += 1
                if performed_calls >= max_calls:
                    logger.info(
                        'Waiting [{} s] to prevent max API calls exceedance'
                        .format(retry_period_s))
                    time.sleep(retry_period_s)
                    performed_calls = 0
        except Exception as e:
            logger.error(e)
        finally:
            if connection is not None:
                connection.close()
