#!/bin/bash

# Requirements: yt-dlp, jq

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

# ========== Input ==========
echo -e "${YELLOW}Enter the YouTube channel handle (e.g., @TechnoMindHindi-r9u):${NC}"
read -r handle

# Strip extra parts like "/shorts" or full URL
handle=$(echo "$handle" | sed -E 's#^https://www\.youtube\.com/##' | cut -d'/' -f1)

# ========== Dependency Checks ==========
if ! command -v yt-dlp &>/dev/null; then
    echo -e "${RED}yt-dlp is not installed. Please install it first.${NC}"
    exit 1
fi

if ! command -v jq &>/dev/null; then
    echo -e "${RED}jq is not installed. Please install it first.${NC}"
    exit 1
fi

# ========== Fetch Channel ID ==========
echo -e "${GREEN}Getting channel ID from handle $handle...${NC}"

channel_id=$(yt-dlp -j "https://www.youtube.com/$handle" 2>/dev/null | jq -r '.channel_id')

if [[ -z "$channel_id" || "$channel_id" == "null" ]]; then
    echo -e "${RED}Could not get channel ID. Please check the handle.${NC}"
    exit 1
fi

echo -e "${GREEN}Channel ID: $channel_id${NC}"

# ========== Build Shorts Playlist URL ==========
playlist_url="https://www.youtube.com/playlist?list=${channel_id}-shorts"
echo -e "${GREEN}Fetching Shorts playlist from:${NC} $playlist_url"

# ========== Extract & Print Shorts URLs ==========
yt-dlp --flat-playlist -J "$playlist_url" 2>/dev/null \
  | jq -r '.entries[].url' \
  | sed 's_^_https://www.youtube.com/watch?v=_'

echo -e "${GREEN}Done.${NC}"
