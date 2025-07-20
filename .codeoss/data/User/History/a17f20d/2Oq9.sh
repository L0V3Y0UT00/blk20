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
