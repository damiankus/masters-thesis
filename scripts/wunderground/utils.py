#!/usr/bin/env python3


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
    try:
        cursor.execute(statement, vals)
        connection.commit()
    except Exception as e:
        connection.rollback()
        raise e


def exec_stat(connection, stat):
    cursor = connection.cursor()
    try:
        cursor.execute(stat)
        connection.commit()
    except Exception as e:
        connection.rollback()
        raise e
