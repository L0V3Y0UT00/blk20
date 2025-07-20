#!/bin/bash

# Extract all video URLs (including Shorts) from a YouTube channel
# Dependencies: yt-dlp, jq

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

# Extract channel name (cleaned for filename)
channel_name=$(basename "$channel_url" | sed 's|/shorts||' | sed 's|@||g')
output_file="${channel_name}_shorts.txt"

echo -e "${GREEN}Extracting video URLs from channel...${NC}"

yt-dlp --flat-playlist --dump-single-json "$channel_url" \
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
    
    # Preview all URLs
    cat "$output_file"

    # Count total
    count=$(wc -l < "$output_file")

    # Full path
    full_path=$(realpath "$output_file")

    echo -e "${GREEN}Saved $count videos from ${channel_name} to ${output_file}${NC}"
    echo -e "${YELLOW}Path:${NC} $full_path"
else
    echo -e "${RED}No URLs found. Please check the channel URL.${NC}"
fi
