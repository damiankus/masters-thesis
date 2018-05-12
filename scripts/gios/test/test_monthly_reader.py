#!/usr/bin/env python3

import unittest
from readers import MonthlyDataReader


class TestMonthlyReader(unittest.TestCase):
    def setUp(self):
        self.fpath = 'test/monthly_data.csv'
        self.station_id = 'gios_krasinskiego'
        self.station_uuid = 'MpKrakAlKras'
        self.header_line_no = 0
        self.data_line_no = 2
        self.var_names = ['pm2.5', 'pm10']
        self.reader = MonthlyDataReader(
            self.station_id, self.station_uuid, self.var_names,
            self.header_line_no, self.data_line_no)
        self.header = 'Zanieczyszczenie,Aleja Krasińskiego - benzen,\
        Aleja Krasińskiego - pył zawieszony PM2.5,Aleja Krasińskiego - pył zawieszony PM10,\
        Aleja Krasińskiego - tlenki azotu,Aleja Krasińskiego - dwutlenek azotu,\
        Aleja Krasińskiego - tlenek węgla'

        self.colnames = self.header.split(',')
        self.col_indexes = [2, 3]
        self.records = self.reader.read_from_file(self.fpath)
        self.observations = [
            self.reader.map_to_object(r) for r in self.records]

    def test_monthly_getVarIndexes(self):
        col_indexes = self.reader.get_var_indexes(self.colnames)
        print(col_indexes)
        self.assertEqual(self.col_indexes, col_indexes)

    def test_monthly_readFromFile_length(self):
        self.assertEqual(len(self.records), 10)

    def test_monthly_readFromFile_firstRecordTimestamp(self):
        self.assertEqual(self.records[0]['timestamp'], '2017-01-01 01:00')

    def test_monthly_readFromFile_firstRecordPm25Value(self):
        self.assertEqual(self.observations[0].pm2_5, '119.9')

    def test_monthly_readFromFile_firstRecordPm10Value(self):
        self.assertEqual(self.observations[0].pm10, '160.2')

    def test_monthly_readFromFile_lastRecordTimestamp(self):
        self.assertEqual(self.records[-1]['timestamp'], '2017-01-01 10:00')

    def test_monthly_readFromFile_lastRecordPm25Value(self):
        self.assertEqual(self.observations[-1].pm2_5, '157.2')

    def test_monthly_ReadFromFile_lastRecordPm10Value(self):
        self.assertEqual(self.observations[-1].pm10, '187.3')
