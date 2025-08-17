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

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s', datefmt='%H:%M:%S')

# Get current date in EST and determine processing range
est = pytz.timezone('America/New_York')
now = datetime.now(est)

if now.month == 12 and now.day <= 25:
    end_year, last_day = now.year, now.day
else:
    end_year, last_day = now.year - 1, 25

START_YEAR = 2015
OUTPUT_FILE = os.getenv('OUTPUT_FILE', 'puzzles.json')
CACHE_DIR = os.getenv('CACHE_DIR', 'cache')

def log(level, msg): logging.log(getattr(logging, level), msg)

def get_puzzle_name(day, year):
    cache_file = f'{CACHE_DIR}/{year}_{day}.txt'
    
    # Return cached result if exists
    if os.path.exists(cache_file):
        with open(cache_file) as f:
            return f.read().strip()
    
    # Fetch with retry and rate limiting
    url = f"https://adventofcode.com/{year}/day/{day}"
    
    for attempt in range(3):
        try:
            response = requests.get(url, timeout=10)
            response.raise_for_status()
            
            soup = BeautifulSoup(response.text, 'html.parser')
            h2 = soup.find('h2')
            
            if h2:
                text = h2.get_text(strip=True)
                start_marker = f"--- Day {day}: "
                end_marker = " ---"
                
                start_idx = text.find(start_marker)
                if start_idx != -1:
                    start_idx += len(start_marker)
                    end_idx = text.find(end_marker, start_idx)
                    
                    if end_idx != -1:
                        puzzle_name = text[start_idx:end_idx].strip()
                        
                        # Cache result
                        os.makedirs(CACHE_DIR, exist_ok=True)
                        with open(cache_file, 'w') as f:
                            f.write(puzzle_name)
                        
                        time.sleep(random.uniform(0.5, 1.4))
                        return puzzle_name
        
        except Exception as e:
            if attempt < 2:
                time.sleep((attempt + 1) * 2)
            else:
                log('WARNING', f'Failed to fetch puzzle for {year} day {day}: {e}')
    
    return None

# Initialize or load existing JSON
if os.path.exists(OUTPUT_FILE):
    with open(OUTPUT_FILE) as f:
        json_data = json.load(f)
else:
    json_data = {}

log('INFO', f'Processing years {START_YEAR}-{end_year}, up to day {last_day}')

for year in range(START_YEAR, end_year + 1):
    year_str = str(year)
    if year_str not in json_data:
        json_data[year_str] = {}
    
    max_day = last_day if year == end_year else 25
    
    for day in range(1, max_day + 1):
        day_str = str(day)
        
        # Skip if puzzle already exists
        if json_data[year_str].get(day_str):
            continue
        
        log('INFO', f'Fetching {year} day {day}')
        puzzle_name = get_puzzle_name(day, year)
        if puzzle_name:
            json_data[year_str][day_str] = puzzle_name

# Save updated JSON with proper day ordering
def sort_json(obj):
    if isinstance(obj, dict):
        # Sort year keys naturally, day keys numerically
        return {k: sort_json(v) for k, v in sorted(obj.items(), 
                key=lambda x: int(x[0]) if x[0].isdigit() and len(x[0]) <= 2 else x[0])}
    return obj

with open(OUTPUT_FILE, 'w') as f:
    json.dump(sort_json(json_data), f, indent=2)
    f.write('\n')

log('INFO', f'Updated {OUTPUT_FILE} successfully')
