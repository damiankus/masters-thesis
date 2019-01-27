#!/usr/bin/env python3

import csv
import psycopg2
import psycopg2.extras
import itertools


class AirlyImporter:
    def __init__(self, conn):
        self.conn = conn

    def save_from_csv(self, in_path, table_name, colnames, line_processor):
        cursor = self.conn.cursor()
        statement = 'INSERT INTO {0}({1}) VALUES %s'.format(
            table_name, ','.join(colnames)
        )
        try:
            with open(in_path, 'r') as in_file:
                csv_reader = csv.reader(in_file, delimiter=',')
                header = next(csv_reader)
                records = list(itertools.chain(*[line_processor(cols, header) for cols in csv_reader]))
                psycopg2.extras.execute_values(cursor, statement, records)
                connection.commit()
        except Exception as e:
            print(e)
            self.conn.rollback()
            raise e

    def import_stations(self, in_path):
        colnames = ['id', 'latitude', 'longitude']
        def preprocess_stations(cols, header):
            # Wrap columns in a list to allow for concatenation
            # required in the case of observations
            return [tuple([cols[idx] for idx in range(len(cols))])]
        self.save_from_csv(in_path, 'airly_stations', colnames, preprocess_stations)

    def import_observations(self, in_path):
        colnames = ['utc_time', 'station_id', 'temperature',
                    'humidity', 'pressure', 'pm1', 'pm2_5', 'pm10']

        def preprocess_observations(cols, header):
            # Number of columns other than utc_time and station_id
            record_len = len(colnames) - 2

            # Just to be sure that the datetime string
            # is parsed for the UTC timezone
            utc_time = cols[0] + '+00:00'

            # print('Importing data for {}'.format(utc_time))
            records = []
            append = records.append
            print('Saving for {}'.format(utc_time))

            # the first column contains a datetime string
            # common for the whole row
            for i in range(1, len(cols), record_len):
                station_header = header[i:(i + record_len)]
                station_id = station_header[0].split('_')[0]
                values = [utc_time, station_id] + cols[i:(i + record_len)]
                record = tuple([values[idx] if values[idx] else None for idx in range(len(values))])
                append(record)
            return records
        
        self.save_from_csv(in_path, 'airly_observations', colnames, preprocess_observations)


if __name__ == '__main__':
    conn_params = {
        'dbname': 'air_quality',
        'user': 'damian',
        'host': 'localhost',
        'password': 'pass'
    }
    try:
        connection = psycopg2.connect(**conn_params)
        importer = AirlyImporter(connection)
        importer.import_stations('sensor_locations.csv')
        importer.import_observations('airly-merged.csv')
    finally:
        if connection:
            connection.close()
