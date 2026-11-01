#!/bin/bash

if [ -f "$HOME/.env" ]; then
    source "$HOME/.env"
else
    echo "File .secrets not found in $HOME"
fi

if [ -f "$(pwd)/.env" ]; then
    source "$(pwd)/.env"
else
    echo "File .secrets not found in $(pwd)"
fi


# =========================================================
# CONFIGURATION
# =========================================================
# This token was retrieved from your previous log for continuous functionality.
DEVICE_CODE="courbet"
BUILD_TARGET="LunarisAOSP"
ANDROID_VERSION="16.2"

# SHELL CONFIGURATION
export TZ="Asia/Jakarta"
export BUILD_USERNAME=Szechuan
export BUILD_HOSTNAME=Sze-Labs

# =========================================================
# TELEGRAM FUNCTIONS
# =========================================================

# Function to safely format and send a text message to Telegram
send_telegram() {
  local chat_id="$1"
  local message="$2"
  local _TK="$TG_BOT_TOKEN"

  # 1. Escape characters required by MarkdownV2 that are NOT meant to be formatters.
  # We use a comprehensive escaping logic to ensure *bold* text works.
  local escaped_message=$(echo "$message" | sed \
    -e 's/\*/\*TEMP\*/g' \
    -e 's/_/\_TEMP\_/g' \
    -e 's/\[/\\[/g' \
    -e 's/\]/\\]/g' \
    -e 's/(/\\(/g' \
    -e 's/)/\\)/g' \
    -e 's/~/\\~/g' \
    -e 's/`/\`/g' \
    -e 's/>/\\>/g' \
    -e 's/#/\\#/g' \
    -e 's/+/\\+/g' \
    -e 's/-/\\-/g' \
    -e 's/=/\\=/g' \
    -e 's/|/\\|/g' \
    -e 's/{/\\{/g' \
    -e 's/}/\\}/g' \
    -e 's/\./\\./g' \
    -e 's/!/\\!/g')

  # 2. Revert the temporary placeholders for the actual formatting characters that are intended for bold/italic.
  local re_escaped_message=$(echo "$escaped_message" | sed \
    -e 's/\*TEMP\*/\*/g' \
    -e 's/\_TEMP\_/\_/g')
  
  # 3. URL encode special characters for transmission, including newlines.
  local encoded_message=$(echo "$re_escaped_message" | sed \
    -e 's/%/%25/g' \
    -e 's/&/%26/g' \
    -e 's/+/%2b/g' \
    -e 's/ /%20/g' \
    -e 's/\"/%22/g' \
    -e 's/'"'"'/%27/g' \
    -e 's/\n/%0A/g')
    
  echo -e "\n[$(date '+%Y-%m-%d %H:%M:%S')] Sending message to Telegram (${chat_id})"
  # We must explicitly set parse_mode to MarkdownV2
  curl -s -X POST "https://api.telegram.org/bot${_TK}/sendMessage" \
    -d "chat_id=${chat_id}" \
    -d "text=${encoded_message}" \
    -d "parse_mode=MarkdownV2" \
    -d "disable_web_page_preview=true" > /dev/null
}

send_telegram_file() {

  local chat_id="$1"
  local file_path="$2"
  local caption="$3"

  if [ ! -f "$file_path" ]; then
    echo "Error: File $file_path not found!"
    return 1
  fi

  echo -e "\n[$(date '+%Y-%m-%d %H:%M:%S')] Sending document to Telegram (${chat_id})"

  curl -s -X POST "https://api.telegram.org/bot${_TK}/sendDocument" \
    -F "chat_id=${chat_id}" \
    -F "document=@${file_path}" \
    -F "caption=${caption}" \
    -F "parse_mode=MarkdownV2" > /dev/null
}

# Function to format total seconds into HH:MM:SS string
format_duration() {
    local T=$1
    local H=$((T/3600))
    local M=$(( (T%3600)/60 ))
    local S=$((T%60))
    printf "%02d hours, %02d minutes, %02d seconds" $H $M $S
}


# =========================================================
# BUILD LOGIC FUNCTION
# =========================================================

