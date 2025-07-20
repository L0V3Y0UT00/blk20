#!/bin/bash

# Dependencies: yt-dlp, jq

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ========= Get Channel Handle =========
echo -e "${YELLOW}Enter the YouTube channel handle (e.g., @TechnoMindHindi-r9u):${NC}"
read -r handle

# ========= Validate yt-dlp =========
if ! command -v yt-dlp &>/dev/null; then
    echo -e "${RED}yt-dlp is not installed. Please install yt-dlp first.${NC}"
    exit 1
fi

# ========= Validate jq =========
if ! command -v jq &>/dev/null; then
    echo -e "${RED}jq is not installed. Please install jq to continue.${NC}"
    exit 1
fi

# ========= Get Channel ID from Handle =========
echo -e "${GREEN}Fetching channel ID from handle...${NC}"

channel_id=$(yt-dlp -j "https://www.youtube.com/$handle" | jq -r .channel_id)

if [[ -z "$channel_id" || "$channel_id" == "null" ]]; then
    echo -e "${RED}Failed to extract channel ID. Please check the handle.${NC}"
    exit 1
fi

echo -e "${GREEN}Channel ID: $channel_id${NC}"

# ========= Construct Shorts Playlist URL =========
shorts_playlist_url="https://www.youtube.com/playlist?list=${channel_id}-shorts"

echo -e "${GREEN}Fetching Shorts from:${NC} $shorts_playlist_url"

# ========= Extract Shorts URLs =========
yt-dlp --flat-playlist --dump-single-json "$shorts_playlist_url" 2>/dev/null \
| jq -r '.entries[].url' \
| awk '{ print "https://www.youtube.com/watch?v=" $0 }' > shorts.txt

# ========= Confirm and Preview =========
if [[ -s shorts.txt ]]; then
    count=$(wc -l < shorts.txt)
    echo -e "${GREEN}Successfully extracted $count Shorts URLs.${NC}"
    echo -e "${YELLOW}Preview (first 5 URLs):${NC}"
    head -n 5 shorts.txt
else
    echo -e "${RED}No Shorts found or playlist is empty.${NC}"
fi
