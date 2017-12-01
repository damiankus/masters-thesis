#!/usr/bin/env python3

import json
import os
import urllib


class InvalidSchemaTypeException(Exception):
    pass


class MissingDictException(Exception):
    pass


def traverse_dict(d, schema):
    result = None
    if (type(d) == dict or type(d) == list) and type(d) != type(schema):
        raise InvalidSchemaTypeException
    if isinstance(schema, dict):
        if d is None:
            raise MissingDictException
        result = {}
        for key, item in schema.items():
            result[key] = traverse_dict(d[key], item)
    elif isinstance(schema, list):
        if d is None:
            raise MissingDictException
        result = []
        for idx, item in enumerate(schema):
            result.append(traverse_dict(d[idx], item))
    else:
        result = d
    return result


def flatten_dict(d, key='', sep='_'):
    result = {}
    prefix = key + sep if (key != '') else ''
    if isinstance(d, dict):
        for child_key, item in d.items():
            i = flatten_dict(item, prefix + child_key)
            result.update(i)
    elif isinstance(d, list):
        if len(d) == 1:
            result = flatten_dict(d[0], key)
        else:
            for idx, item in enumerate(d):
                i = flatten_dict(item, prefix + str(idx))
                result.update(i)
    elif key != 'id':
        # Delete ID attributes in order to
        # prevent conflict while iinserting them
        # into a database
        result[key] = d
    return result


def save_in_db(connection, d, stat_template, cols=[]):
    if len(cols) == 0:
        cols = list(d.keys())
    vals = [d[col] for col in cols]
    statement = stat_template.format(
        cols=','.join(cols), vals=','.join(['%s'] * len(cols)))
    cursor = connection.cursor()
    cursor.execute(statement, vals)
    connection.commit()


def get_json(url, schema, logger):
    """
    @type url: string
    @param url: A complete URL to the API endpoint.
    @type schema: dict
    @param schema: A sample response used for finding
        the way to traverse other responses based on
        the structure of nested JSON objects.
    """

    logger.info('Connecting to: {}'.format(url))
    with urllib.request.urlopen(url) as res:
        json_string = str(res.read(), 'utf-8')
        observation = json.loads(json_string)
        observation = traverse_dict(observation, schema)
        if len(observation) == 1:
            _, observation = observation.popitem()
        return flatten_dict(observation)


def post(url, body, logger):
    logger.info('Connecting to: {}'.format(url))
    body = urllib.parse.urlencode(body).encode('ascii')
    req = urllib.request.Request(url, body)
    with urllib.request.urlopen(req) as res:
        return str(res.read(), 'utf-8')


def apath(rel_path):
    return os.path.join(os.path.dirname(__file__), rel_path)