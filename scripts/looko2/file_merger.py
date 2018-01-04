#!/usr/bin/env python3

import os
from logging_utils import init_logger
import argparse

logger = init_logger('file-merger')


class FileMerger:
    def __init__(self, dir_path, target_path='merged.txt'):
        self.dir_path = dir_path
        self.target_path = target_path
        self.ext = self.target_path.split('.')[-1]

    def merge(self):
        with open(self.target_path, 'w') as output_file:
            paths = [os.path.join(self.dir_path, filename)
                     for filename in os.listdir(self.dir_path)
                     if filename.endswith(self.ext)]
            is_first = True
            for filepath in paths:
                if filepath != self.target_path:
                    logger.info('Appending file {}'.format(filepath))
                    with open(filepath, 'r') as input_file:
                        if not is_first:
                            # skip the header line
                            next(input_file)
                        else:
                            is_first = False
                        for line in input_file:
                            output_file.write(line)
        logger.info('Merged file saved under {}'.format(self.target_path))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Merging files into one')
    parser.add_argument('--dir', '-d', help='Path to the directory \
        containing files', required=True)
    parser.add_argument('--out', '-o', help='Path to the target file',
                        required=True)
    args = vars(parser.parse_args())
    merger = FileMerger(args['dir'], args['out'])
    merger.merge()
