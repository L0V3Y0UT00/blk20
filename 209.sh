#!/bin/bash

# ========== Styling ==========
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ========== Environment Detection ==========
if [[ -d "/data/data/com.termux/files" ]]; then
    ENVIRONMENT="termux"
    STORAGE_DIR="/storage/emulated/0"
    TMP_DIR="/data/data/com.termux/files/usr/tmp"
else
    ENVIRONMENT="linux"
    STORAGE_DIR="$HOME"
    TMP_DIR="/tmp"
fi

echo -e "${YELLOW}Detected environment: $ENVIRONMENT${NC}"

# ========== Dependencies ==========
echo -e "${YELLOW}Checking dependencies...${NC}"
command -v yt-dlp >/dev/null 2>&1 || {
    echo -e "${RED}yt-dlp not found. Installing...${NC}"
    if [[ "$ENVIRONMENT" == "termux" ]]; then
        pkg update && pkg install -y python
        pip install yt-dlp
    else
        sudo apt update && sudo apt install -y python3-pip
        pip3 install yt-dlp
    fi
}

# ========== Prompt for TikTok or YouTube URL ==========
echo
read -p "Enter the full TikTok or YouTube channel/video URL: " user_input

if [[ "$user_input" =~ ^https?://(www\.)?tiktok\.com/@[^/]+/video/[0-9]+$ ]]; then
    platform="tiktok"
    final_url="$user_input"
elif [[ "$user_input" =~ ^https?://(www\.)?youtube\.com/@[^/]+/shorts/?$ || "$user_input" =~ ^https?://(www\.)?youtube\.com/(shorts|channel|c|user)/.*$ ]]; then
    platform="youtube"
    final_url="$user_input"
else
    echo -e "${RED}Invalid or unsupported URL. Please enter a proper TikTok or YouTube link.${NC}"
    exit 1
fi

# ========== Extract Playlist ==========
echo -e "${YELLOW}Extracting videos from: $final_url${NC}"
json=$(yt-dlp --flat-playlist --dump-single-json "$final_url" 2>/dev/null)

video_urls=($(echo "$json" | jq -r '.entries[].url'))
count=${#video_urls[@]}

if [[ $count -eq 0 ]]; then
    echo -e "${RED}No videos found or unsupported URL structure.${NC}"
    exit 1
fi

# ========== Save and Display URLs ==========
mkdir -p "$STORAGE_DIR/@shorts_links"
list_file="$STORAGE_DIR/@shorts_links/shorts_links.txt"

echo -e "${GREEN}Found $count videos. Saving list to:$NC $list_file"
: > "$list_file"
for i in "${!video_urls[@]}"; do
    index=$((i + 1))
    id="${video_urls[$i]}"
    if [[ "$platform" == "youtube" ]]; then
        echo "$index. https://www.youtube.com/shorts/$id" >> "$list_file"
    elif [[ "$platform" == "tiktok" ]]; then
        echo "$index. https://www.tiktok.com/@${final_url#*@}/video/$id" >> "$list_file"
    fi
done

cat "$list_file"

# ========== Prompt for Range ==========
echo
read -p "Enter range to download (e.g., 1-5): " range

IFS='-' read -r start end <<< "$range"
start=$((start < 1 ? 1 : start))
end=$((end > count ? count : end))

# ========== Download Selected Videos ==========
echo -e "${YELLOW}Downloading videos $start to $end...${NC}"
mkdir -p "$STORAGE_DIR/@${platform}_shorts_videos"

for ((i = start - 1; i < end; i++)); do
    id="${video_urls[$i]}"
    if [[ "$platform" == "youtube" ]]; then
        url="https://www.youtube.com/shorts/$id"
    else
        url="https://www.tiktok.com/@${final_url#*@}/video/$id"
    fi
    echo -e "${GREEN}Downloading: $url${NC}"
    yt-dlp -P "$STORAGE_DIR/@${platform}_shorts_videos" "$url"
done

echo -e "${GREEN}Done. Videos saved to:$NC $STORAGE_DIR/@${platform}_shorts_videos"
