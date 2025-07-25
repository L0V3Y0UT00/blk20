#!/bin/bash

# ========== Styling ==========
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ========== Environment Detection ==========
if [[ -d "/data/data/com.termux/files" ]]; then
    IS_TERMUX=1
    STORAGE_DIR="/storage/emulated/0"
    TMP_DIR="/data/data/com.termux/files/usr/tmp"
    PKG_MANAGER="pkg"
else
    IS_TERMUX=0
    STORAGE_DIR="$HOME/Downloads"
    TMP_DIR="/tmp"
    if command -v apt >/dev/null; then
        PKG_MANAGER="apt"
    elif command -v dnf >/dev/null; then
        PKG_MANAGER="dnf"
    elif command -v yum >/dev/null; then
        PKG_MANAGER="yum"
    else
        echo -e "${RED}No supported package manager found. Exiting.${NC}"
        exit 1
    fi
fi

echo -e "${YELLOW}Checking dependencies...${NC}"

# ========== Termux Storage Setup ==========
if [[ $IS_TERMUX -eq 1 && ! -d "$STORAGE_DIR" ]]; then
    echo -e "${YELLOW}Setting up Termux storage access...${NC}"
    termux-setup-storage
    sleep 2
fi

# ========== Install Dependencies ==========
install_if_missing() {
    local pkg=$1
    local termux_pkg=$2
    if ! command -v "$pkg" &>/dev/null; then
        echo -e "${YELLOW}Installing $pkg...${NC}"
        if [[ $IS_TERMUX -eq 1 ]]; then
            pkg update -y && pkg install -y "${termux_pkg:-$pkg}"
        else
            case $PKG_MANAGER in
                apt) sudo apt update && sudo apt install -y "$pkg" ;;
                dnf|yum) sudo $PKG_MANAGER install -y "$pkg" ;;
            esac
        fi
    fi
}

install_if_missing jq jq
install_if_missing ffmpeg ffmpeg

# yt-dlp via pip if needed
if ! command -v yt-dlp &>/dev/null; then
    echo -e "${YELLOW}Installing yt-dlp...${NC}"
    if [[ $IS_TERMUX -eq 1 ]]; then
        pkg install -y python && pip install -U yt-dlp
    else
        install_if_missing pip python3-pip
        pip install -U yt-dlp --user
        export PATH="$HOME/.local/bin:$PATH"
    fi
else
    echo -e "${YELLOW}Updating yt-dlp...${NC}"
    pip install -U yt-dlp --user
fi

# ========== URL Input ==========
echo
read -p "Enter YouTube/TikTok Channel URL or Username: " user_input

if [[ "$user_input" =~ ^[a-zA-Z0-9_.]+$ ]]; then
    final_url="https://www.tiktok.com/@$user_input"
    platform="tiktok"
elif [[ "$user_input" =~ ^https?://(www\.)?tiktok\.com/@[a-zA-Z0-9_.-]+$ ]]; then
    final_url="$user_input"
    platform="tiktok"
elif [[ "$user_input" =~ ^https?:// ]]; then
    final_url="$user_input"
    platform="youtube"
else
    echo -e "${RED}Invalid input.${NC}"
    exit 1
fi

# ========== Extract Playlist ==========
echo -e "${YELLOW}Extracting videos from $platform...${NC}"
channel_json=$(yt-dlp --flat-playlist --dump-single-json "$final_url" 2> yt-dlp-error.log)
if [[ $? -ne 0 ]]; then
    echo -e "${RED}yt-dlp failed:${NC}"
    cat yt-dlp-error.log
    exit 1
fi
rm -f yt-dlp-error.log
echo "$channel_json" > channel_json.txt

channel_title=$(echo "$channel_json" | jq -r '.title // "unknown_channel"' | sed 's/[^a-zA-Z0-9_-]/_/g')
output_file="@${channel_title}_shorts.txt"

urls=$(echo "$channel_json" | jq -r '.entries[]?.url // empty')
if [[ -z "$urls" ]]; then
    echo -e "${RED}No URLs found.${NC}"
    exit 1
fi

echo -e "\n${GREEN}Extracted URLs:${NC}"
indexed_urls=()
index=1
while IFS= read -r url; do
    if [[ "$platform" == "tiktok" ]]; then
        username=$(basename "$final_url")
        full_url="https://www.tiktok.com/$username/video/${url##*/}"
    else
        full_url="https://www.youtube.com/shorts/${url##*/}"
    fi
    printf "%3d) %s\n" "$index" "$full_url"
    indexed_urls+=("$full_url")
    ((index++))
done <<< "$urls"

printf "%s\n" "${indexed_urls[@]}" > "$output_file"
echo -e "${GREEN}\nSaved to $output_file${NC}"

# ========== File Picker ==========
echo -e "\n${YELLOW}Listing items in current directory:${NC}"
items=(*)
for i in "${!items[@]}"; do
    printf "%3d) %s\n" "$((i+1))" "${items[i]}"
done

echo
read -p "Select a number to pick a file or folder: " choice
selected="${items[choice-1]}"
echo -e "\n${GREEN}You selected: $selected${NC}"

if [[ -d "$selected" ]]; then
    echo -e "\n${YELLOW}Files in folder: $selected${NC}"
    files_in_folder=("$selected"/*)
    for i in "${!files_in_folder[@]}"; do
        printf "%3d) %s\n" "$((i+1))" "${files_in_folder[i]##*/}"
    done
    echo
    read -p "Pick a file number: " file_choice
    file_selected="${files_in_folder[file_choice-1]}"
else
    file_selected="$selected"
fi

[[ ! -f "$file_selected" || "${file_selected##*.}" != "txt" ]] && {
    echo -e "${RED}Invalid file selected.${NC}"
    exit 1
}

echo -e "\n${YELLOW}File contents:${NC}"
nl -w3 -s'. ' "$file_selected"

total_lines=$(wc -l < "$file_selected")
range_label=$(basename "$file_selected" .txt)

echo
read -p "Enter range (1-$total_lines) to download (e.g., 3-10): " range_input
start=$(echo "$range_input" | cut -d'-' -f1)
end=$(echo "$range_input" | cut -d'-' -f2)

if ! [[ "$start" =~ ^[0-9]+$ && "$end" =~ ^[0-9]+$ && "$end" -ge "$start" && "$start" -le "$total_lines" ]]; then
    echo -e "${RED}Invalid range: $range_input${NC}"
    exit 1
fi

selected_urls=$(sed -n "${start},${end}p" "$file_selected")
echo -e "\n${GREEN}Selected URLs:${NC}"
echo "$selected_urls"

download_dir="${STORAGE_DIR}/${range_label}_videos"
mkdir -p "$download_dir"
echo "$selected_urls" > "$TMP_DIR/ytdl_urls.txt"

yt-dlp -f "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]" -o "${download_dir}/%(title).80s.%(ext)s" -a "$TMP_DIR/ytdl_urls.txt"
rm -f "$TMP_DIR/ytdl_urls.txt"

echo -e "\n${GREEN}Download complete. Videos saved to:${NC} ${download_dir}"
