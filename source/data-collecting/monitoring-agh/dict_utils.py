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
        for idx in range(min(len(d), len(schema))):
            result.append(extract_attrs(d[idx], schema[idx]))
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
        for idx, item in enumerate(d):
            e = flatten_dict(item, prefix + str(idx + 1))
            result.update(e)
    elif key != 'id' or skip_id is False:
        # Delete ID attributes in order to
        # prevent conflict while inserting them
        # into a database
        result[key] = d
    return result
