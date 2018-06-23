#!/usr/bin/env python3

import csv
import psycopg2


class AirlyImporter:
    def __init__(self, conn):
        self.conn = conn

    def save_from_csv(self, in_path, statement, line_processor):
        cursor = self.conn.cursor()
        try:
            with open(in_path, 'r') as in_file:
                csv_reader = csv.reader(in_file, delimiter=',')
                header = next(csv_reader)
                for cols in csv_reader:
                    for vals in line_processor(cols, header):
                        cursor.execute(statement, vals)
                        connection.commit()
        except Exception as e:
            print(e)
            self.conn.rollback()
            raise e

    def import_stations(self, in_path):
        statement = 'INSERT INTO airly_stations(id, lattitude, longitude)\
            VALUES(%s, %s, %s)'
        self.save_from_csv(in_path, statement, lambda c, h: [c])

    def preprocess_observations(self, cols, header):
        # Number of columns other than utc_time and station_id
        rec_len = 6
        utc_time = cols[0]
        print('Importing data for {}'.format(utc_time))
        observations = []
        append = observations.append
        for i in range(1, len(cols), rec_len):
            station_header = header[i:(i + rec_len)]
            station_id = station_header[0].split('_')[0]
            observation = [utc_time, station_id] + cols[i:(i + rec_len)]
            append([c if c != '' else None for c in observation])
        return observations

    def import_observations(self, in_path):
        colnames = ['utc_time', 'station_id', 'temperature',
                    'humidity', 'pressure', 'pm1', 'pm2_5', 'pm10']
        statement = 'INSERT INTO airly_observations({}) VALUES({})' \
            .format(','.join(colnames), ','.join(['%s'] * len(colnames)))
        self.save_from_csv(in_path, statement, self.preprocess_observations)


if __name__ == '__main__':
    conn_params = {
        'dbname': 'pollution',
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