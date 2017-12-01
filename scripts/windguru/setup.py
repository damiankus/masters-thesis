#!/usr/bin/env python3

from setuptools import setup, find_packages


setup(
    name='Windguru-Collector',
    version='0.1',
    packages=find_packages(exclude=['tests']),
    setup_requires=['pytest-runner'],
    tests_require=['pytest'],
    package_data={
        '': ['*.json', '*.yml', '*.conf', '*.txt']
    },
    include_package_data=True
)
