#!/bin/bash

# Dependencies: yt-dlp, jq

# ========== Styling ==========
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ========== Input ==========
echo -e "${YELLOW}Enter the full YouTube channel URL:${NC}"
read -r channel_url

# Sanitize URL: Replace /shorts with /videos if present
channel_url=$(echo "$channel_url" | sed 's/\/shorts/\/videos/')

# ========== Dependency Checks ==========
if ! command -v yt-dlp &>/dev/null; then
    echo -e "${RED}yt-dlp is not installed. Please install yt-dlp first.${NC}"
    exit 1
fi

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

# ========== Start Extraction ==========
echo -e "${GREEN}Extracting all video IDs...${NC}"

video_ids=$(yt-dlp --flat-playlist --dump-single-json "$channel_url" | jq -r '.entries[].url')

if [ -z "$video_ids" ]; then
    echo -e "${RED}No video IDs found. Please check the channel URL.${NC}"
    exit 1
fi

# Clear output files
> urls.txt
> shorts.txt

echo -e "${GREEN}Analyzing videos... (this may take a while)${NC}"
short_count=0
total_count=0

# ========== Process Each Video ==========
while IFS= read -r video_id; do
    # Handle full URLs or just IDs
    if [[ "$video_id" =~ ^https?:// ]]; then
        full_url="$video_id"
    else
        full_url="https://www.youtube.com/watch?v=$video_id"
    fi

    echo "$full_url" >> urls.txt
    ((total_count++))

    # Get video duration in seconds
    duration=$(yt-dlp -j "$full_url" | jq -r '.duration // empty')

    # If duration exists and is ≤ 60, consider it a Short
    if [[ -n "$duration" && "$duration" -le 60 ]]; then
        echo "$full_url" >> shorts.txt
        ((short_count++))
    fi
done <<< "$video_ids"

# ========== Summary ==========
echo -e "${GREEN}Done! Total videos found: $total_count${NC}"
echo -e "${YELLOW}Shorts found: $short_count${NC}"

if [[ -s shorts.txt ]]; then
    echo -e "${GREEN}Shorts URLs saved to shorts.txt${NC}"
    echo -e "${YELLOW}Preview (first 5 Shorts):${NC}"
    head -n 5 shorts.txt
else
    echo -e "${RED}No Shorts detected (duration ≤ 60s).${NC}"
fi
