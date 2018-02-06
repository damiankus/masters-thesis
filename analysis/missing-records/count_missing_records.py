#!/usr/bin/env python3

import argparse
import csv
import json
import psycopg2
from psycopg2 import sql


def execute(conn, statement, vals):
    cursor = conn.cursor()
    cursor.execute(statement, vals)
    return cursor.fetchall()


def count_factory(config):
    count_fun = None
    if len(config['sources']) == 0:
        missing_stat_template = """
            SELECT COUNT(*) FROM {observations}
            WHERE {{}} IS NULL
        """.format(observations=config['observations-table'])

        def count_missing_records(conn, source, factor):
            missing_stat = sql.SQL(missing_stat_template).format(
                sql.Identifier(factor.lower()))
            cursor = conn.cursor()
            cursor.execute(missing_stat)
            return int(cursor.fetchall()[0][0])
        count_fun = count_missing_records
    else:
        missing_stat_template = """
            SELECT COUNT(*) FROM {observations} AS o
            JOIN {stations} AS s
            ON s.id = o.station_id
            WHERE s.source = %s
            AND {{}} IS NULL
        """.format(observations=config['observations-table'],
                   stations=config['stations-table'])
        print(missing_stat_template)

        def count_missing_by_source(conn, source, factor):
            missing_stat = sql.SQL(missing_stat_template).format(
                sql.Identifier(factor.lower()))
            cursor = conn.cursor()
            cursor.execute(missing_stat, (source,))
            return int(cursor.fetchall()[0][0])
        count_fun = count_missing_by_source
    return count_fun


def count_stats_factory(config):
    count_stations_stat = ''
    count_total_stat = ''

    if len(config['sources']) == 0:
        count_stations_stat = """
            SELECT COUNT(*) FROM {stations}
        """.format(stations=config['stations-table'])

        count_total_stat = """
            SELECT COUNT(*) FROM {observations}
        """.format(observations=config['observations-table'])
    else:
        count_stations_stat = """
            SELECT COUNT(*) FROM {stations}
            WHERE source = %s
        """.format(stations=config['stations-table'])

        count_total_stat = """
            SELECT COUNT(*) FROM {observations} AS o
            JOIN {stations} AS s
            ON s.id = o.station_id
            WHERE s.source = %s
        """.format(observations=config['observations-table'],
                   stations=config['stations-table'])

    return count_stations_stat, count_total_stat


if __name__ == '__main__':

    parser = argparse.ArgumentParser(
        description='Counting incomplete reecords')
    parser.add_argument('--config', '-c', help='Path to the config file',
                        default='config.json')
    args = vars(parser.parse_args())
    config = None
    with open(args['config'], 'r') as config_file:
        config = json.load(config_file)

    sources = config['sources']
    factors = config['factors']
    header = ['Source', 'Theoretical total', 'Actual total']
    tab_rows = [header]
    for factor in factors:
        f = factor.replace('_', '.')
        header += [f, f + ' %']

    count_stations_stat, count_total_stat = count_stats_factory(config)

    conn = None
    count_missing = count_factory(config)
    try:
        conn = psycopg2.connect(**config['db-connection'])
        if len(sources) == 0:
            sources = ['all']
        for s in sources:
            stations_count = int(execute(
                conn, count_stations_stat, [s])[0][0])
            theoretical_total = 24 * 365 * stations_count
            total_count = int(execute(
                conn, count_total_stat, [s])[0][0])
            tab_row = [s, theoretical_total, total_count]

            for f in factors:
                missing_count = count_missing(conn, s, f)
                missing_ratio = (missing_count / float(total_count)) * 100
                tab_row += [missing_count, '{0:.2f}'.format(missing_ratio)]
            tab_rows.append(tab_row)

        with open(config['target-file'], 'w+') as out_file:
            writer = csv.writer(out_file, delimiter=',', quotechar='"')
            for row in tab_rows:
                writer.writerow(row)
        print('Saved')
    finally:
        if conn:
            conn.close()
