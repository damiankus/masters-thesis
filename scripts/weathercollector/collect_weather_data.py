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
        pwss = [dict([(key, station[key]) for key in pws_keys])
                for station in neighbors['pws']['station']]
        for airport in airports:
            airport['type'] = 'icao'
            airport['id'] = airport.pop('icao')
        for pws in pwss:
            pws['type'] = 'pws'

        with open(out_path, 'w+') as out_file:
            stations = {'stations': airports + pwss}
            json.dump(stations, out_file, indent=4)
            print('Saved list of stations in: [{}]'.format(out_path))
            return stations


def traverse_dict(d, schema):
    result = None
    if isinstance(schema, dict):
        result = {}
        for key, item in schema.items():
            result[key] = traverse_dict(d[key], item)
    elif isinstance(schema, list):
        result = []
        for idx, item in enumerate(schema):
            result.append(traverse_dict(d[idx], item))
    else:
        result = d
    return result


def get(url, schema):
    """
    @type url: string
    @param url: A complete URL to the API endpoint.
    @type schema: dict
    @param schema: A sample response used for finding
        the way to traverse other responses based on
        the structure of nested JSON objects.
    """

    print('Connecting to: {}'.format(url))
    with urllib.request.urlopen(url) as res:
        json_string = str(res.read(), 'utf-8')
        observation = json.loads(json_string)
        measures = traverse_dict(observation, schema)
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

    for service_name, config in global_config.items():
        print('Gathering data for {}'.format(service_name))
        with open(config['stations-file']) as stations_file:
            stations = json.load(stations_file)
        stations = stations['stations']
        endpoint = config['api-endpoint']
        for station in stations:
            params = [station[param] for param in config['url-params']]
            get(endpoint.format(*params), config['schema'])
