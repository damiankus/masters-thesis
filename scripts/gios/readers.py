#!/usr/bin/env python3

import csv
from abc import ABC, abstractmethod
from models import Observation

TRANS_NUM = ''.maketrans(',', '.')
TRANS_DOT = ''.maketrans('.', '_')


class AbstractDataReader(ABC):
    def __init__(self, station_ids, station_uuids, var_names,
                 delimiter=',', quotechar='"'):
        super().__init__()
        self.station_ids = [s.lower() for s in station_ids]
        self.station_uuids = [u.lower() for u in station_uuids]
        self.data_line_no = 0
        self.var_names = [
            v.strip().lower().translate(TRANS_DOT)
            for v in var_names]
        self.csv_opts = {'delimiter': delimiter}
        if quotechar:
            self.csv_opts['quotechar'] = quotechar

    def read_data(self, fpath):
        records = self.read_from_file(fpath)
        mapping = self.map_to_object
        return [mapping(r) for r in records]

    def read_from_file(self, fpath):
        lines = []
        append = lines.append
        with open(fpath, 'r') as csv_file:
            reader = csv.reader(
                csv_file, **self.csv_opts)
            header = []

            # Read header
            for i in range(self.data_line_no):
                header.append(next(reader))
            col_indexes = self.get_var_indexes(header)

            for row in reader:
                for s in self.station_ids:
                    record = {
                        'timestamp':  row[0],
                        'station_id': s
                    }
                    for v in self.var_names:
                        idx = col_indexes[s][v]
                        if idx is not None and row[idx]:
                            record[v] = row[idx].translate(TRANS_NUM)
                    append(record)
        return lines

    def map_to_object(self, record):
        return Observation(**record)

    """
    Returns a dict with two key levels:
    1. id of a station
    2. preprocessed name of variable
       (lowercase, dots replaced with underscores)
    Values are the numbers of columns (starting from 0)
    in the file for specified station and variable
    """
    @abstractmethod
    def get_var_indexes(self, cols):
        pass


class YearlyDataReader(AbstractDataReader):
    def __init__(self, station_ids, station_uuids, var_names,
                 delimiter=',', quotechar='"'):
        super().__init__(station_ids, station_uuids, var_names,
                         delimiter, quotechar)
        self.data_line_no = 6

    def get_var_indexes(self, header):
        all_uuids = [s.lower() for s in header[1]]
        all_var_names = [v.lower().translate(TRANS_DOT) for v in header[2]]
        uuids = dict([(u, i) for i, u in enumerate(self.station_uuids)])
        var_names = set(self.var_names)

        col_indexes = dict([
            (s, dict.fromkeys(self.var_names)) for s in self.station_ids])
        for i, s in enumerate(all_uuids):
            if s in uuids and all_var_names[i] in var_names:
                col_indexes[self.station_ids[uuids[s]]][all_var_names[i]] = i
        return col_indexes


class MonthlyDataReader(AbstractDataReader):
    def __init__(self, station_ids, station_uuids, var_names,
                 delimiter=',', quotechar='"'):
        super().__init__(station_ids, station_uuids, var_names,
                         delimiter, quotechar)
        self.data_line_no = 2

    def get_var_indexes(self, header):
        """
        Monthly data files contain records for only one
        station identified by name of the directory
        """
        cols = [c.strip().lower().translate(TRANS_DOT) for c in header[0]]
        col_indexes = dict([
            (s, dict.fromkeys(self.var_names)) for s in self.station_ids])

        for s in self.station_ids:
            for v in self.var_names:
                found_count = 0
                i = 0
                while not found_count == len(self.var_names) and i < len(cols):
                    if cols[i].endswith(v):
                        col_indexes[s][v] = i
                        found_count += 1
                    i += 1
        return col_indexes
