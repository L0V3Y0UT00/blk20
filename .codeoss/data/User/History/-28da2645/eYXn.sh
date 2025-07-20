#!/bin/bash

# Bulk Video Downloader Script using yt-dlp
# Version: 0.20
# Author: Ans Raza (0xAnsR)

# -----------------------------------------------
# Part 1: Color and Formatting Definitions
# -----------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# -----------------------------------------------
# Part 2: Header Display
# -----------------------------------------------
header() {
    clear
    echo -e "${BLUE}=============================================${NC}"
    echo -e "${BOLD}       BULK VIDEO DOWNLOADER TOOL ${NC}"
    echo -e "               ${YELLOW}By Ans Raza (0xAnsR)${NC}"
    echo -e "                                ${RED}v0.20${NC}"
    echo -e "${BLUE}=============================================${NC}\n"
}

# -----------------------------------------------
# Part 3: Check/Install yt-dlp
# -----------------------------------------------
check_ytdlp() {
    if ! command -v yt-dlp &>/dev/null; then
        echo -e "${RED}yt-dlp is not installed.${NC}"
        read -p "Install yt-dlp now? (y/n): " install_choice
        if [[ "$install_choice" == "y" ]]; then
            echo -e "${YELLOW}Installing yt-dlp...${NC}"
            sudo curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp
            sudo chmod a+rx /usr/local/bin/yt-dlp
            echo -e "${GREEN}yt-dlp installed successfully!${NC}"
            sleep 2
        else
            echo -e "${RED}Script requires yt-dlp. Exiting.${NC}"
            exit 1
        fi
    fi
}

# -----------------------------------------------
# Part 4: Check/Install ffmpeg
# -----------------------------------------------
check_ffmpeg() {
    if ! command -v ffmpeg &>/dev/null; then
        echo -e "${RED}ffmpeg is not installed.${NC}"
        read -p "Install ffmpeg now? (y/n): " install_choice
        if [[ "$install_choice" == "y" ]]; then
            echo -e "${YELLOW}Installing ffmpeg...${NC}"
            if [[ "$OSTYPE" == "linux-gnu"* ]]; then
                sudo apt-get update && sudo apt-get install -y ffmpeg
            elif [[ "$OSTYPE" == "darwin"* ]]; then
                brew install ffmpeg
            else
                echo -e "${RED}Unsupported OS for auto-install. Please install ffmpeg manually.${NC}"
                exit 1
            fi
            echo -e "${GREEN}ffmpeg installed successfully!${NC}"
            sleep 1
        else
            echo -e "${RED}Video editing requires ffmpeg. Continuing without.${NC}"
            return 1
        fi
    fi
    return 5
}

# -----------------------------------------------
# Part 5: Setup Cookies
# -----------------------------------------------
setup_cookies() {
    header
    echo -e "${BOLD}Cookie Setup (for private/restricted videos)${NC}\n"
    
    if [[ -f "cookies.txt" ]]; then
        echo -e "${YELLOW}Found cookies.txt in current directory.${NC}"
        if [[ -s "cookies.txt" ]]; then
            if grep -q "^#.*Netscape HTTP Cookie File" "cookies.txt" && grep -qE "^[^\s#].*\s+.*\s+.*\s+.*\s+.*\s+.*\s+.*$" "cookies.txt"; then
                echo -e "${GREEN}cookies.txt contains valid cookies:${NC}"
                echo -e "  Size: $(du -h cookies.txt | cut -f1)"
                echo -e "  Date: $(date -r cookies.txt)"
                cookies_command="--cookies cookies.txt"
                echo -e "${GREEN}Using cookies.txt${NC}"
                sleep 2
                return
            else
                echo -e "${RED}cookies.txt does not contain valid cookies!${NC}"
            fi
        else
            echo -e "${RED}cookies.txt is empty!${NC}"
        fi
        read -p "Add new cookies to cookies.txt? (y/n): " add_cookies
        if [[ "$add_cookies" != "y" ]]; then
            echo -e "${YELLOW}Continuing without cookies.${NC}"
            cookies_command=""
            sleep 2
            return
        fi
    fi
    
    echo -e "Steps to get cookies:"
    echo -e "1. Log in to the target site in Chrome/Firefox"
    echo -e "2. Install the '${BLUE}Get cookies.txt LOCALLY${NC}' extension:"
    echo -e "   - [Chrome Web Store](https://chromewebstore.google.com/detail/get-cookiestxt-locally/cclelndahbckbenkjhflpdbgdldlbecc)"
    echo -e "3. Export cookies as '${GREEN}cookies.txt${NC}\n"
    
    read -p "Use cookies? (y/n): " need_cookies
    if [[ "$need_cookies" != "y" ]]; then
        cookies_command=""
        return
    fi
    
    echo -e "\n${BOLD}Cookie Options:${NC}"
    echo -e "1) Provide cookies.txt path"
    echo -e "2) Skip cookies"
    read -p "Select (1-2): " cookie_choice
    case $cookie_choice in
        1)
            read -p "Enter full path to cookies.txt: " cookie_path
            if [[ -f "$cookie_path" && -s "$cookie_path" ]]; then
                if grep -q "^#.*Netscape" "$cookie_path"; then
                    cp "$cookie_path" ./cookies.txt
                    cookies_command="--cookies cookies.txt"
                    echo -e "${GREEN}Cookies configured!${NC}"
                else
                    echo -e "${RED}File not valid. Continuing without cookies.${NC}"
                    cookies_command=""
                fi
            else
                echo -e "${RED}File not found or empty! Continuing without cookies.${NC}"
                cookies_command=""
            fi
            ;;
        *) cookies_command="";;
    esac
    sleep 1
}

