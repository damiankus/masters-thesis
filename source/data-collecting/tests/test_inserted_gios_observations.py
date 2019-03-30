#!/usr/bin/env python3

import csv
import json
import unittest
from decimal import Decimal
from operator import itemgetter
import psycopg2
from querybuilder.querybuilder import QueryBuilder


class TestDataImport(unittest.TestCase):

    def get_config(self, fpath):
        with open(fpath, 'r') as config_file:
            return json.load(config_file)

    def connect_to_db(self, config):
        try:
            return psycopg2.connect(**config['db-connection'])
        except Exception as e:
            self.fail('Could not connect to a database: ' + str(e))

    def setup_test_data(self, config_path, valid_values_path):
        self.config = self.get_config(config_path)
        self.conn = self.connect_to_db(self.config)
        self.valid_values_file = open(valid_values_path, 'r')
        self.csv_reader = csv.reader(self.valid_values_file,
                                     delimiter=',', quotechar='"')

    def assert_equality_for_columns(
            self, colnames, condition_colnames, acceptable_error=10**-2):
        cursor = self.conn.cursor()
        query_builder = QueryBuilder()

        header = next(self.csv_reader)
        raw_valid_records = [dict(zip(header, values))
                             for values in self.csv_reader]

        # sort the records to be sure their order
        # is same as the order of rows fetched from the DB
        valid_records = sorted(
            raw_valid_records, key=itemgetter(*condition_colnames))

        condition_groups = [
            query_builder.get_query_conditions(
                condition_colnames, record)
            for record in valid_records
        ]

        statement = query_builder.get_select_query(
            header,
            self.config['observations-table'],
            condition_colnames,
            condition_groups)
        cursor.execute(statement)

        records = [dict(zip(header, row)) for row in cursor]

        if len(records) != len(valid_records):
            self.fail('Number of fetched results is different\
                from the expected one ({0} != {1})'.format(
                len(records), len(valid_records)))

        for actual, expected in zip(records, valid_records):
            for colname in colnames:
                if not expected[colname]:
                    self.assertIsNone(actual[colname])
                else:
                    # Currenlty only numeric values are used for testing
                    self.assertLessEqual(
                        abs(actual[colname] - Decimal(expected[colname])),
                        acceptable_error)

    def test_gios_observations(self):
        self.setup_test_data('../gios/config.json', 'gios/valid_values.csv')
        self.assert_equality_for_columns(
            ['pm2_5', 'pm10'], ['station_id', 'measurement_time'])

    def test_airly_observations(self):
        self.setup_test_data('../airly/config.json', 'airly/valid_values.csv')
        self.assert_equality_for_columns(
            ['temperature', 'humidity', 'pressure', 'pm1', 'pm2_5', 'pm10'],
            ['utc_time', 'station_id'])

    def test_agh_meteo_observations(self):
        self.setup_test_data('../agh-meteo/config.json',
                             'agh-meteo/valid_values.csv')
        self.assert_equality_for_columns(
            ['averageAirPressure', 'averageAirTemp', 'averageRelativeHumidity',
                'averageWindDirection', 'averageWindSpeed', 'rainIntensity'],
            ['time'])

    def test_wunderground_observations(self):
        self.setup_test_data('../wunderground/config.json',
                             'wunderground/valid_values.csv')
        self.assert_equality_for_columns(
            ['humidity', 'precip_rate', 'precip_total', 'pressure',
                'solradiation', 'temperature', 'wind_dir_deg', 'wind_speed'],
            ['station_id', 'timestamp'])
            
    def tearDown(self):
        if self.conn:
            self.conn.close()
        if self.valid_values_file:
            self.valid_values_file.close()
