#!/usr/bin/env python3


import logging
import sys


# Logger initiation is performed before imports
# in order to make sure that import errors will
# be caught and logged (helpful while deploying
# to an AWS Elasticbeanstalk instance)

logger = logging.getLogger('weather-data-collector')
logger.setLevel(logging.DEBUG)


def init_logger(log_filename='windguru.log'):
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
# sys.excepthook = log_all_errors


import json
import mysql.connector as sql
import os.path
import time
import urllib.error
import urllib.parse
import urllib.request
import common
from windguru import WindguruCollector


if __name__ == "__main__":
    logger.debug('=== A NEW SESSION HAS BEEN INITIALIZED ===')

    global_config = None
    stations = None
    with open(common.apath('config.json'), 'r') as config_file:
        global_config = json.load(config_file)

    init_logger(common.apath(global_config['log-file']))
    logger.debug(global_config['log-file'])

    for service_name, config in global_config['services'].items():
        logger.info('Gathering data for {}'.format(service_name))
        service = WindguruCollector(config, logger)
        service.collect_data()