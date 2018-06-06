#!/usr/bin/env python3

import argparse
import glob
import json
import os

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Parsing Wunderground \
        history API responses')
    parser.add_argument('--dir', '-d', help='Path to directory containing \
        the responses grouped in subdirectories named after the station IDs',
                        default=os.path.join('responses', '*'))
    args = vars(parser.parse_args())

    global_config = None
    stations = None
    with open('config.json', 'r') as config_file:
        global_config = json.load(config_file)

    for service_name, config in global_config['services'].items():
        for dirpath in glob.glob(os.path.join(args['dir'], '*')):
            station_id = dirpath.split(os.path.sep)[-1]
            print(station_id)
            for fpath in glob.glob(os.path.join(dirpath, '*')):
                with open(fpath, 'r') as in_file:
                    if len(json.load(in_file)['history']['observations']) == 0:
                        print('Deleting file with no observations {}'
                              .format(fpath))
                        os.remove(fpath)
