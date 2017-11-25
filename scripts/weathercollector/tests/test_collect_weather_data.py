#!/usr/bin/env python3

import pytest
from collector.collect_weather_data import traverse_dict
from errors.custom_errors import \
    InvalidSchemaTypeException, MissingDictException


def test_json_traversion():
    schema = {
        'b': {
            'bb': [1, 2, 3]
        },
        'c': [
            {'ca': 0},
        ]
    }
    d = {
        'a': 1,
        'b': {
            'ba': 2,
            'bb': [3, 3, 3]
        },
        'c': [
            {'ca': 4},
            {'cb': 5}
        ]
    }
    expected = {
        'b': {
            'bb': [3, 3, 3]
        },
        'c': [
            {'ca': 4},
        ]
    }
    actual = traverse_dict(d, schema)
    assert actual['b']['bb'] == expected['b']['bb']
    assert actual['c'][0]['ca'] == expected['c'][0]['ca']
    with pytest.raises(KeyError):
        actual['a'] != 1


def test_traverse_list_too_short():
    schema = {
        'b': [1, 2, 3, 4]
    }
    d = {
        'b': [3, 3, 3]
    }
    with pytest.raises(IndexError):
        traverse_dict(d, schema)


def test_traverse_missing_key():
    schema = {
        'b': [1, 2, 3, 4]
    }
    d = {
        'a': 0
    }
    with pytest.raises(KeyError):
        traverse_dict(d, schema)


def test_missing_schema():
    schema = {
        'a': None
    }
    d = {
        'a': [1, 2, 3]
    }
    with pytest.raises(InvalidSchemaTypeException):
        traverse_dict(d, schema)


def test_missing_dict():
    schema = {
        'b': [1, 2, 3, 4]
    }
    d = None
    with pytest.raises(MissingDictException):
        traverse_dict(d, schema)

