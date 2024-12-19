import requests
from bs4 import BeautifulSoup
import json
import os
from datetime import datetime
import pytz
import time
import logging
import hashlib
import random

# Set up logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# Define the current date in UTC-5 (EST)
est = pytz.timezone('US/Eastern')
now = datetime.now(est)

# Determine the valid year and last valid day based on the current month and day
if now.month == 12 and now.day <= 25:
    end_year = now.year  # Current year if it's December and before 25th
    last_day = now.day   # Set the last valid day to today if it's before or on 25th
elif now.month == 12 and now.day > 25:
    end_year = now.year  # Current year if it's after 25th December
    last_day = 25        # Only check up to 25th December
else:
    end_year = now.year - 1  # Previous year if it's not December
    last_day = 25  # Consider only data up to 25th December of the previous year

# Define dynamic years and days range
start_year = 2015

# Retry decorator for network requests and file I/O
def retry_operation(func, retries=3, delay=2, backoff=True):
    for attempt in range(retries):
        try:
            return func()
        except Exception as e:
            if attempt < retries - 1:
                logging.warning(f"Attempt {attempt + 1} failed. Retrying... Error: {e}")
                if backoff:
                    time.sleep(delay * (2 ** attempt))
            else:
                logging.error(f"Failed after {retries} attempts. Error: {e}")
                return None

# Function to get the puzzle name for a specific day, with caching to minimize requests
def get_puzzle_name(day, year):
    url = f"https://adventofcode.com/{year}/day/{day}"
    
    cache_key = hashlib.md5(url.encode('utf-8')).hexdigest()
    cache_file = f'cache/{cache_key}.json'
    
    if os.path.exists(cache_file):
        logging.info(f"Using cached data for Year {year}, Day {day}")
        try:
            with open(cache_file, 'r') as cache:
                cached_data = json.load(cache)
            return cached_data.get('puzzle_name'), False
        except (json.JSONDecodeError, IOError) as e:
            logging.error(f"Error reading cached data for Year {year}, Day {day}: {e}")
            return None, False
    
    # Send HTTP request to get the page content with retry logic
    def fetch_puzzle_page():
        response = requests.get(url, timeout=10)
        response.raise_for_status()
        return response
    
    response = retry_operation(fetch_puzzle_page)
    if not response:
        return None, False
    
    soup = BeautifulSoup(response.content, 'html.parser')
    
    h2_tag = soup.find('h2')
    
    if h2_tag:
        h2_text = h2_tag.get_text(strip=True)
        
        start_index = h2_text.find(f"--- Day {day}: ") + 1
        end_index = h2_text.find(" ---")
        
        if start_index != -1 and end_index != -1:
            puzzle_name = h2_text[start_index:end_index]
            
            os.makedirs('cache', exist_ok=True)
            def save_cache():
                with open(cache_file, 'w') as cache:
                    json.dump({'puzzle_name': puzzle_name}, cache, indent=2)
                    file.write("\n")
            retry_operation(save_cache, retries=3, backoff=True)
            
            return puzzle_name.strip(), True
    
    logging.warning(f"Puzzle name not found for Day {day} of {year}.")
    return None, False

# Function to check if a specific puzzle name is missing or empty
def is_puzzle_missing(puzzles_data, year, day):
    return not puzzles_data.get(str(year), {}).get(str(day), "").strip()

# Function to update or create the JSON file
def update_json_file(filename="puzzles.json"):
    if not os.path.exists(filename):
        puzzles_data = {}
    else:
        def read_file():
            with open(filename, "r") as file:
                return json.load(file)
        puzzles_data = retry_operation(read_file, retries=3, backoff=True) or {}
    
    for year in range(start_year, end_year + 1):
        if str(year) not in puzzles_data:
            puzzles_data[str(year)] = {}
        
        for day in range(1, 26):
            if year == end_year and day > last_day:
                break
            
            if is_puzzle_missing(puzzles_data, year, day):
                logging.info(f"Fetching puzzle for Year {year}, Day {day}")
                puzzle_name, fetched_from_website = get_puzzle_name(day, year)
                if puzzle_name:
                    puzzles_data[str(year)][str(day)] = puzzle_name
                
                if fetched_from_website:
                    time.sleep(random.uniform(0.5, 1.5))
    
    def save_data():
        with open(filename, "w") as file:
            json.dump(puzzles_data, file, indent=2)
            file.write("\n")
    
    retry_operation(save_data, retries=3, backoff=True)
    logging.info(f"JSON file '{filename}' has been updated successfully.")

if __name__ == "__main__":
    update_json_file()
