#!/usr/bin/env python3

import unittest
from readers import YearlyDataReader


class TestYearlyReader(unittest.TestCase):
    def setUp(self):
        self.fpath = 'test/yearly_data.csv'
        self.station_id = 'gios_krasinskiego'
        self.station_uuid = 'MpKrakAlKras'
        self.header_line_no = 1
        self.data_line_no = 6
        self.var_names = ['pm2.5']
        self.reader = YearlyDataReader(
            self.station_id, self.station_uuid, self.var_names,
            self.header_line_no, self.data_line_no)
        self.header = ',LdZgieMielcz,LuZielKrotka,MpKrakAlKras, \
            MpKrakBujaka,MpKrakBulwar,MzLegZegrzyn,MzPiasPulask'
        self.colnames = self.header.split(',')
        self.col_indexes = [3]
        self.records = self.reader.read_from_file(self.fpath)
        self.observations = [
            self.reader.map_to_object(r) for r in self.records]

    def test_yearly_getVarIndexes(self):
        col_indexes = self.reader.get_var_indexes(self.colnames)
        self.assertEqual(self.col_indexes[0], col_indexes[0])
    def test_yearly_readFromFile_length(self):
        self.assertEqual(len(self.records), 10)

    def test_yearly_readFromFile_firstRecordTimestamp(self):
        self.assertEqual(self.records[0]['timestamp'], '2016-01-01 01:00:00')

    def test_yearly_readFromFile_firstRecordPm25Value(self):
        self.assertEqual(self.observations[0].pm2_5, '248.173')

    def test_yearly_readFromFile_firstRecordPm10Value(self):
        self.assertIsNone(self.observations[0].pm10)

    def test_yearly_readFromFile_lastRecordTimestamp(self):
        self.assertEqual(self.records[-1]['timestamp'], '2016-01-01 10:00:00')

    def test_yearly_readFromFile_lastRecordPm25Value(self):
        self.assertEqual(self.observations[-1].pm2_5, '226.542')

    def test_yearly_readFromFile_lastRecordPm10Value(self):
        self.assertIsNone(self.observations[-1].pm10)
