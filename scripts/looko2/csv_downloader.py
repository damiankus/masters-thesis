#!/usr/bin/env python3

import os
import requests
from concurrent.futures import ThreadPoolExecutor
from link_parser import LinkParser
from logging_utils import init_logger

logger = init_logger('CSVDownloader')


class CSVDownloader:
    def __init__(self, url, target_dir):
        self.url = url
        self.target_dir = target_dir
        if not os.path.exists(target_dir):
            logger.info('Creating directory {}'.format(target_dir))
            os.makedirs(target_dir)

    def download_csv(self, url):
        logger.info('Fetching data from {}'.format(url))
        filepath = os.path.join(self.target_dir, url.split('/')[-1])
        res = requests.get(url, stream=True)
        with open(filepath, "wb+") as output_file:
            for chunk in res.iter_content(chunk_size=8096):
                if (chunk):
                    output_file.write(chunk)
        logger.info('File saved under {}'.format(filepath))

    def download_parallel(self, urls):
        executor = ThreadPoolExecutor(max_workers=5)
        executor.map(self.download_csv, urls)

    def fetch(self):
        res = requests.get(self.url)
        parser = LinkParser(self.url, self.download_parallel)
        parser.feed(str(res.content, 'utf-8'))
