#!/usr/bin/env python3

import json
import base64
import urllib.error
import urllib.parse
import urllib.request
from dict_utils import extract_attrs, flatten_dict


def get_token(url, auth_phrase=b'fslab:monitoring'):
    # A byte-encoded body is necessary to send a POST request
    req = urllib.request.Request(url, data=b'')
    req.add_header('Authorization', b'Basic ' + base64.b64encode(auth_phrase))
    with urllib.request.urlopen(req) as res:
        json_string = str(res.read(), 'utf-8')
        res_dict = json.loads(json_string)
        return res_dict['access_token'], res_dict['refresh_token']


def revoke_token(url, refresh_token, auth_phrase=b'fslab:monitoring'):
    req = urllib.request.Request(url.format(refresh_token), data=b'')
    req.add_header('Authorization', b'Basic ' + base64.b64encode(auth_phrase))
    with urllib.request.urlopen(req) as res:
        json_string = str(res.read(), 'utf-8')
        return json.loads(json_string)['access_token']


def get(url, schema, token):
    """
    @type url: string
    @param url: A complete URL to the API endpoint.
    @type schema: dict
    @param schema: A sample response used for finding
        the way to traverse other responses based on
        the structure of nested JSON objects.
    """

    req = urllib.request.Request(url)
    req.add_header('Authorization', 'Bearer ' + token)
    with urllib.request.urlopen(req) as res:
        json_string = str(res.read(), 'utf-8')
        observations = json.loads(json_string)
        results = []
        if schema is not None:
            for observation in observations:
                observation = extract_attrs(observation, schema)
                if len(observation) == 1:
                    _, observation = observation.popitem()
                results.append(observation)
        return results
