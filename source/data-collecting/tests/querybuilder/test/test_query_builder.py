import unittest

from querybuilder.querybuilder import QueryBuilder


class TestQueryBuilder(unittest.TestCase):

    def setUp(self):
        self.builder = QueryBuilder()
        self.colnames = ['pm2_5', 'pm10']
        self.condition_colnames = ['station_id', 'measurement_time']
        self.STATION_ID = 'test_station'
        self.MEASUREMENT_TIME = '2018-01-01 00:00:00+00:00'
        self.record = {
            'dummy': None,
            'station_id': self.STATION_ID,
            'measurement_time': self.MEASUREMENT_TIME,
            'dummy2': 123,
        }
        self.table_name = 'test_table'
        self.conditions = self.builder.get_query_conditions(
            self.condition_colnames, self.record)

    def quote(self, val):
        return "'" + str(val) + "'"

    def test_generating_query_conditions(self):
        self.assertEqual(self.conditions[0].colname, 'station_id')
        self.assertEqual(self.conditions[0].value, self.STATION_ID)
        self.assertEqual(self.conditions[1].colname, 'measurement_time')
        self.assertEqual(self.conditions[1].value, self.MEASUREMENT_TIME)

    def test_query_condition_string_representation(self):
        self.assertEqual(
            str(self.conditions[0]),
            "station_id = '{}'".format(self.STATION_ID))

    def test_creating_condition_statement(self):
        statement = self.builder.get_condition_statement([self.conditions])
        self.assertEqual(
            statement, "(station_id = '{}' AND measurement_time = '{}')"
            .format(self.STATION_ID, self.MEASUREMENT_TIME)
        )

    def test_creating_complex_condition_statement(self):
        statement = self.builder.get_condition_statement(
            [self.conditions, self.conditions])
        base_statement = "(station_id = '{}' AND measurement_time = '{}')" \
            .format(self.STATION_ID, self.MEASUREMENT_TIME)
        self.assertEqual(statement, '{0} OR {0}'.format(base_statement))

    def test_generating_select_statement(self):
        statement = self.builder.get_select_query(
            self.colnames,
            self.table_name,
            self.condition_colnames,
            [self.conditions]
        )
        expected_statement = ' '.join("""
                SELECT pm2_5, pm10 FROM test_table
                WHERE (station_id = '{station_id}'
                AND measurement_time = '{measurement_time}')
                ORDER BY station_id, measurement_time
            """.format(
            station_id=self.STATION_ID,
            measurement_time=self.MEASUREMENT_TIME)
            .split())
        self.assertEqual(statement, expected_statement)
