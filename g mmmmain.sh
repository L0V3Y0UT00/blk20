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
    STORAGE_DIR="$HOME/Downloads" # Default to ~/Downloads on Linux, can be customized
    TMP_DIR="/tmp"
    # Detect Linux package manager
    if command -v apt >/dev/null; then
        PKG_MANAGER="apt"
    elif command -v dnf >/dev/null; then
        PKG_MANAGER="dnf"
    elif command -v yum >/dev/null; then
        PKG_MANAGER="yum"
    else
        echo -e "${RED}No supported package manager found (apt, dnf, yum). Exiting.${NC}"
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
                apt)
                    sudo apt update && sudo apt install -y "$pkg"
                    ;;
                dnf|yum)
                    sudo $PKG_MANAGER install -y "$pkg"
                    ;;
            esac
        fi
    fi
}

# Install jq and ffmpeg
install_if_missing jq jq
install_if_missing ffmpeg ffmpeg

# Install yt-dlp (special handling)
if ! command -v yt-dlp &>/dev/null; then
    echo -e "${YELLOW}Installing yt-dlp...${NC}"
    if [[ $IS_TERMUX -eq 1 ]]; then
        pkg update -y && pkg install -y yt-dlp
    else
        # Try installing yt-dlp via pip, as it's often not in default Linux repos
        if ! command -v pip &>/dev/null; then
            echo -e "${RED}pip is required to install yt-dlp. Please install python3-pip.${NC}"
            exit 1
        fi
        pip install -U yt-dlp
    fi
fi

# ========== Prompt for Channel ==========
echo
read -p "Enter the full YouTube channel URL (or press Enter to skip): " channel_url

if [[ -n "$channel_url" ]]; then
    echo -e "${GREEN}Extracting video URLs from channel...${NC}"

    # Get channel JSON
    channel_json=$(yt-dlp --flat-playlist --dump-single-json "$channel_url")

    # Extract and sanitize title
    channel_title=$(echo "$channel_json" | jq -r '.title' | sed 's/[^a-zA-Z0-9_-]/_/g')
    output_file="@${channel_title}_shorts.txt"

    # Extract shorts URLs properly
    echo "$channel_json" | jq -r '.entries[].url' | sed 's|^/shorts/|https://www.youtube.com/shorts/|' > "$output_file"

    # Confirm extraction
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
    file_assignments="$selected"
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
download_dir="${STORAGE_DIR}/${range_label}_videos"
mkdir -p "$download_dir"
echo -e "\n${YELLOW}Videos will be saved to: $download_dir${NC}"

tmp_file="${TMP_DIR}/ytdl_urls.txt"
echo "$selected_urls" > "$tmp_file"

yt-dlp -o "${download_dir}/%(title).80s.%(ext)s" -a "$tmp_file"

rm -f "$tmp_file"
echo -e "\n${GREEN}Download completed. Saved to '${download_dir}'${NC}"
