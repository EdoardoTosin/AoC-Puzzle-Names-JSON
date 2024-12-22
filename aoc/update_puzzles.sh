#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

# Log function with levels
log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo "$timestamp [$level] - $message" >&2
}

# Parse command line arguments
while getopts "o:c:" opt; do
    case "$opt" in
        o) OUTPUT_FILE="$OPTARG" ;;
        c) CACHE_DIR="$OPTARG" ;;
        *) log "ERROR" "Invalid option" && exit 1 ;;
    esac
done

# Default values
OUTPUT_FILE="${OUTPUT_FILE:-puzzles.json}"
CACHE_DIR="${CACHE_DIR:-cache}"

# Check for required tools
check_tools() {
    local missing_tools=()
    local installed_tools=()
    
    for tool in "${REQUIRED_TOOLS[@]}"; do
        if command -v "$tool" &>/dev/null; then
            installed_tools+=("$tool")
        else
            missing_tools+=("$tool")
        fi
    done
    
    if [[ "${#missing_tools[@]}" -ne 0 ]]; then
        log "ERROR" "The following required tools are missing: ${missing_tools[*]}"
        log "INFO" "You can install them using: sudo apt install ${missing_tools[*]}"
        exit 1
    fi
    
    # Join installed tools with a space and log them in a single line
    local tools_list
    tools_list=$(IFS=' ' ; echo "${installed_tools[*]}")
    log "INFO" "The following tools are installed: $tools_list"
}

# Define constant variables
declare -r TIMEZONE="America/New_York"
declare -r START_YEAR=2015
declare -r OUTPUT_FILE="${OUTPUT_FILE:-puzzles.json}"
declare -r CACHE_DIR="${CACHE_DIR:-cache}"
declare -r REQUIRED_TOOLS=("curl" "jq" "gawk")

# Define the current date in UTC-5 (EST)
current_date=$(TZ="$TIMEZONE" date +"%Y-%m-%d")
current_year=$(TZ="$TIMEZONE" date +"%Y")
current_month=$(TZ="$TIMEZONE" date +"%m")
current_day=$(TZ="$TIMEZONE" date +"%d")

# Determine the valid year and last valid day
if [[ "$current_month" -eq 12 && "$current_day" -le 25 ]]; then
    end_year="$current_year"
    last_day="$current_day"
elif [[ "$current_month" -eq 12 && "$current_day" -gt 25 ]]; then
    end_year="$current_year"
    last_day=25
else
    end_year=$((current_year - 1))
    last_day=25
fi

mkdir -p "$CACHE_DIR"

# Retry function
retry() {
    local retries=$1
    local delay=$2
    shift 2
    local count=0
    until "$@"; do
        count=$((count + 1))
        if [[ "$count" -ge "$retries" ]]; then
            log "ERROR" "Command failed after $count attempts: $*"
            return 1
        fi
        log "WARN" "Retry $count/$retries for: $*"
        sleep "$delay"
    done
}

# Get puzzle name function
get_puzzle_name() {
    local day=$1
    local year=$2
    local url="https://adventofcode.com/${year}/day/${day}"
    local cache_key
    local cache_file
    cache_key=$(echo -n "$url" | md5sum | cut -d' ' -f1)
    cache_file="${CACHE_DIR}/${cache_key}.json"
    
    if [[ -f "$cache_file" ]]; then
        # Using cached data, no sleep needed
        log "INFO" "Using cached data for Year $year, Day $day"
        jq -r '.puzzle_name' "$cache_file" || {
            log "ERROR" "Failed to parse cached puzzle name for Year $year, Day $day"
            return 1
        }
        return
    fi
    
    # Fetch data from the URL
    local response
    response=$(retry 3 2 curl -sSL "$url" || { log "ERROR" "Failed to fetch puzzle for Year $year, Day $day"; return 1; })
    
    # Extract puzzle name from the response
    local puzzle_name
    puzzle_name=$(echo "$response" | grep -oP "(?<=--- Day $day: ).*(?= ---)")
    
    if [[ -n "$puzzle_name" ]]; then
        # Save the puzzle name to the cache file
        echo "{\"puzzle_name\": \"$puzzle_name\"}" >"$cache_file"
        log "INFO" "Puzzle name for Year $year, Day $day: $puzzle_name"
        echo "$puzzle_name"

        # Apply sleep after fetching data from the web
        sleep "$(awk -v min=0.5 -v max=1.5 'BEGIN{srand(); print min+rand()*(max-min)}')"
    else
        log "ERROR" "Puzzle name not found for Year $year, Day $day."
        echo ""  # Return an empty string if no puzzle name found
    fi
}

# Check if puzzle name is missing in JSON
is_puzzle_missing() {
    local json_data=$1
    local year=$2
    local day=$3
    [[ -z $(echo "$json_data" | jq -r --arg year "$year" --arg day "$day" '.[$year][$day] // empty') ]]
}

# Update puzzles JSON file
update_json_file() {
    local json_data
    if [[ -f "$OUTPUT_FILE" ]]; then
        json_data=$(<"$OUTPUT_FILE")
    else
        json_data="{}"
    fi
    
    for ((year = START_YEAR; year <= end_year; year++)); do
        for ((day = 1; day <= 25; day++)); do
            if [[ "$year" -eq "$end_year" && "$day" -gt "$last_day" ]]; then
                break
            fi

            if is_puzzle_missing "$json_data" "$year" "$day"; then
                log "INFO" "Fetching puzzle for Year $year, Day $day"
                puzzle_name=$(get_puzzle_name "$day" "$year")

                if [[ -n "$puzzle_name" ]]; then
                    # Store the puzzle name in the JSON file
                    json_data=$(echo "$json_data" | jq --arg year "$year" --arg day "$day" --arg name "$puzzle_name" \
                        '.[$year][$day] = $name')
                fi
            fi
        done
    done
    
    # Write the updated JSON data to the output file
    echo "$json_data" | jq '.' >"$OUTPUT_FILE"
    log "INFO" "JSON file '$OUTPUT_FILE' has been updated successfully."
}

# Main script
check_tools
update_json_file
