#!/usr/bin/env python3

import common
import json
import time
import urllib


class WindguruCollector:
    def __init__(self, config, logger):
        self.config = config
        self.logger = logger
        self.endpoint = config['api-endpoint']
        self.max_calls = config['max-calls']
        self.retry_period_s = config['retry-period-s'] + 1
        self.insert_template = 'INSERT INTO ' + config['table'] \
            + '({cols}) VALUES({vals})'
        with open(common.apath(self.config['stations-file'])) as stations_file:
            self.stations = json.load(stations_file)['stations']

    def collect_data(self):
            performed_calls = 0
            connection = None
            try:
                # connection = sql.connect(**config['db-connection'])
                for station in self.stations:
                    params = [station[param] for param in self.config['url-params']]

                    print(common.post(
                        self.endpoint.format(*params),
                        {
                            'date_from': '2017-10-30',
                            'date_to': '2017-11-30',
                            'step': '1',
                            'pwindspd': '1',
                            'psmer': '1',
                            'ptmp': '1',
                            'id_spot': '313170',
                            'id_model': '3',
                        },
                        self.logger))
                    performed_calls += 1
                    if performed_calls >= self.max_calls:
                        self.logger.info(
                            'Waiting [{} s] to prevent max API calls exceedance'
                            .format(self.retry_period_s))
                        time.sleep(self.retry_period_s)
                        performed_calls = 0
            finally:
                if connection is not None:
                    connection.close()
