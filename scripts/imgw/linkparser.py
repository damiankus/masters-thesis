#!/usr/bin/env python3

class LinkTarget(object):
  def __init__(self, config, callback):
    self.close_callback = callback
    self.links = []
    self.base_link = config["url"] + config["year"] + "/"

  def start(self, tag, attrs):
    if (tag == "a" and "href" in attrs and attrs["href"].endswith("gz")):
      self.links.append(self.base_link + attrs["href"])

  def close(self):
    self.close_callback(self.links)
