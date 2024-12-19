# Advent of Code Puzzle Names JSON

[![Update AoC JSON](https://github.com/EdoardoTosin/AoC-Puzzle-Names-JSON/actions/workflows/update-aoc-json.yml/badge.svg?branch=main)](https://github.com/EdoardoTosin/AoC-Puzzle-Names-JSON/actions/workflows/update-aoc-json.yml)

This repository contains a script that dynamically fetches the puzzle names for all Advent of Code challenges starting from 2015. The output is stored in a JSON file named [`puzzles.json`](https://raw.githubusercontent.com/EdoardoTosin/AoC-Puzzle-Names-JSON/refs/heads/main/puzzles.json).

## Features

- Fetches puzzle names from the Advent of Code website using the structure of the `h2` tags on each day's page.
- Caches puzzle names to minimize server load and reduce the number of requests to the origin server.
- Checks for missing or empty puzzle names and only fetches missing data.
- Updates the [`puzzles.json`](https://raw.githubusercontent.com/EdoardoTosin/AoC-Puzzle-Names-JSON/refs/heads/main/puzzles.json) file to ensure all puzzle names are present and up-to-date based on the current date.
- Automatically called via a GitHub Actions workflow to keep the JSON file updated.

## Output

The script generates or updates a file named [`puzzles.json`](https://raw.githubusercontent.com/EdoardoTosin/AoC-Puzzle-Names-JSON/refs/heads/main/puzzles.json) in the following structure:

```json
{
  "2015": {
    "1": "Not Quite Lisp",
    "2": "I Was Told There Would Be No Math",
    ...
    "25": "Let It Snow"
  },
  "2016": {
    "1": "No Time for a Taxicab",
    ...
  },
  ...
  "2024": {
    "1": "Historian Hysteria",
    ...
  }
}
```

## GitHub Workflow

The repository includes a GitHub Actions workflow that:

1. Automatically runs the script daily from December 1st to December 25th, or until the last valid day for the current year.
2. Fetches any missing puzzle names for past years and updates the [`puzzles.json`](https://raw.githubusercontent.com/EdoardoTosin/AoC-Puzzle-Names-JSON/refs/heads/main/puzzles.json) file.
3. Commits and pushes changes back to the repository to keep the puzzle names up-to-date.

## Script Logic

- **Dynamic Year Range**: The script automatically determines the valid year range based on the current date. If the current date is before **25th December**, it will check puzzle names up to the current date. If it's after **25th December**, it will only check up to **25th December** of the current year.
- **Efficient Fetching**: The script will only fetch missing puzzle names (i.e., missing or empty entries for specific days) and will not re-fetch the entire dataset if it's already complete.
- **Caching**: Puzzle data is cached locally to reduce requests to the origin server, speeding up subsequent script runs and reducing the server load.

## Usage

If you'd like to run the script locally:

1. Clone the repository:
   ```bash
   git clone https://github.com/EdoardoTosin/AoC-Puzzle-Names-JSON
   cd AoC-Puzzle-Names-JSON
   ```

2. Install the required Python packages:
   ```bash
   pip install -r requirements.txt
   ```

3. Run the script:
   ```bash
   python src/fetch_aoc_puzzle_names.py
   ```

## Contributing

Contributions to improve the script or workflow are welcome! Please submit a pull request with your changes.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
