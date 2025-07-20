#!/bin/bash

# ========== Styling ==========
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Checking environment...${NC}"

# ========== Environment Detection ==========
if [[ "$PREFIX" == *"com.termux"* || "$HOME" == "/data/data/com.termux/files/home" ]]; then
    ENVIRONMENT="termux"
    echo -e "${GREEN}Detected Termux environment.${NC}"
else
    ENVIRONMENT="linux"
    echo -e "${GREEN}Detected Linux environment.${NC}"
fi

# ========== Setup storage for Termux ==========
if [[ "$ENVIRONMENT" == "termux" && ! -d "/storage/emulated/0" ]]; then
    echo -e "${YELLOW}Setting up Termux storage access...${NC}"
    if command -v termux-setup-storage &>/dev/null; then
        termux-setup-storage
        sleep 2
    else
        echo -e "${RED}termux-setup-storage not found. Are you using Termux?${NC}"
        exit 1
    fi
fi

# ========== Install dependencies ==========
install_if_missing() {
    if ! command -v "$1" &>/dev/null; then
        echo -e "${YELLOW}Installing $1...${NC}"
        if [[ "$ENVIRONMENT" == "termux" ]]; then
            pkg update -y && pkg install -y "$1"
        else
            sudo apt update -y && sudo apt install -y "$1"
        fi
    fi
}

install_if_missing jq
install_if_missing ffmpeg
install_if_missing yt-dlp

# ========== Prompt for channel ==========
echo
read -p "Enter the full YouTube channel URL (or press Enter to skip): " channel_url

if [[ -n "$channel_url" ]]; then
    # Auto-correct /shorts or /videos links
    channel_url=$(echo "$channel_url" | sed 's|/shorts$||' | sed 's|/videos$||')

    echo -e "${GREEN}Extracting video URLs from channel...${NC}"
    channel_json=$(yt-dlp --flat-playlist --dump-single-json "$channel_url")

    channel_title=$(echo "$channel_json" | jq -r '.title' | sed 's/[^a-zA-Z0-9_-]/_/g')
    output_file="@${channel_title}_shorts.txt"

    echo "$channel_json" | jq -r '.entries[].url' | sed 's|^/shorts/|https://www.youtube.com/shorts/|' > "$output_file"

    if [[ -s "$output_file" ]]; then
        count=$(wc -l < "$output_file")
        full_path=$(realpath "$output_file")
        echo -e "${GREEN}Video URLs saved to ${output_file}${NC}"
        echo -e "${GREEN}Saved $count videos to ${output_file}${NC}"
        echo -e "${YELLOW}Path:${NC} $full_path"
    else
        echo -e "${RED}No URLs found. Please check the channel URL.${NC}"
        exit 1
    fi
fi

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

# If folder, pick file inside
if [[ -d "$selected" ]]; then
    echo -e "\n${YELLOW}Listing files in folder: $selected${NC}"
    files_in_folder=("$selected"/*)
    if [[ ${#files_in_folder[@]} -eq 0 ]]; then
        echo -e "${RED}No files found in the folder.${NC}"
        exit 1
    fi
    for i in "${!files_in_folder[@]}"; do
        printf "%3d) %s\n" "$((i+1))" "${files_in_folder[i]##*/}"
    done
    echo
    read -p "Select a number to pick a file from the folder: " file_choice
    file_selected="${files_in_folder[file_choice-1]}"
    echo -e "\n${GREEN}You picked file: $file_selected${NC}"
else
    file_selected="$selected"
    echo -e "${GREEN}You picked file: $file_selected${NC}"
fi

# Validate file
if [[ ! -f "$file_selected" || "${file_selected##*.}" != "txt" ]]; then
    echo -e "${RED}The selected file is not a .txt file. Exiting.${NC}"
    exit 1
fi

# Show content
echo -e "\n${YELLOW}File contents (YouTube Shorts URLs):${NC}"
nl -w3 -s'. ' "$file_selected"

# Ask for range
total_lines=$(wc -l < "$file_selected")
range_label=$(basename "$file_selected" .txt)

echo
read -p "Enter ${range_label} video range (1-$total_lines) to download (e.g., 5-15): " range_input

start=$(echo "$range_input" | cut -d'-' -f1)
end=$(echo "$range_input" | cut -d'-' -f2)

if ! [[ "$start" =~ ^[0-9]+$ && "$end" =~ ^[0-9]+$ && "$end" -ge "$start" && "$start" -le "$total_lines" ]]; then
    echo -e "${RED}Invalid range: $range_input${NC}"
    exit 1
fi

# Extract selected URLs
selected_urls=$(sed -n "${start},${end}p" "$file_selected")
echo -e "\n${GREEN}Selected URLs to download (${start}-${end}):${NC}"
echo "$selected_urls"

# ========== Download ==========
if [[ "$ENVIRONMENT" == "termux" ]]; then
    download_dir="/storage/emulated/0/${range_label}_videos"
    tmp_file="/data/data/com.termux/files/usr/tmp/ytdl_urls.txt"
else
    download_dir="$HOME/${range_label}_videos"
    tmp_file="/tmp/ytdl_urls.txt"
fi

mkdir -p "$download_dir"
echo "$selected_urls" > "$tmp_file"

echo -e "\n${YELLOW}Videos will be saved to: $download_dir${NC}"
yt-dlp -o "${download_dir}/%(title).80s.%(ext)s" -a "$tmp_file"

rm -f "$tmp_file"
echo -e "\n${GREEN}Download completed. Saved to '${download_dir}'${NC}"
