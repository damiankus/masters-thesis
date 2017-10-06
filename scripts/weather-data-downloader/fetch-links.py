#!/usr/bin/env python3

import requests
import json
import logging
from lxml import etree
from linkparser import LinkTarget

# Logger config

logging.basicConfig(format="[%(asctime)-11s][%(levelname)s][%(name)s] : %(message)s")
logger = logging.getLogger("downloader")
logger.setLevel(logging.INFO)

def callback_decorator(config):
  def callback(links):
    logger.info("Saving {0} links to file [{1}]".format(len(links), config["linksFilename"]))
    with open(config["linksFilename"], "w+") as output_file:
      for link in links:
        output_file.write(link + "\n")
  return callback

# Main

with open("config.json", "r") as config_file:
  config = json.load(config_file)
  links_html = ""

  try:
    with open(config["htmlContentFilename"], "r") as html_file:
      logger.info("Reading cached HTML content from file [{0}]".format(config["htmlContentFilename"]))
      links_html = html_file.read()

  except FileNotFoundError as e:
    logger.info("Cached file not found. Fetching data from [{0}]".format(config["url"] + config["year"]))
    links_html = requests.get(config["url"] + config["year"]).text

    logger.info("Saving links HTML to file {0}".format(config["htmlContentFilename"]))
    with open(config["htmlContentFilename"], "w+") as html_file:
      
      # Skip the DOCTYPE header to prevent parsing errors
      links_html = links_html[links_html.find("\n") + 1:]
      html_file.write(links_html)

  link_parser = etree.HTMLParser(target=LinkTarget(
    config,
    callback_decorator(config)
  ))
  tree = etree.fromstring(links_html, parser=link_parser)