# -----------------------------------------------
# Part 6: Extract URL Identifier
# -----------------------------------------------
get_url_identifier() {
    local url=$1
    local platform=$2
    
    case $platform in
        youtube)
        if [[ $url == *"youtube.com"* ]]; then
            if [[ $url" == *"youtube.com/watch"* ]]; then
                echo "$url" | grep -o -E 'v=([^&]+)' | cut -d'=' -f2
            elif [[ "$url" == *"youtube.com/shorts"* ]]; then
                echo "$url" | grep -o -E '/shorts/[^/]+$' | cut -d'/' -f2
            elif [[ "$url" == *"youtu.be"* ]]; then
                echo "$url" | grep -o -E '/youtu\.be/([^?]+)' | cut -d'/' -f2
            fi
        fi
        ;;
    *)
            echo "${url##*/}_$(date +%s)"
            ;;
    esac
}

# -----------------------------------------------
# Part 7: Configure Video Editing
# -----------------------------------------------
configure_editing() {
    header
    echo -e "${BOLD}Video Editing Options:${NC}"
    local video_options=("No editing" "Trim video" "Resize video" "Convert format" "Flip video")
    
    for i in "${!video_options[@]}"; do
        echo -e "$((i+1))- ${video_options[i]}"
    done
    read -p "${YELLOW}Select option:${NC}" do
    
    until [[ "$edit_choice" =~ ^[1-5]$ ]]; do
            echo -e "${RED}Invalid choice. Enter a number between 1 and 5.${NC}"
            read -p "${YELLOW}Select option (1-5): ${NC}" edit_choice
    done
    
    case $edit_choice in
        2)
            read -p "Start time (e.g., 00:00:10): " trim_start
            read -p "Duration (e.g., 00:00:30): " trim_duration
            echo "-ss $trim_start -t $trim_duration -c:v copy -c:a copy|_trimmed"
            ;;
        3)
            read -p "Resolution (e.g., 1280x720): " resolution
            echo "-vf scale=$resolution -c:a copy|_resized"
            ;;
        4)
            read -p "Output format (e.g., mp4, avi): " format
            echo "-c:v libx264 -c:a aac|_converted.$format"
            ;;
        5)
            echo -e "${BOLD}Flip Options:${NC}"
            local flip_options=("Horizontal flip" "Vertical flip" "Both")
            for i in "${!flip_options[@]}"; do
                echo -e "$((i+1))) ${flip_options[i]}"
            done
            read -p "${YELLOW}Select flip option (1-3): ${NC}" flip_choice
            until [[ "$flip_choice" =~ ^[1-3]$ ]]; do
                echo -e "${RED}Invalid choice. Enter a number between 1 and 3.${NC}"
                read -p "${YELLOW}Select flip option (1-3): ${NC}" flip_choice
            done
            case $flip_choice in
                1) echo "-vf hflip -c:a copy|_hflipped";;
                2) echo "-vf vflip -c:a copy|_vflipped";;
                3) echo "-vf hflip,vflip -c:a copy|_flipped";;
            esac
            ;;
        *) echo "|";;
    esac
}

