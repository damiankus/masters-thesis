#!/usr/bin/env python3

from errors import InvalidSchemaTypeException, MissingDictException


def extract_attrs(d, schema):
    result = None
    if (type(d) == dict or type(d) == list) and type(d) != type(schema):
        raise InvalidSchemaTypeException(type(d))
    if isinstance(schema, dict):
        if d is None:
            raise MissingDictException
        result = {}
        for key, item in schema.items():
            result[key] = extract_attrs(d[key], item)
    elif isinstance(schema, list):
        if d is None:
            raise MissingDictException
        result = []

        # TODO: length of the list of measurments
        # may differ between responses from various stations

        for idx, item in enumerate(schema):
            result.append(extract_attrs(d[idx], item))
    else:
        result = d
    return result


def flatten_dict(d, key='', sep='_', skip_id=False):
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
    elif key != 'id' or skip_id is False:
        # Delete ID attributes in order to
        # prevent conflict while inserting them
        # into a database
        result[key] = d
    return result
