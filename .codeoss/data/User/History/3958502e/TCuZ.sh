#!/bin/bash

# ========== Styling ==========
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Enter the full YouTube channel URL:${NC}"
read -r channel_url

# Check for yt-dlp
if ! command -v yt-dlp &>/dev/null; then
    echo -e "${RED}yt-dlp is not installed. Please install yt-dlp first.${NC}"
    exit 1
fi

# Check for jq
if ! command -v jq &>/dev/null; then
    echo -e "${RED}jq is required but not installed. Installing...${NC}"
    if command -v apt-get &>/dev/null; then
        sudo apt-get install -y jq
    elif command -v pkg &>/dev/null; then
        pkg install jq -y
    else
        echo -e "${RED}Could not install jq automatically. Please install it manually.${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}Extracting video URLs from channel...${NC}"

# Download JSON metadata to extract channel title and video URLs
channel_json=$(yt-dlp --flat-playlist --dump-single-json "$channel_url")

# Extract real channel title (safe for filename)
channel_title=$(echo "$channel_json" | jq -r '.title' | sed 's/[^a-zA-Z0-9_-]/_/g')

# Output filename
output_file="${channel_title}_shorts.txt"

# Extract video URLs and format properly
echo "$channel_json" \
| jq -r '.entries[].url' \
| awk '{
    if ($0 ~ /^https?:\/\//) {
        print $0
    } else {
        print "https://www.youtube.com/watch?v=" $0
    }
}' > "$output_file"

# Confirm result
if [[ -s "$output_file" ]]; then
    echo -e "${GREEN}Video URLs saved to ${output_file}${NC}"
    
    # Optional preview
    head -n 5 "$output_file"

    # Total count
    count=$(wc -l < "$output_file")

    # Full path
    full_path=$(realpath "$output_file")

    echo -e "${GREEN}Saved $count videos from ${channel_title} to ${output_file}${NC}"
    echo -e "${YELLOW}Path:${NC} $full_path"
else
    echo -e "${RED}No URLs found. Please check the channel URL.${NC}"
fi
