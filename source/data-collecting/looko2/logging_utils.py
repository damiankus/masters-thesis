#!/usr/bin/env python3

import logging


def init_logger(name):
    logging.basicConfig(
        format="[%(asctime)-11s][%(levelname)s][%(name)s] : %(message)s")
    logger = logging.getLogger(name)
    logger.setLevel(logging.INFO)
    return logger
