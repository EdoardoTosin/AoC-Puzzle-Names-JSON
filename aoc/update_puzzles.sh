#!/usr/bin/env bash

set -euo pipefail

readonly OUTPUT_FILE="${OUTPUT_FILE:-puzzles.json}"
readonly CACHE_DIR="${CACHE_DIR:-cache}"
readonly START_YEAR=2015

# Get current date in EST
current_date=$(TZ=America/New_York date)
current_year=$(date -d "$current_date" +%Y)
current_month=$((10#$(date -d "$current_date" +%m)))
current_day=$((10#$(date -d "$current_date" +%d)))

# Determine end year and last valid day
if [[ $current_month -eq 12 && $current_day -le 25 ]]; then
    end_year=$current_year
    last_day=$current_day
else
    end_year=$((current_year - 1))
    last_day=25
fi

mkdir -p "$CACHE_DIR"

log() { echo "$(date '+%H:%M:%S') [$1] $2" >&2; }

get_puzzle_name() {
    local day=$1 year=$2
    local cache_file="$CACHE_DIR/${year}_${day}.txt"
    
    # Return cached result if exists
    [[ -f "$cache_file" ]] && { cat "$cache_file"; return; }
    
    # Fetch with retry and rate limiting
    local url="https://adventofcode.com/$year/day/$day"
    local puzzle_name
    
    for attempt in {1..3}; do
        if puzzle_name=$(curl -sSL --max-time 10 "$url" | 
                         grep -oP "(?<=--- Day $day: ).*(?= ---)" | head -1); then
            [[ -n "$puzzle_name" ]] && {
                echo "$puzzle_name" | tee "$cache_file"
                sleep 0.$((RANDOM % 10 + 5))  # 0.5-1.4s random delay
                return
            }
        fi
        [[ $attempt -lt 3 ]] && sleep $((attempt * 2))
    done
    
    log "WARN" "Failed to fetch puzzle for $year day $day"
    return 1
}

# Initialize or load existing JSON
json_data=$([ -f "$OUTPUT_FILE" ] && cat "$OUTPUT_FILE" || echo "{}")

log "INFO" "Processing years $START_YEAR-$end_year, up to day $last_day"

for year in $(seq $START_YEAR $end_year); do
    max_day=$([ $year -eq $end_year ] && echo $last_day || echo 25)
    
    for day in $(seq 1 $max_day); do
        # Skip if puzzle already exists
        existing=$(echo "$json_data" | jq -r --arg y "$year" --arg d "$day" '.[$y][$d] // empty')
        [[ -n "$existing" ]] && continue
        
        log "INFO" "Fetching $year day $day"
        if puzzle_name=$(get_puzzle_name "$day" "$year"); then
            json_data=$(echo "$json_data" | jq --arg y "$year" --arg d "$day" --arg n "$puzzle_name" \
                '.[$y][$d] = $n')
        fi
    done
done

# Save updated JSON
echo "$json_data" | jq --indent 2 \
    'to_entries | sort_by(.key) | map(.value |= (to_entries | sort_by(.key|tonumber) | from_entries)) | from_entries' \
    > "$OUTPUT_FILE"

log "INFO" "Updated $OUTPUT_FILE successfully"