start_build_process() {

    # --- STEP 1: START TIMER AND SEND INITIAL NOTIFICATION ---
    START_TIME=$(date +%s)

    # Message for Build Started
    local initial_msg="⚙️ *ROM Build Started!*

    *ROM:* $BUILD_TARGET
    *Android:* $ANDROID_VERSION
    *Device:* $DEVICE_CODE
    *Start Time:* $(date '+%Y-%m-%d %H:%M:%S %Z')"
    send_telegram "$TG_BUILD_CHAT_ID" "$initial_msg"
    echo "Build Started at $(date '+%Y-%m-%d %H:%M:%S')"

    # =========================================================
    # ORIGINAL BUILD STEPS
    # =========================================================

    # Init LunarisAOSP
    repo init --depth=1 -u https://github.com/Lunaris-AOSP/android -b 16.2 --git-lfs

    # Resync sources
    /opt/crave/resync.sh
    repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags
    /opt/crave/resync.sh
    repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags
    /opt/crave/resync.sh

    # Clean up existing trees
    echo "Clean up repositories..."
    rm -rf device/xiaomi/courbet
    rm -rf vendor/xiaomi/courbet
    rm -rf kernel/xiaomi/sm6150
    rm -rf device/xiaomi/sm6150-common
    rm -rf vendor/xiaomi/sm6150-common
    rm -rf vendor/xiaomi/miuicamera-courbet
    rm -rf out/target/product/courbet
    echo "Successfully deleted previous repositories."

    echo "Cloning device stuff..."
    # Device Trees
    git clone -b lunar --depth 1 https://github.com/Szes-Labs/device_xiaomi_courbet.git device/xiaomi/courbet
    git clone -b lunar --depth 1 https://github.com/Szes-Labs/device_xiaomi_sm6150-common.git device/xiaomi/sm6150-common
    
    # Kernel
    git clone -b aosp --depth 1 https://github.com/Szes-Labs/kernel_xiaomi_sm6150.git kernel/xiaomi/sm6150
    
    # Vendor tree
    git clone -b 16 --depth 1 https://github.com/Szes-Labs/vendor_xiaomi_sm6150-common.git vendor/xiaomi/sm6150-common
    git clone -b 16 --depth 1 https://github.com/Szes-Labs/vendor_xiaomi_courbet.git vendor/xiaomi/courbet 
    
    # Camera
    git clone -b 16 --depth 1 https://github.com/Szes-Labs/vendor_miuicamera-courbet.git vendor/miuicamera-courbet
    
    # Dolby
    git clone -b seventeen --depth 1 https://github.com/Szes-Labs/android_packages_apps_LunarisDolby.git packages/apps/LunarisDolby
    git clone -b 16 --depth 1 https://github.com/Szes-Labs/vendor_sony_dolby.git vendor/sony/dolby
    
    # Hardware
    git clone -b lineage-23.2 --depth 1 https://github.com/Szes-Labs/android_hardware_xiaomi.git hardware/xiaomi

    echo "Tree sync complete."

    # Setup the build environment
    . b*/e*
    echo "Environment setup success."

    # Lunch target selection
    lunch lineage_courbet-bp4a-user
    echo "Lunch command executed."

    # Build ROM
    echo "========================="
    echo "Starting ROM Compilation..."
    echo "========================="
    m bacon -j$(nproc --all) 2>&1 | tee log.txt

    BUILD_STATUS=$? # Capture exit code immediately

    # --- STEP 3: CALCULATE TIME AND SEND FINAL NOTIFICATION ---
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    local DURATION_FORMATTED=$(format_duration $DURATION)
    
    if [[ $BUILD_STATUS -eq 0 ]]; then
        local status_icon="✅"
        local status_text="Success"
	LOG_FILE="log.txt"
    else
        local status_icon="❌"
        local status_text="Failure (Exit Code: $BUILD_STATUS)"
	LOG_FILE="out/error.log"
    fi

    # Final Message with Android Version
    local final_msg="${status_icon} *Build Finished!*

    *ROM:* $BUILD_TARGET
    *Android:* $ANDROID_VERSION
    *Device:* $DEVICE_CODE
    *Duration:* $DURATION_FORMATTED
    *Status:* $status_text"
    send_telegram "$TG_BUILD_CHAT_ID" "$final_msg"

    if [[ -f "$LOG_FILE" ]]; then
	send_telegram_file "$TG_BUILD_CHAT_ID" "$LOG_FILE"
    else
	send_telegram "$TG_BUILD_CHAT_ID" "⚠️ Warning: Log file ${LOG_FILE} not found."
    fi

    # Conditional Upload ROM
    if [[ $BUILD_STATUS -eq 0 ]]; then
        echo "Build successful. Starting upload script..."
        # Calls the go-up script
        rm -rf go-up*
        wget https://raw.githubusercontent.com/Szetian/Crave_builder/refs/heads/Lunaris/go-up
        chmod +x go-up
        ./go-up out/target/product/courbet/*courbet*.zip
    else
        echo "Build failed. Skipping upload."
    fi

    # Display any error logs
    echo "Here is your error"
    cat out/error.log
}

# =========================================================
# MAIN EXECUTION
# =========================================================

# Check required environment variables (optional but good practice)
start_build_process
