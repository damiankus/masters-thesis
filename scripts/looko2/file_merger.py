#!/usr/bin/env python3

import os
from logging_utils import init_logger

logger = init_logger('CSVDownloader')


class FileMerger:
    def __init__(self, dirname, target_path='merged.txt'):
        self.dirname = dirname
        self.target_path = target_path

    def merge(self):
        with open(self.target_path, 'w') as output_file:
            paths = [os.path.join(self.dirname, filename)
                     for filename in os.listdir(self.dirname)]
            for filepath in paths:
                logger.info('Appending file {}'.format(filepath))
                with open(filepath, 'r') as input_file:
                    for line in input_file:
                        output_file.write(line)
        logger.info('Merged file saved under {}'.format(self.target_path))
