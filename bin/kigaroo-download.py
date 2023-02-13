#!/usr/bin/env python3

import logging
import os
import re
import requests
from bs4 import BeautifulSoup


ROOT = "https://app.kigaroo.de"
NEWS = "/backend/news/"
NEWSITEM = re.compile("(https://app.kigaroo.de)?(?P<slug>/backend/news/(?P<id>\d+)/show)")
GALLERY = "/backend/gallery/"
ALBUM = re.compile("(https://app.kigaroo.de)?(?P<slug>/backend/gallery/album/(?P<id>\d+))")
IMAGE = re.compile("(https://app.kigaroo.de)?(?P<slug>/backend/thumbnail/image/(?P<id>\d+)/big)")
COOKIES = {}


def get_news():
    logging.info("Getting news")
    r = requests.get(f"{ROOT}{NEWS}", cookies=COOKIES)
    r.raise_for_status()
    soup = BeautifulSoup(r.text, "html.parser")
    for a in soup.find_all("a"):
        if m := NEWSITEM.match(a.get("href")):
            r = requests.get(f"{ROOT}{m.group('slug')}", cookies=COOKIES)
            r.raise_for_status()
            filename =  f"news_{m.group('id')}.html"
            if os.path.exists(filename):
                continue
            logging.info(f"Saving {filename}")
            with open(filename, "w") as f:
                f.write(r.text)


def get_galleries():
    logging.info("Getting pictures")
    r = requests.get(f"{ROOT}{GALLERY}", cookies=COOKIES)
    r.raise_for_status()
    soup = BeautifulSoup(r.text, "html.parser")
    for a in soup.find_all("a"):
        if m := ALBUM.match(a.get("href")):
            folder = "".join(x for x in a.text if (x.isalnum() or x == " "))
            logging.info(f"Getting album {folder}")
            os.makedirs(folder, exist_ok=True)
            r = requests.get(f"{ROOT}{m.group('slug')}", cookies=COOKIES)
            r.raise_for_status()
            soup = BeautifulSoup(r.text, "html.parser")
            for a in soup.find_all("a"):
                if m := IMAGE.match(a.get("href")):
                    filename = os.path.join(folder, f"{a.get('title')}.jpg")
                    if os.path.exists(filename):
                        continue
                    r = requests.get(f"{ROOT}{m.group('slug')}", cookies=COOKIES)
                    r.raise_for_status()
                    logging.info(f"Saving {filename}")
                    with open(filename, "wb") as f:
                        f.write(r.content)


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    value = input("Log in to Kigaroo in your browser and then paste the KGRSESSION cookie: ").strip().split("=")
    if len(value) == 2:
        assert value[0] == "KGRSESSION"
        value = value[1]
    else:
        assert len(value) == 1
        value = value[0]
    COOKIES = {"KGRSESSION": value}

    get_news()
    get_galleries()
