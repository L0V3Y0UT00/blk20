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
read -p "Select a number to pick a file/folder: " choice

selected="${items[choice-1]}"
echo -e "\n${GREEN}You selected: $selected${NC}"

# Check if selected item is a directory
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
    echo -e "${GREEN}You picked file: $selected${NC}"
fi


#!/bin/bash

# ========== Styling ==========
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ========== Step 1: Let user select the file ==========
echo -e "${YELLOW}Available .txt files in current directory:${NC}"
txt_files=(*.txt)
if [[ ${#txt_files[@]} -eq 0 ]]; then
    echo -e "${RED}No .txt files found in the current directory.${NC}"
    exit 1
fi

for i in "${!txt_files[@]}"; do
    printf "%3d) %s\n" "$((i+1))" "${txt_files[i]}"
done

echo
read -p "Select a file number to use: " file_index
selected_file="${txt_files[file_index-1]}"

if [[ ! -f "$selected_file" ]]; then
    echo -e "${RED}Invalid file selection.${NC}"
    exit 1
fi

echo -e "${GREEN}You selected: $selected_file${NC}"

# ========== Step 2: Display file content with line numbers ==========
echo -e "\n${YELLOW}File contents (YouTube Shorts URLs):${NC}"
nl -w3 -s'. ' "$selected_file"

# ========== Step 3: Get range from user ==========
echo
read -p "Enter the line range to download (e.g., 20-45): " range_input

start=$(echo "$range_input" | cut -d'-' -f1)
end=$(echo "$range_input" | cut -d'-' -f2)

# Validate range
if ! [[ "$start" =~ ^[0-9]+$ && "$end" =~ ^[0-9]+$ && "$end" -ge "$start" ]]; then
    echo -e "${RED}Invalid range: $range_input${NC}"
    exit 1
fi

# ========== Step 4: Extract selected URLs ==========
selected_urls=$(sed -n "${start},${end}p" "$selected_file")

echo -e "\n${GREEN}Selected URLs to download (${start}-${end}):${NC}"
echo "$selected_urls"

# ========== Step 5: Download with yt-dlp ==========
echo -e "\n${YELLOW}Starting download using yt-dlp...${NC}"

if ! command -v yt-dlp &>/dev/null; then
    echo -e "${RED}yt-dlp not found. Please install it first.${NC}"
    exit 1
fi

# Create a temporary file
tmp_file=$(mktemp)
echo "$selected_urls" > "$tmp_file"

# Download
yt-dlp -o "%(title).80s.%(ext)s" -a "$tmp_file"

# Clean up
rm -f "$tmp_file"

echo -e "\n${GREEN}Download completed.${NC}"
