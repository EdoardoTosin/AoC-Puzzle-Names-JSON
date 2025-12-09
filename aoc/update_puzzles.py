#!/usr/bin/env python3

import json
import os
from datetime import datetime
import time
import logging
import random
import pytz
import requests
from bs4 import BeautifulSoup

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)

START_YEAR = 2015
OUTPUT_FILE = os.getenv("OUTPUT_FILE", "puzzles.json")
CACHE_DIR = os.getenv("CACHE_DIR", "cache")
MAX_FETCH_ATTEMPTS = 3

os.makedirs(CACHE_DIR, exist_ok=True)


def log(level, msg):
    logging.log(getattr(logging, level), msg)


# Determine max available day for a year
def get_max_day_for_year(year):
    cache_file = os.path.join(CACHE_DIR, f"{year}_max_day.txt")

    if os.path.exists(cache_file):
        with open(cache_file) as f:
            return int(f.read().strip())

    url = f"https://adventofcode.com/{year}"
    max_day = 25

    for attempt in range(MAX_FETCH_ATTEMPTS):
        try:
            response = requests.get(url, timeout=10)
            response.raise_for_status()

            soup = BeautifulSoup(response.text, "html.parser")

            # Select only valid <a href="/YEAR/day/N"> links
            days = []
            for tag in soup.find_all("a", href=True):
                href = tag["href"]
                prefix = f"/{year}/day/"
                if href.startswith(prefix):
                    day_text = href[len(prefix) :]
                    if day_text.isdigit():
                        days.append(int(day_text))

            if days:
                max_day = max(days)

            with open(cache_file, "w") as f:
                f.write(str(max_day))

            time.sleep(random.uniform(0.5, 1.4))
            return max_day

        except Exception as e:
            if attempt < MAX_FETCH_ATTEMPTS - 1:
                time.sleep((attempt + 1) * 2)
            else:
                log("WARNING", f"Failed to detect max day for {year}: {e}")

    with open(cache_file, "w") as f:
        f.write(str(max_day))

    return max_day


# Puzzle name fetching
def get_puzzle_name(day, year):
    cache_file = f"{CACHE_DIR}/{year}_{day}.txt"

    if os.path.exists(cache_file):
        with open(cache_file) as f:
            return f.read().strip()

    url = f"https://adventofcode.com/{year}/day/{day}"

    for attempt in range(MAX_FETCH_ATTEMPTS):
        try:
            response = requests.get(url, timeout=10)
            response.raise_for_status()

            soup = BeautifulSoup(response.text, "html.parser")
            h2 = soup.find("h2")
            if not h2:
                raise ValueError("H2 missing")

            text = h2.get_text(strip=True)
            start_marker = f"--- Day {day}: "
            end_marker = " ---"

            start_idx = text.find(start_marker)
            if start_idx != -1:
                start_idx += len(start_marker)
                end_idx = text.find(end_marker, start_idx)
                if end_idx != -1:
                    name = text[start_idx:end_idx].strip()

                    with open(cache_file, "w") as f:
                        f.write(name)

                    time.sleep(random.uniform(0.5, 1.4))
                    return name

        except Exception as e:
            if attempt < MAX_FETCH_ATTEMPTS - 1:
                time.sleep((attempt + 1) * 2)
            else:
                log("WARNING", f"Failed to fetch puzzle for {year} day {day}: {e}")

    return None


# Determine year/day processing range
est = pytz.timezone("America/New_York")
now = datetime.now(est)

if now.month == 12:
    end_year = now.year
else:
    end_year = now.year - 1

# Load existing JSON
if os.path.exists(OUTPUT_FILE):
    with open(OUTPUT_FILE) as f:
        json_data = json.load(f)
else:
    json_data = {}

log("INFO", f"Processing years {START_YEAR}-{end_year}")

# Main processing loop
for year in range(START_YEAR, end_year + 1):
    year_str = str(year)
    json_data.setdefault(year_str, {})

    # Determine max days dynamically
    max_day = get_max_day_for_year(year)

    # For current year, cap by today's date in December
    if year == now.year:
        if now.month == 12:
            max_day = min(max_day, now.day)
        else:
            continue

    log("INFO", f"Year {year}: detected {max_day} available puzzles")

    for day in range(1, max_day + 1):
        day_str = str(day)

        if json_data[year_str].get(day_str):
            continue

        log("INFO", f"Fetching {year} day {day}")
        puzzle_name = get_puzzle_name(day, year)

        if puzzle_name:
            json_data[year_str][day_str] = puzzle_name


# Sorted JSON output
def sort_json(obj):
    if isinstance(obj, dict):
        return {
            k: sort_json(v)
            for k, v in sorted(
                obj.items(),
                key=lambda x: (
                    int(x[0]) if x[0].isdigit() else float("inf"),
                    x[0],
                ),
            )
        }
    return obj


with open(OUTPUT_FILE, "w") as f:
    json.dump(sort_json(json_data), f, indent=2)
    f.write("\n")

log("INFO", f"Updated {OUTPUT_FILE} successfully")
