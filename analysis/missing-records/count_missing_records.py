#!/usr/bin/env python3

import csv
import json
import psycopg2
from psycopg2 import sql


def execute(conn, statement, vals):
    cursor = conn.cursor()
    cursor.execute(statement, vals)
    return cursor.fetchall()


def count_missing_records(conn, source, factor):
    present_stat = """
        SELECT COUNT(*) FROM observations AS o
        JOIN stations AS s
        ON o.station_id = s.id
        WHERE s.source = %s
        AND {} IS NULL
    """
    present_stat = sql.SQL(present_stat).format(
        sql.Identifier(factor.lower()))
    cursor = conn.cursor()
    cursor.execute(present_stat, (source,))
    return int(cursor.fetchall()[0][0])


if __name__ == '__main__':
    sources = sorted(['agh', 'airly', 'looko2'])
    factors = ['PM1', 'PM2_5', 'PM10', 'temperature',
                      'pressure', 'humidity']

    header = ['Source', 'Theoretical total', 'Actual total']
    for factor in factors:
        f = factor.replace('_', '.')
        header += [f, f + ' %']

    tab_rows = [header]
    conn = None
    config = None
    with open('config.json', 'r') as config_file:
        config = json.load(config_file)

    count_stations_stat = """
        SELECT COUNT(*) FROM stations WHERE source = %s
    """
    total_stat = """
        SELECT COUNT(*) FROM observations AS o
        JOIN stations AS s
        ON o.station_id = s.id
        WHERE s.source = %s
    """

    try:
        conn = psycopg2.connect(**config['db-connection'])
        for s in sources:
            stations_count = int(execute(
                conn, count_stations_stat, [s])[0][0])
            theoretical_total = 24 * 365 * stations_count
            total_count = int(execute(
                conn, total_stat, [s])[0][0])
            tab_row = [s, theoretical_total, total_count]

            for f in factors:
                missing_count = count_missing_records(conn, s, f)
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
