import pytest
# from weathercollector.collect_weather_data import traverse_dict


def traverse_dict(d, schema):
    if type(d) != type(schema):
        raise AttributeError(
            'Dictionary structure is not compatible with the schema')
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
        print('{} <-> {}'.format(d, schema))
        result = d
    return result


def test_json_traversion():
    schema = {
        'b': {
            'bb': [1, 2, 3]
        },
        'c': [
            {'ca': 0},
        ]
    }
    obj = {
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
    actual = traverse_dict(obj, schema)
    assert actual['b']['bb'] == expected['b']['bb']
    assert actual['c']['ca'] == expected['c']['ca']
    with pytest.assertRises(KeyError):
        actual['a'] != 1


test_json_traversion()
