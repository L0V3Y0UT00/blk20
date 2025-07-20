#!/bin/bash

# Requirements: yt-dlp, jq

# ===== Styling =====
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ===== Input from user =====
echo -e "${YELLOW}Enter the YouTube channel handle (e.g., @TechnoMindHindi-r9u):${NC}"
read -r handle

# Sanitize input (strip leading URL or trailing /shorts)
handle=$(echo "$handle" | sed -E 's#^https?://(www\.)?youtube\.com/##' | sed 's|/shorts||')

# ===== Check for yt-dlp =====
if ! command -v yt-dlp &>/dev/null; then
    echo -e "${RED}yt-dlp is not installed. Please install it to continue.${NC}"
    exit 1
fi

# ===== Check for jq =====
if ! command -v jq &>/dev/null; then
    echo -e "${RED}jq is not installed. Please install it to continue.${NC}"
    exit 1
fi

# ===== Construct Shorts URL =====
shorts_url="https://www.youtube.com/${handle}/shorts"
echo -e "${GREEN}Fetching video URLs from:${NC} $shorts_url"

# ===== Extract video URLs only =====
yt-dlp --flat-playlist -J "$shorts_url" 2>/dev/null \
  | jq -r '.entries[].url' \
  | sed 's_^_https://www.youtube.com/watch?v=_'

# ===== Done =====
echo -e "${GREEN}Done listing Shorts video URLs.${NC}"
