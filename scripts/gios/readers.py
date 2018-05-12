#!/usr/bin/env python3

import csv
from abc import ABC, abstractmethod
from models import Observation

TRANS_TAB = ''.maketrans(',', '.')


class AbstractDataReader(ABC):
    def __init__(self, station_id, station_uuid, var_names,
                 header_line_no, data_line_no):
        self.station_id = station_id
        self.station_uuid = station_uuid
        self.var_names = ['_'.join(
            v.strip().lower().split('.'))
            for v in var_names]
        self.header_line_no = header_line_no
        self.data_line_no = data_line_no
        super().__init__()

    def read_data(self, fpath):
        records = self.read_from_file(fpath)
        mapping = self.map_to_object
        return [mapping(r) for r in records]

    def read_from_file(self, fpath):
        lines = []
        append = lines.append
        with open(fpath, 'r') as csv_file:
            reader = csv.reader(csv_file, delimiter=',', quotechar='"')

            # Skip header lines till the main line
            for i in range(self.header_line_no):
                next(reader)
            self.col_indexes = self.get_var_indexes(next(reader))

            # Skip to the beginning of data records
            for i in range(self.data_line_no - self.header_line_no - 1):
                next(reader)
            for row in reader:
                record = {'timestamp':  row[0]}
                for i in range(len(self.var_names)):
                    record[self.var_names[i]] = row[self.col_indexes[i]].translate(TRANS_TAB)
                append(record)
        return lines

    @abstractmethod
    def get_var_indexes(self, cols):
        pass

    def map_to_object(self, record):
        record['station_id'] = self.station_id
        return Observation(**record)


class YearlyDataReader(AbstractDataReader):
    def get_var_indexes(self, cols):
        cols = [c.lower() for c in cols]
        return [cols.index(self.station_uuid.lower())]


class MonthlyDataReader(AbstractDataReader):
    def get_var_indexes(self, cols):
        cols = [c.strip().lower().replace('.', '_') for c in cols]
        indexes = []
        for v in self.var_names:
            found = False
            i = 0
            while not found and i < len(cols):
                found = cols[i].endswith(v)
                i += 1
            if found:
                indexes.append(i - 1)
        return indexes