#!/usr/bin/env python3

import json
import psycopg2
import urllib.error
import urllib.parse
import urllib.request


def get_json(url):
    req = urllib.request.Request(url)
    with urllib.request.urlopen(req) as res:
        json_string = str(res.read(), 'utf-8')
        return json.loads(json_string)


def slice_dict(d, attrs):
    return dict([(attr, d[attr])
                for attr in d.keys() if attr in attrs])


def exec_stat(connection, stat):
    cursor = connection.cursor()
    try:
        cursor.execute(stat)
        connection.commit()
    except Exception as e:
        connection.rollback()
        raise e


if __name__ == '__main__':
    config = None
    with open('config.json', 'r') as config_file:
        config = json.load(config_file)

    connection = None
    try:
        connection = psycopg2.connect(**config['db-connection'])
        token = config['api-token']
        url = config['api-endpoint'].format(token=token)
        stations = get_json(url)
        ids = set(config['station-ids'])
        attrs = set(['Device', 'Lat', 'Lon'])
        stations = [slice_dict(s, attrs)
                    for s in stations
                    if s['Device'] in ids
                    and s['Lat'] != '0']
        update_stat = 'UPDATE ' + config['stations-table'] + \
            """
            SET latitude = {Lat}, longitude = {Lon}
            WHERE id = '{Device}'
            """
        for s in stations:
            stat = update_stat.format(**s)
            exec_stat(connection, stat)
            print('Updated {}'.format(s['Device']))
    finally:
        if connection:
            connection.close()
