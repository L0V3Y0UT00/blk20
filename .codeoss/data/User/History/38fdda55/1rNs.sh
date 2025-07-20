#!/bin/bash

# ========== Styling ==========
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Listing items in the current directory:${NC}"
echo

# List all files and folders
items=(*)
for i in "${!items[@]}"; do
    printf "%3d) %s\n" "$((i+1))" "${items[i]}"
done

echo
read -p "Select a number to pick a file or folder: " choice

selected="${items[choice-1]}"
echo -e "\n${GREEN}You selected: $selected${NC}"

# Step 1: If directory, let user choose file inside it
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

# Step 2: Validate it's a .txt file
if [[ ! -f "$file_selected" || "${file_selected##*.}" != "txt" ]]; then
    echo -e "${RED}The selected file is not a .txt file. Exiting.${NC}"
    exit 1
fi

# Step 3: Display URLs with line numbers
echo -e "\n${YELLOW}File contents (YouTube Shorts URLs):${NC}"
nl -w3 -s'. ' "$file_selected"

# Step 4: Get user range
echo
read -p "Enter the line range to download (e.g., 20-45): " range_input

start=$(echo "$range_input" | cut -d'-' -f1)
end=$(echo "$range_input" | cut -d'-' -f2)

if ! [[ "$start" =~ ^[0-9]+$ && "$end" =~ ^[0-9]+$ && "$end" -ge "$start" ]]; then
    echo -e "${RED}Invalid range: $range_input${NC}"
    exit 1
fi

# Step 5: Extract and confirm URLs
selected_urls=$(sed -n "${start},${end}p" "$file_selected")

echo -e "\n${GREEN}Selected URLs to download (${start}-${end}):${NC}"
echo "$selected_urls"

# Step 6: Check for yt-dlp
if ! command -v yt-dlp &>/dev/null; then
    echo -e "${RED}yt-dlp not found. Please install it first.${NC}"
    exit 1
fi

# Step 7: Download using yt-dlp
echo -e "\n${YELLOW}Starting download using yt-dlp...${NC}"

tmp_file=$(mktemp)
echo "$selected_urls" > "$tmp_file"

yt-dlp -o "%(title).80s.%(ext)s" -a "$tmp_file"

rm -f "$tmp_file"

echo -e "\n${GREEN}Download completed.${NC}"
