#!/usr/bin/env python3

import json
from csv_downloader import CSVDownloader
from file_merger import FileMerger

if __name__ == '__main__':
    config = {}
    with open('config.json', 'r') as fp:
        config = json.load(fp)
    downloader = CSVDownloader(config['archive-url'], config['target-dir'])
    downloader.fetch()
    merger = FileMerger(config['target-dir'], config['target-file'])
    merger.merge()
