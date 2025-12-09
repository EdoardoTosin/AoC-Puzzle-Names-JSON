#!/usr/bin/env bash

set -euo pipefail

readonly OUTPUT_FILE="${OUTPUT_FILE:-puzzles.json}"
readonly CACHE_DIR="${CACHE_DIR:-cache}"
readonly START_YEAR=2015
readonly MAX_FETCH_ATTEMPTS=3

mkdir -p "$CACHE_DIR"

log() { echo "$(date '+%H:%M:%S') [$1] $2" >&2; }

# Fetch and cache the maximum available day for an AoC year.
get_max_day_for_year() {
    local year="$1"
    local cache_file="$CACHE_DIR/${year}_max_day.txt"

    if [[ -f "$cache_file" ]]; then
        cat "$cache_file"
        return
    fi

    local url="https://adventofcode.com/$year"
    local content="" max_day=25

    for attempt in $(seq 1 "$MAX_FETCH_ATTEMPTS"); do
        if content=$(curl -sSL --max-time 10 "$url"); then
            # Extract day numbers from href="/YEAR/day/N" inside <a> tags
            max_day=$(echo "$content" \
                | grep -oP "<a[^>]+href=\"/$year/day/\K[0-9]+(?=\")" \
                | sort -n | tail -1 || echo 25)

            [[ "$max_day" =~ ^[0-9]+$ ]] || max_day=25

            echo "$max_day" | tee "$cache_file"
            sleep 0.$((RANDOM % 10 + 5))
            return
        fi
        [[ "$attempt" -lt "$MAX_FETCH_ATTEMPTS" ]] && sleep $((attempt * 2))
    done

    log "WARN" "Failed to detect max day for $year; defaulting to 25"
    echo 25 | tee "$cache_file"
}

get_puzzle_name() {
    local day="$1" year="$2"
    local cache_file="$CACHE_DIR/${year}_${day}.txt"

    [[ -f "$cache_file" ]] && { cat "$cache_file"; return; }

    local url="https://adventofcode.com/$year/day/$day"
    local puzzle_name=""

    for attempt in $(seq 1 "$MAX_FETCH_ATTEMPTS"); do
        if puzzle_name=$(curl -sSL --max-time 10 "$url" |
                         grep -oP "(?<=--- Day $day: ).*(?= ---)" |
                         head -1 ); then
            if [[ -n "$puzzle_name" ]]; then
                echo "$puzzle_name" | tee "$cache_file"
                sleep 0.$((RANDOM % 10 + 5))
                return
            fi
        fi
        [[ "$attempt" -lt "$MAX_FETCH_ATTEMPTS" ]] && sleep $((attempt * 2))
    done

    log "WARN" "Failed to fetch puzzle for $year day $day"
    return 1
}

# Determine cutoffs based on EST time
current_date=$(TZ=America/New_York date)
current_year=$(date -d "$current_date" +%Y)
current_month=$((10#$(date -d "$current_date" +%m)))
current_day=$((10#$(date -d "$current_date" +%d)))

if [[ $current_month -eq 12 ]]; then
    end_year=$current_year
else
    end_year=$((current_year - 1))
fi

json_data=$([ -f "$OUTPUT_FILE" ] && cat "$OUTPUT_FILE" || echo "{}")

log "INFO" "Processing years $START_YEAR-$end_year"

for year in $(seq "$START_YEAR" "$end_year"); do
    year_max_day=$(get_max_day_for_year "$year")

    # For the current year, limit days to the present date
    if [[ "$year" -eq "$current_year" ]]; then
        year_max_day=$(( current_month == 12 ? current_day : 0 ))
        (( year_max_day < 1 )) && continue
    fi

    log "INFO" "Year $year: detected $year_max_day available puzzles"

    for day in $(seq 1 "$year_max_day"); do
        existing=$(echo "$json_data" | jq -r --arg y "$year" --arg d "$day" '.[$y][$d] // empty')
        [[ -n "$existing" ]] && continue

        log "INFO" "Fetching $year day $day"
        if puzzle_name=$(get_puzzle_name "$day" "$year"); then
            json_data=$(echo "$json_data" | jq \
                --arg y "$year" --arg d "$day" --arg n "$puzzle_name" \
                '.[$y][$d] = $n')
        fi
    done
done

echo "$json_data" |
    jq --indent 2 \
        'to_entries
        | sort_by(.key)
        | map(.value |= (to_entries | sort_by(.key|tonumber) | from_entries))
        | from_entries' \
    > "$OUTPUT_FILE"

log "INFO" "Updated $OUTPUT_FILE successfully"