# -----------------------------------------------
# Part 8: Display Download Summary
# -----------------------------------------------
show_summary() {
    local platform=$1
    local url_identifier=$2
    local quality_label=$3
    local output_dir=$4
    local edit_choice=$5
    local description_choice=$6
    
    header
    echo -e "${GREEN}Download Settings:${NC}"
    echo -e " - Platform: ${platform}"
    [[ -n "$url_identifier" ]] && echo -e " - Source: ${url_identifier}"
    echo -e " - Quality: ${quality_label}"
    [[ -n "$cookies_command" ]] && echo -e " - Cookies: Enabled${NC}" || echo -e " - Cookies: Disabled${NC}"
    if [[ "$description_choice" == "1" ]]; then
        echo -e " - Description: Included${NC}"
    else
        echo -e " - Description: Excluded${NC}"
    fi
    if [[ -n "$edit_choice" && "$edit_choice" != "1" ]]; then
        case $edit_choice in
            2) echo -e " - Editing: Trimming${NC}";;
            3) echo -e " - Editing: Resizing${NC}";;
            4) echo -e " - Editing: Converting${NC}";;
            5) echo -e " - Editing: Flipping${NC}";;
        esac
    else
        echo -e " - Editing: Disabled${NC}"
    fi
    echo -e " - Output: ${output_dir}${NC}\n"
    sleep 2
}

