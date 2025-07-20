#!/bin/bash

# ========== Styling ==========
GREEN='\033[0;32m'
BLUE='\033[1;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ========== Time + Date ==========
current_time=$(date +"%Y-%m-%d %H:%M:%S")

# ========== Detection ==========
if [[ "$PREFIX" == *"com.termux"* || "$HOME" == "/data/data/com.termux/files/home" ]]; then
    environment="Termux"
else
    environment="Linux"
fi

echo -e "${BLUE}Detected Environment:${NC} ${GREEN}$environment${NC}"
echo -e "${YELLOW}Script started at:${NC} $current_time"

# ========== Termux Path ==========
if [[ "$environment" == "Termux" ]]; then
    echo -e "${YELLOW}Checking dependencies...${NC}"

    # Setup storage
    if [[ ! -d "/storage/emulated/0" ]]; then
        echo -e "${YELLOW}Setting up Termux storage access...${NC}"
        termux-setup-storage
        sleep 2
    fi

    # Install dependencies
    install_if_missing() {
        if ! command -v "$1" &>/dev/null; then
            echo -e "${YELLOW}Installing $1...${NC}"
            pkg update -y && pkg install -y "$1"
        fi
    }

    install_if_missing jq
    install_if_missing ffmpeg
    install_if_missing yt-dlp

    echo
    read -p "Enter the full video/profile/channel URL: " input_url
    domain=$(echo "$input_url" | awk -F/ '{print $3}' | sed 's/^www\.//')
    platform=$(echo "$domain" | cut -d'.' -f1)
    echo -e "${GREEN}Platform selected:${NC} $platform"

    if [[ "$platform" == "youtube" || "$platform" == "youtu" ]]; then
        echo -e "${GREEN}Extracting video URLs from YouTube channel...${NC}"
        channel_json=$(yt-dlp --flat-playlist --dump-single-json "$input_url")
        channel_title=$(echo "$channel_json" | jq -r '.title' | sed 's/[^a-zA-Z0-9_-]/_/g')
        output_file="@${channel_title}_shorts.txt"
        echo "$channel_json" | jq -r '.entries[].url' | sed 's|^/shorts/|https://www.youtube.com/shorts/|' > "$output_file"
        if [[ -s "$output_file" ]]; then
            count=$(wc -l < "$output_file")
            full_path=$(realpath "$output_file")
            echo -e "${GREEN}Saved $count videos to $output_file${NC}"
            echo -e "${YELLOW}Path:${NC} $full_path"
        else
            echo -e "${RED}No URLs found. Check the input URL.${NC}"
            exit 1
        fi
    fi

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

    if [[ ! -f "$file_selected" || "${file_selected##*.}" != "txt" ]]; then
        echo -e "${RED}The selected file is not a .txt file. Exiting.${NC}"
        exit 1
    fi

    echo -e "\n${YELLOW}File contents (Short video URLs):${NC}"
    nl -w3 -s'. ' "$file_selected"

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

    selected_urls=$(sed -n "${start},${end}p" "$file_selected")
    echo -e "\n${GREEN}Selected URLs to download (${start}-${end}):${NC}"
    echo "$selected_urls"

    download_dir="/storage/emulated/0/${range_label}_videos"
    mkdir -p "$download_dir"
    echo -e "\n${YELLOW}Videos will be saved to: $download_dir${NC}"

    tmp_file="/data/data/com.termux/files/usr/tmp/ytdl_urls.txt"
    echo "$selected_urls" > "$tmp_file"

    echo -e "\n${BLUE}Starting download at $(date +'%Y-%m-%d %H:%M:%S') in $environment environment...${NC}"
    yt-dlp -o "${download_dir}/%(title).80s.%(ext)s" -a "$tmp_file"
    rm -f "$tmp_file"
    echo -e "\n${GREEN}Download completed at $(date +'%Y-%m-%d %H:%M:%S'). Saved to '${download_dir}'${NC}"

else
    echo -e "${YELLOW}This is Linux. You can place your Linux-based script here.${NC}"
    echo -e "${BLUE}Start Time:${NC} $(date +'%Y-%m-%d %H:%M:%S')"
    # You can add a download block for Linux here
fi
