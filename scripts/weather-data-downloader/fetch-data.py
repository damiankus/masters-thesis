#!/usr/bin/env python3

import requests
import json
import logging
import os
from concurrent.futures import ThreadPoolExecutor

# Logger config

logging.basicConfig(format="[%(asctime)-11s][%(levelname)s][%(name)s] : %(message)s")
logger = logging.getLogger("downloader")
logger.setLevel(logging.INFO)

# Task callabacks

def fetch_decorator(config):
  def fetch_archive(url):
    filepath = config["dataDir"] + url.split("/")[-1]
    logger.info("Fetching data from [{0}]".format(url))

    res =  requests.get(url, stream=True)
    with open(filepath, "wb+") as output_file:
      for chunk in res.iter_content(chunk_size=config["chunkSize"]):
        if (chunk):
          output_file.write(chunk)
    logger.info("File saved under [{0}]".format(filepath))

  return fetch_archive

# Main

with open("config.json", "r") as config_file:
  config = json.load(config_file)

  try:
    with open(config["linksFilename"], "r") as links_file:
      if (not os.path.exists(config["dataDir"])):
        os.makedirs(config["dataDir"])
      
      links = [line.rstrip() for line in links_file.readlines() if (len(line) > 0)]
      executor = ThreadPoolExecutor(max_workers=5)
      executor.map(fetch_decorator(config), links)

  except FileNotFoundError as e:
    logger.warning("No file named [{0}] has been found. \
      Make sure to run the fetch-links.py script first".format(config["linksFilename"]))
