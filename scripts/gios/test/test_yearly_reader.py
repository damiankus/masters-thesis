#!/usr/bin/env python3

import unittest
from readers import YearlyDataReader


class TestYearlyReader(unittest.TestCase):
    def setUp(self):
        self.fpath = 'test/yearly_data.csv'
        self.station_ids = ['gios_krasinskiego', 'gios_bulwarowa']
        self.station_uuids = ['MpKrakAlKras', 'MpKrakBulwar']
        self.var_names = ['pm2_5', 'pm10']
        self.reader = YearlyDataReader(
            self.station_ids, self.station_uuids, self.var_names)

        self.header = """Kod stacji,MpKrakAlKras,MpKrakBujaka,MpKrakBulwar,MpKrakAlKras,MpKrakBujaka,MpKrakBulwar,MpKrakDietla,MpKrakOsPias,MpKrakZloRog
Wskaźnik,PM2.5,PM2.5,PM2.5,PM10,PM10,PM10,PM10,PM10,PM10
Czas uśredniania,1g,1g,1g,1g,1g,1g,1g,1g,1g"""
        self.header = [row.split(',') for row in self.header.split('\n')]
        self.col_indexes = [3]
        self.records = self.reader.read_from_file(self.fpath)
        self.observations = [
            self.reader.map_to_object(r) for r in self.records]

    def test_yearly_getVarIndexes_firstStation_firstVar(self):
        col_indexes = self.reader.get_var_indexes(self.header)
        print(self.header)
        self.assertEqual(
            col_indexes[self.station_ids[0]][self.var_names[0]],
            1)

    def test_yearly_getVarIndexes_firstStation_secondVar(self):
        col_indexes = self.reader.get_var_indexes(self.header)
        self.assertEqual(
            col_indexes[self.station_ids[0]][self.var_names[1]],
            4)

    def test_yearly_getVarIndexes_secondStation_firstVar(self):
        col_indexes = self.reader.get_var_indexes(self.header)
        self.assertEqual(
            col_indexes[self.station_ids[1]][self.var_names[0]],
            3)

    def test_yearly_getVarIndexes_secondStation_secondVar(self):
        col_indexes = self.reader.get_var_indexes(self.header)
        self.assertEqual(
            col_indexes[self.station_ids[1]][self.var_names[1]],
            6)

    def test_yearly_readFromFile_length(self):
        self.assertEqual(len(self.records), 20)

    def test_yearly_readFromFile_firstRecordTimestamp(self):
        self.assertEqual(self.records[0]['timestamp'], '2016-01-01 01:00:00')

    def test_yearly_readFromFile_firstRecordStationId(self):
        self.assertEqual(self.observations[0].station_id, 'gios_krasinskiego')

    def test_yearly_readFromFile_firstRecordPm25Value(self):
        self.assertEqual(self.observations[0].pm2_5, '248.173')

    def test_yearly_readFromFile_firstRecordPm10Value(self):
        self.assertEqual(self.observations[0].pm10, '303.558')

    def test_yearly_readFromFile_lastRecordTimestamp(self):
        self.assertEqual(self.records[-1]['timestamp'], '2016-01-01 10:00:00')

    def test_yearly_readFromFile_lastRecordStationId(self):
        self.assertEqual(self.observations[-1].station_id, 'gios_bulwarowa')

    def test_yearly_readFromFile_lastRecordPm25Value(self):
        self.assertEqual(self.observations[-1].pm2_5, '154.305')

    def test_yearly_readFromFile_lastRecordPm10Value(self):
        self.assertEqual(self.observations[-1].pm10, '191.754')
