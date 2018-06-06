#!/usr/bin/env python3

import logging


def init_logger(logger, log_filename='monitoring-agh-collector.log'):
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


def logging_hook(logger):
    def log_all_errors(type, value, tb):
        logger.error("Exception: {0}".format(str(value)))
    return log_all_errors
