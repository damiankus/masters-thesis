#!/usr/bin/env python3

from html.parser import HTMLParser


class LinkParser(HTMLParser):
    def __init__(self, base_url, callback):
        HTMLParser.__init__(self)
        self.base_url = base_url
        self.urls = []
        self.el_stack = []
        self.callback = callback

    def handle_starttag(self, tag, attrs):
        if len(self.el_stack) >= 1:
            if self.el_stack[-1] == 'td' \
                    and tag == 'a':
                attrs = dict(attrs)
                self.urls.append(self.base_url + attrs['href'])
        self.el_stack.append(tag)

    def handle_endtag(self, tag):
        self.el_stack.pop()
        if tag == 'html':
            self.callback(self.urls)
