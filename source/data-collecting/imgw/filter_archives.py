#!/usr/bin/env python3

import requests
import json
import logging
import os
import glob
import gzip
import shutil
from concurrent.futures import ThreadPoolExecutor

# Logger config

logging.basicConfig(format="[%(asctime)-11s][%(levelname)s][%(name)s] : %(message)s")
logger = logging.getLogger("unzipper")
logger.setLevel(logging.INFO)

def filter_decorator(config):
  param_codes = set([code.encode("latin-1") for code in config["params"].values()])
  print(param_codes)
  def filter_archive(archive_path):
    filename = archive_path.split("/")[-1]
    # prefix format data_YYYY_MM_
    date = "_".join(filename.split("_")[1:-1])
    code = filename.split("_")[-1].split('.')[0]
    csv_path = os.path.join(config["dataDir"], config["stations"][code] + "_" + date + ".csv")
    print(csv_path)
    logger.info("Unpacking [{0}] to [{1}]".format(archive_path, csv_path))
    with gzip.open(archive_path, "rb") as archive:
      with open(csv_path, "wb+") as csv_file:
        for line in archive:
          # code is the third vale in a line
          code = line.split(b";")[3]
          if (code in param_codes):
            csv_file.write(line + b"\r\n")
  return filter_archive

# Main

with open("config.json", "r") as config_file:
  config = json.load(config_file)
  executor = ThreadPoolExecutor(max_workers=5)
  executor.map(filter_decorator(config), glob.glob(os.path.join(config["dataDir"], "*")))