# -----------------------------------------------
# Part 9: Main Download Logic
# -----------------------------------------------
main() {
    header
    check_ytdlp
    check_ffmpeg
    has_ffmpeg=$?
    
    # Platform selection
    header
    echo -e "${BOLD}Select Platform:${NC}"
    local platform_options=("YouTube" "Facebook" "TikTok" "Other")
    for i in "${!platform_options[@]}"; do
        echo -e "$((i+1))) ${platform_options[i]}"
    done
    read -p "${YELLOW}Select platform (1-4): ${NC}" platform_choice
    until [[ "$platform_choice" =~ ^[1-4]$ ]]; do
        echo -e "${RED}Invalid choice. Enter a number between 1 and 4.${NC}"
        read -p "${YELLOW}Select platform (1-4): ${NC}" platform_choice
    done
    
    case $platform_choice in
        1) platform="youtube"; profile_type="video/channel";;
        2) platform="facebook"; profile_type="post/page";;
        3) platform="tiktok"; profile_type="video/user";;
        4) platform="other"; profile_type="URL";;
    esac
    
    # Cookie setup
    setup_cookies
    [[ "$platform" == "tiktok" ]] && cookies_command+=" --referer https://www.tiktok.com/"
    
    # URL input
    read -p "Enter $profile_type URL: " video_url
    [[ -z "$video_url" ]] && { echo -e "${RED}URL cannot be empty!${NC}"; exit 1; }
    
    # Get identifier
    url_identifier=$(get_url_identifier "$video_url" "$platform")
    
    # Download scope
    header
    echo -e "${BOLD}Download Scope:${NC}"
    local scope_options=("Single video" "All videos")
    for i in "${!scope_options[@]}"; do
        echo -e "$((i+1))) ${scope_options[i]}"
    done
    read -p "${YELLOW}Select scope (1-2): ${NC}" scope_choice
    until [[ "$scope_choice" =~ ^[1-2]$ ]]; do
        echo -e "${RED}Invalid choice. Enter a number between 1 and 2.${NC}"
        read -p "${YELLOW}Select scope (1-2): ${NC}" scope_choice
    done
    
    # Quality selection
    header
    echo -e "${BOLD}Video Quality:${NC}"
    local quality_options=("Best quality" "1080p" "720p" "480p" "Audio only (MP3)")
    for i in "${!quality_options[@]}"; do
        echo -e "$((i+1))) ${quality_options[i]}"
    done
    read -p "${YELLOW}Select quality (1-5): ${NC}" quality_choice
    until [[ "$quality_choice" =~ ^[1-5]$ ]]; do
        echo -e "${RED}Invalid choice. Enter a number between 1 and 5.${NC}"
        read -p "${YELLOW}Select quality (1-5): ${NC}" quality_choice
    done
    
    case $quality_choice in
        1) quality="best"; quality_label="Best quality";;
        2) quality="bestvideo[height<=1080]+bestaudio/best[height<=1080]"; quality_label="1080p";;
        3) quality="bestvideo[height<=720]+bestaudio/best[height<=720]"; quality_label="720p";;
        4) quality="bestvideo[height<=480]+bestaudio/best[height<=480]"; quality_label="480p";;
        5) quality="bestaudio -x --audio-format mp3"; quality_label="Audio only (MP3)";;
    esac
    
    # Description file selection (only for video downloads, not audio)
    description_command=""
    description_label="Excluded"
    if [[ "$quality_choice" != "5" ]]; then
        header
        echo -e "${BOLD}Download Options:${NC}"
        local description_options=("MP4 with description file" "MP4 only")
        for i in "${!description_options[@]}"; do
            echo -e "$((i+1))) ${description_options[i]}"
        done
        read -p "${YELLOW}Select option (1-2): ${NC}" description_choice
        until [[ "$description_choice" =~ ^[1-2]$ ]]; do
            echo -e "${RED}Invalid choice. Enter a number between 1 and 2.${NC}"
            read -p "${YELLOW}Select option (1-2): ${NC}" description_choice
        done
        if [[ "$description_choice" == "1" ]]; then
            description_command="--write-description"
            description_label="Included"
        fi
    fi
    
    # Editing options
    edit_command=""
    edit_suffix=""
    if [[ "$scope_choice" == "1" && $has_ffmpeg -eq 0 ]]; then
        IFS='|' read -r edit_command edit_suffix <<< "$(configure_editing)"
    elif [[ "$scope_choice" == "2" && $has_ffmpeg -eq 0 ]]; then
        echo -e "${YELLOW}Editing is only supported for single video downloads${NC}"
        sleep 1
    fi
    
    # Output folder
    if [[ "$scope_choice" == "2" ]]; then
        output_dir="${platform}_${url_identifier}_downloads"
    else
        output_dir="${platform}_single_videos"
    fi
    mkdir -p "$output_dir"
    
    output_template="$output_dir/%(title)s.%(ext)s"
    edit_output_template="$output_dir/%(title)s${edit_suffix}.%(ext)s"
    
    # Platform-specific options
    case $platform in
        tiktok) extra_options="--force-overwrites --write-thumbnail";;
        youtube) extra_options="--embed-thumbnail --add-metadata";;
        *) extra_options="";;
    esac
    # Append description command to extra options
    extra_options="$extra_options $description_command"
    
    # Show summary
    show_summary "$platform" "$url_identifier" "$quality_label" "$output_dir" "$quality_choice" "$description_choice"
    
    # Download execution
    if [[ "$scope_choice" == "1" && -n "$edit_command" ]]; then
        echo -e "${YELLOW}Downloading video...${NC}"
        if ! yt-dlp $cookies_command $extra_options -f "$quality" -o "$output_template" "$video_url"; then
            echo -e "${RED}Download failed!${NC}"
            exit 1
        fi
        echo -e "${YELLOW}Editing video...${NC}"
        local input_file=$(ls -t "$output_dir" | head -n 1)
        if ! ffmpeg -i "$output_dir/$input_file" $edit_command "${output_dir}/${input_file%.*}${edit_suffix}.mp4" 2>ffmpeg_error.log; then
            echo -e "${RED}Editing failed. Check ffmpeg_error.log.${NC}"
            cat ffmpeg_error.log
        else
            echo -e "${GREEN}Editing completed!${NC}"
        fi
    elif [[ "$scope_choice" == "1" ]]; then
        echo -e "${YELLOW}Downloading single video...${NC}"
        if ! yt-dlp $cookies_command $extra_options -f "$quality" -o "$output_template" "$video_url"; then
            echo -e "${RED}Download failed!${NC}"
            exit 1
        fi
    else
        echo -e "${YELLOW}Downloading multiple videos...${NC}"
        if ! yt-dlp $cookies_command $extra_options -f "$quality" -o "$output_template" --yes-playlist "$video_url"; then
            echo -e "${RED}Download failed!${NC}"
            exit 1
        fi
    fi
    
    echo -e "${GREEN}Download completed!${NC}"
    ls -lh "$output_dir" | head -5
    [[ $(ls "$output_dir" | wc -l) -gt 5 ]] && echo "[...] More files..."
}

# -----------------------------------------------
# Part 10: Run Script
# -----------------------------------------------
main