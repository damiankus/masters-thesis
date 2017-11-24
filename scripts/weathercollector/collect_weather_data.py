#!/usr/bin/env python3

import urllib.request
import urllib.error
import urllib.parse
import json
import os.path


def load_stations(in_path, out_path, city='Krakow'):
    with open(in_path, 'r') as in_file:
        neighbors = json.load(in_file)['location']['nearby_weather_stations']
        common_keys = ['city', 'lat', 'lon']
        airport_keys = common_keys + ['icao']
        pws_keys = common_keys[:] + ['id', 'neighborhood']
        airports = [dict([(key, station[key]) for key in airport_keys])
                    for station in neighbors['airport']['station']
                    if station['city'] == city]
        pws = [dict([(key, station[key]) for key in pws_keys])
               for station in neighbors['pws']['station']]
        with open(out_path, 'w+') as out_file:
            stations = {'stations': [
                {
                    'type': 'airport',
                    'type-id': 'icao',
                    'id-attr': 'icao',
                    'locations': airports,
                },
                {
                    'type': 'pws',
                    'type-id': 'pws',
                    'id-attr': 'id',
                    'locations': pws
                }
            ]}
            json.dump(stations, out_file, indent=4)
            print('Saved list of stations in: [{}]'.format(out_path))
            return stations


def traverse_dict(d, example):
    pass


def get(url, params):
    """
    @type url: string
    @param url: A complete URL to the API endpoint.
    @type params: dict
    @param params: A sample response used for finding
        the way to traverse other responses based on
        the structure of nested JSON objects.
    """

    print('Connecting to: {}'.format(url))
    with urllib.request.urlopen(url) as res:
        json_string = str(res.read(), 'utf-8')
        observation = json.loads(json_string)
        measures = dict([(key, observation[key]) for key in params])
        print(measures)


if __name__ == "__main__":
    global_config = None
    stations = None
    with open('config.json', 'r') as config_file:
        global_config = json.load(config_file)

    # Requests to the Wunderground API
    config = global_config['wunderground']
    if not os.path.isfile(config['stations-file']):
        print('Parsing a sample response from API')
        stations = load_stations(config['response-file'],
                                 config['stations-file'])

    if stations is None:
        with open(config['stations-file']) as stations_file:
            stations = json.load(stations_file)

    stations = stations['stations']
    endpoint = config['api-endpoint']
    for station_group in stations:
        for location in station_group['locations']:
            get(endpoint.format(station_group['type-id'],
                                location[station_group['id-attr']]),
                config['json-keys'],
                config['params'])

