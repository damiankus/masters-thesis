import pytest
from weathercollector.collect_weather_data import traverse_dict


def test_json_traversion():
    example = {
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
    actual = traverse_dict(obj, example)
    assert actual['b']['bb'] == expected['b']['bb']
    assert actual['c']['ca'] == expected['c']['ca']
    with pytest.assertRises(KeyError):
        actual['a'] != 1
