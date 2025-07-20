#!/bin/bash

# Dependencies: yt-dlp, jq

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

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

echo -e "${GREEN}Extracting all video IDs...${NC}"

video_ids=$(yt-dlp --flat-playlist --dump-single-json "$channel_url" | jq -r '.entries[].url')

if [ -z "$video_ids" ]; then
    echo -e "${RED}No video IDs found. Please check the channel URL.${NC}"
    exit 1
fi

> urls.txt
> shorts.txt

echo -e "${GREEN}Analyzing videos... (this may take a while)${NC}"

short_count=0

while IFS= read -r video_id; do
    full_url="https://www.youtube.com/watch?v=$video_id"
    duration=$(yt-dlp -j "$full_url" | jq -r '.duration // 0')
    
    echo "$full_url" >> urls.txt

    if [ "$duration" -le 60 ]; then
        echo "$full_url" >> shorts.txt
        ((short_count++))
    fi
done <<< "$video_ids"

echo -e "${GREEN}All video URLs saved to urls.txt${NC}"
echo -e "${YELLOW}Total Shorts found: $short_count${NC}"

if [[ -s shorts.txt ]]; then
    echo -e "${GREEN}Shorts URLs saved to shorts.txt${NC}"
    echo -e "${YELLOW}Preview (first 5 Shorts):${NC}"
    head -n 5 shorts.txt
else
    echo -e "${RED}No Shorts detected based on duration <= 60 seconds.${NC}"
fi
