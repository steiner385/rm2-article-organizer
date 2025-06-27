#!/bin/bash
# Remote Installation Script for reMarkable 2 Article Organizer
# This script runs on your computer and handles the entire installation process

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}     reMarkable 2 Article Organizer - Remote Installer${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Config directory for storing connection details
CONFIG_DIR="$HOME/.config/rm2-article-organizer"
CONFIG_FILE="$CONFIG_DIR/connection.conf"

# Create config directory if it doesn't exist
mkdir -p "$CONFIG_DIR"

# Function to save connection details
save_connection_details() {
    local ip=$1
    local save_pass=$2
    local pass=$3
    
    echo "RM_IP=$ip" > "$CONFIG_FILE"
    if [[ "$save_pass" == "y" ]]; then
        # Simple obfuscation (base64) - not secure but prevents casual viewing
        echo "RM_PASS=$(echo -n "$pass" | base64)" >> "$CONFIG_FILE"
    fi
    chmod 600 "$CONFIG_FILE"
}

# Function to load connection details
load_connection_details() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        if [ -n "$RM_PASS" ]; then
            # Decode the password
            RM_PASS=$(echo -n "$RM_PASS" | base64 -d)
        fi
    fi
}

# Function to test SSH connection
test_ssh_connection() {
    local host=$1
    local password=$2
    
    if [ -n "$password" ]; then
        sshpass -p "$password" ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@"$host" "echo 'SSH connection successful'" 2>/dev/null
    else
        ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@"$host" "echo 'SSH connection successful'" 2>/dev/null
    fi
}

# Check for required commands
echo -e "${YELLOW}Checking requirements...${NC}"
MISSING_DEPS=""

if ! command -v ssh &> /dev/null; then
    MISSING_DEPS="$MISSING_DEPS ssh"
fi

if ! command -v scp &> /dev/null; then
    MISSING_DEPS="$MISSING_DEPS scp"
fi

if ! command -v sshpass &> /dev/null; then
    echo -e "${YELLOW}Note: sshpass not found. You'll need to enter your password multiple times.${NC}"
    echo -e "${YELLOW}Install sshpass for a smoother experience: ${NC}"
    echo -e "${YELLOW}  Ubuntu/Debian: sudo apt-get install sshpass${NC}"
    echo -e "${YELLOW}  macOS: brew install hudochenkov/sshpass/sshpass${NC}"
    echo ""
fi

if [ -n "$MISSING_DEPS" ]; then
    echo -e "${RED}Error: Missing required commands: $MISSING_DEPS${NC}"
    echo -e "${RED}Please install them and try again.${NC}"
    exit 1
fi

# Load saved connection details
load_connection_details
SAVED_IP="$RM_IP"
SAVED_PASS="$RM_PASS"

# Get reMarkable connection details
echo -e "${GREEN}Step 1: reMarkable Connection${NC}"
echo -e "Please ensure your reMarkable is:"
echo -e "  • Connected to the same network as this computer"
echo -e "  • SSH is enabled (Settings → Help → Developer mode)"
echo ""

# Check if we have saved credentials
if [ -n "$SAVED_IP" ]; then
    echo -e "${BLUE}Found saved connection details${NC}"
fi

# Get IP address
if [ -n "$SAVED_IP" ]; then
    read -p "Enter your reMarkable IP address [$SAVED_IP]: " RM_IP
    RM_IP=${RM_IP:-$SAVED_IP}
else
    read -p "Enter your reMarkable IP address: " RM_IP
    while [ -z "$RM_IP" ]; do
        echo -e "${RED}IP address cannot be empty${NC}"
        read -p "Enter your reMarkable IP address: " RM_IP
    done
fi

# Get password
echo ""
echo -e "${YELLOW}The default password is shown in Settings → Help → Copyright notices${NC}"
if [ -n "$SAVED_PASS" ]; then
    echo -e "${BLUE}Using saved password (press Enter to use, or type new password)${NC}"
    read -s -p "Enter your reMarkable password: " NEW_PASS
    echo ""
    if [ -z "$NEW_PASS" ]; then
        RM_PASS="$SAVED_PASS"
    else
        RM_PASS="$NEW_PASS"
    fi
else
    read -s -p "Enter your reMarkable password: " RM_PASS
    echo ""
fi

# Test connection
echo ""
echo -e "${YELLOW}Testing connection to $RM_IP...${NC}"
if test_ssh_connection "$RM_IP" "$RM_PASS"; then
    echo -e "${GREEN}✓ Connection successful!${NC}"
    
    # Ask to save credentials if not already saved
    if [ "$RM_IP" != "$SAVED_IP" ] || [ "$RM_PASS" != "$SAVED_PASS" ]; then
        echo ""
        read -p "Save connection details for future use? [Y/n]: " SAVE_CREDS
        SAVE_CREDS=${SAVE_CREDS:-Y}
        if [[ "$SAVE_CREDS" =~ ^(y|yes|Y|YES)$ ]]; then
            if command -v sshpass &> /dev/null; then
                read -p "Save password (base64 encoded)? [y/N]: " SAVE_PASS
                SAVE_PASS=${SAVE_PASS:-N}
                SAVE_PASS=$(echo "$SAVE_PASS" | tr '[:upper:]' '[:lower:]')
            else
                SAVE_PASS="n"
                echo -e "${YELLOW}Note: Password saving requires sshpass${NC}"
            fi
            save_connection_details "$RM_IP" "$SAVE_PASS" "$RM_PASS"
            echo -e "${GREEN}Connection details saved to ~/.config/rm2-article-organizer/${NC}"
        fi
    fi
else
    echo -e "${RED}✗ Failed to connect to reMarkable${NC}"
    echo -e "${RED}Please check:${NC}"
    echo -e "${RED}  • IP address is correct${NC}"
    echo -e "${RED}  • Password is correct${NC}"
    echo -e "${RED}  • SSH is enabled on your reMarkable${NC}"
    echo -e "${RED}  • Both devices are on the same network${NC}"
    exit 1
fi

# Configuration options
echo ""
echo -e "${GREEN}Step 2: Configuration Options${NC}"
echo -e "Press Enter to use defaults shown in [brackets]"
echo ""

# Folder names
read -p "Folder for new articles [To Read]: " TO_READ_FOLDER
TO_READ_FOLDER=${TO_READ_FOLDER:-"To Read"}

read -p "Folder for completed articles [Read Articles]: " READ_FOLDER
READ_FOLDER=${READ_FOLDER:-"Read Articles"}

read -p "Folder for archived articles [Archived Articles]: " ARCHIVE_FOLDER
ARCHIVE_FOLDER=${ARCHIVE_FOLDER:-"Archived Articles"}

# Reading detection
echo ""
echo -e "${BLUE}Reading Detection Settings:${NC}"
read -p "Enable automatic move when articles are read? [Y/n]: " ENABLE_AUTO_MOVE
ENABLE_AUTO_MOVE=${ENABLE_AUTO_MOVE:-Y}
ENABLE_AUTO_MOVE=$(echo "$ENABLE_AUTO_MOVE" | tr '[:upper:]' '[:lower:]')

if [[ "$ENABLE_AUTO_MOVE" =~ ^(y|yes)$ ]]; then
    read -p "Percentage of pages to consider article 'read' (0-100) [80]: " PAGES_THRESHOLD
    PAGES_THRESHOLD=${PAGES_THRESHOLD:-80}
    
    read -p "Minimum reading time in minutes [5]: " TIME_MINUTES
    TIME_MINUTES=${TIME_MINUTES:-5}
    TIME_THRESHOLD=$((TIME_MINUTES * 60))
    
    AUTO_MOVE_ENABLED="true"
else
    PAGES_THRESHOLD=80
    TIME_THRESHOLD=300
    AUTO_MOVE_ENABLED="false"
fi

# Date organization
echo ""
read -p "Organize articles by date? [y/N]: " ORGANIZE_BY_DATE
ORGANIZE_BY_DATE=${ORGANIZE_BY_DATE:-N}
ORGANIZE_BY_DATE=$(echo "$ORGANIZE_BY_DATE" | tr '[:upper:]' '[:lower:]')

if [[ "$ORGANIZE_BY_DATE" =~ ^(y|yes)$ ]]; then
    echo "Date format options:"
    echo "  1) YYYY-MM-DD (2025-06-27)"
    echo "  2) YYYY/MM (2025/06)"
    echo "  3) YYYY-MM (2025-06)"
    read -p "Choose format [1]: " DATE_FORMAT_CHOICE
    DATE_FORMAT_CHOICE=${DATE_FORMAT_CHOICE:-1}
    
    case $DATE_FORMAT_CHOICE in
        2) DATE_FORMAT="%Y/%m" ;;
        3) DATE_FORMAT="%Y-%m" ;;
        *) DATE_FORMAT="%Y-%m-%d" ;;
    esac
    
    DATE_ORG_ENABLED="true"
else
    DATE_FORMAT="%Y-%m-%d"
    DATE_ORG_ENABLED="false"
fi

# Archive settings
echo ""
read -p "Enable automatic archiving of old read articles? [y/N]: " ENABLE_ARCHIVE
ENABLE_ARCHIVE=${ENABLE_ARCHIVE:-N}
ENABLE_ARCHIVE=$(echo "$ENABLE_ARCHIVE" | tr '[:upper:]' '[:lower:]')

if [[ "$ENABLE_ARCHIVE" =~ ^(y|yes)$ ]]; then
    read -p "Days before archiving read articles [30]: " ARCHIVE_DAYS
    ARCHIVE_DAYS=${ARCHIVE_DAYS:-30}
    ARCHIVE_ENABLED="true"
else
    ARCHIVE_DAYS=30
    ARCHIVE_ENABLED="false"
fi

# Create configuration file
echo ""
echo -e "${YELLOW}Creating configuration...${NC}"

cat > /tmp/rm2_organizer_config.json << EOF
{
  "folders": {
    "to_read": "$TO_READ_FOLDER",
    "read": "$READ_FOLDER",
    "archive": "$ARCHIVE_FOLDER"
  },
  "source_patterns": [
    "read on remarkable",
    "chrome extension",
    "web article",
    "http",
    "www.",
    ".com"
  ],
  "poll_interval": 30,
  "file_age_threshold": 5,
  "create_folders_if_missing": true,
  "organize_by_date": $DATE_ORG_ENABLED,
  "date_format": "$DATE_FORMAT",
  "reading_detection": {
    "enable_auto_move": $AUTO_MOVE_ENABLED,
    "pages_threshold": $(echo "scale=2; $PAGES_THRESHOLD/100" | bc),
    "time_threshold": $TIME_THRESHOLD,
    "annotation_indicates_read": true,
    "bookmark_indicates_progress": true
  },
  "archive_read_articles": {
    "enable": $ARCHIVE_ENABLED,
    "days_threshold": $ARCHIVE_DAYS
  }
}
EOF

# Show configuration summary
echo ""
echo -e "${GREEN}Configuration Summary:${NC}"
echo -e "  • To Read folder: ${BLUE}$TO_READ_FOLDER${NC}"
echo -e "  • Read folder: ${BLUE}$READ_FOLDER${NC}"
echo -e "  • Archive folder: ${BLUE}$ARCHIVE_FOLDER${NC}"
echo -e "  • Auto-move read articles: ${BLUE}$AUTO_MOVE_ENABLED${NC}"
if [[ "$AUTO_MOVE_ENABLED" == "true" ]]; then
    echo -e "    - Reading threshold: ${BLUE}$PAGES_THRESHOLD%${NC}"
    echo -e "    - Min reading time: ${BLUE}$TIME_MINUTES minutes${NC}"
fi
echo -e "  • Organize by date: ${BLUE}$DATE_ORG_ENABLED${NC}"
echo -e "  • Auto-archive: ${BLUE}$ARCHIVE_ENABLED${NC}"
if [[ "$ARCHIVE_ENABLED" == "true" ]]; then
    echo -e "    - Archive after: ${BLUE}$ARCHIVE_DAYS days${NC}"
fi

echo ""
read -p "Proceed with installation? [Y/n]: " CONFIRM
CONFIRM=${CONFIRM:-Y}
if [[ ! "$CONFIRM" =~ ^(y|yes|Y|YES)$ ]]; then
    echo -e "${YELLOW}Installation cancelled.${NC}"
    exit 0
fi

# Download files if not present locally
echo ""
echo -e "${GREEN}Step 3: Preparing Installation Files${NC}"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Check if we have local files or need to download
if [ -f "$SCRIPT_DIR/rm2_organizer.py" ] && [ -f "$SCRIPT_DIR/rm2_organizer_install.sh" ]; then
    echo -e "${GREEN}Using local files${NC}"
    cp "$SCRIPT_DIR/rm2_organizer.py" /tmp/
    cp "$SCRIPT_DIR/rm2_organizer_install.sh" /tmp/
else
    echo -e "${YELLOW}Downloading files from GitHub...${NC}"
    REPO_URL="https://raw.githubusercontent.com/steiner385/rm2-article-organizer/main"
    
    curl -s -o /tmp/rm2_organizer.py "$REPO_URL/rm2_organizer.py" || {
        echo -e "${RED}Failed to download rm2_organizer.py${NC}"
        exit 1
    }
    
    curl -s -o /tmp/rm2_organizer_install.sh "$REPO_URL/rm2_organizer_install.sh" || {
        echo -e "${RED}Failed to download install script${NC}"
        exit 1
    }
fi

# Copy files to reMarkable
echo ""
echo -e "${GREEN}Step 4: Copying Files to reMarkable${NC}"

# Function to copy with password
copy_with_pass() {
    local src=$1
    local dst=$2
    
    if [ -n "$RM_PASS" ] && command -v sshpass &> /dev/null; then
        sshpass -p "$RM_PASS" scp -o StrictHostKeyChecking=no "$src" root@"$RM_IP":"$dst"
    else
        scp -o StrictHostKeyChecking=no "$src" root@"$RM_IP":"$dst"
    fi
}

# Copy files
echo -e "${YELLOW}Copying main script...${NC}"
copy_with_pass /tmp/rm2_organizer.py /tmp/ || {
    echo -e "${RED}Failed to copy main script${NC}"
    exit 1
}

echo -e "${YELLOW}Copying install script...${NC}"
copy_with_pass /tmp/rm2_organizer_install.sh /tmp/ || {
    echo -e "${RED}Failed to copy install script${NC}"
    exit 1
}

echo -e "${YELLOW}Copying configuration...${NC}"
copy_with_pass /tmp/rm2_organizer_config.json /tmp/ || {
    echo -e "${RED}Failed to copy configuration${NC}"
    exit 1
}

# Run installation
echo ""
echo -e "${GREEN}Step 5: Running Installation${NC}"

# Function to run command with password
run_with_pass() {
    local cmd=$1
    
    if [ -n "$RM_PASS" ] && command -v sshpass &> /dev/null; then
        sshpass -p "$RM_PASS" ssh -o StrictHostKeyChecking=no root@"$RM_IP" "$cmd"
    else
        ssh -o StrictHostKeyChecking=no root@"$RM_IP" "$cmd"
    fi
}

echo -e "${YELLOW}Making install script executable...${NC}"
run_with_pass "chmod +x /tmp/rm2_organizer_install.sh" || {
    echo -e "${RED}Failed to make script executable${NC}"
    exit 1
}

echo -e "${YELLOW}Running installation...${NC}"
run_with_pass "cd /tmp && ./rm2_organizer_install.sh" || {
    echo -e "${RED}Installation failed${NC}"
    exit 1
}

# Verify installation
echo ""
echo -e "${GREEN}Step 6: Verifying Installation${NC}"

if run_with_pass "systemctl is-active rm2-organizer" | grep -q "active"; then
    echo -e "${GREEN}✓ Service is running${NC}"
else
    echo -e "${YELLOW}⚠ Service is not running, attempting to start...${NC}"
    run_with_pass "systemctl start rm2-organizer"
fi

# Clean up temporary files
echo ""
echo -e "${YELLOW}Cleaning up...${NC}"
rm -f /tmp/rm2_organizer.py /tmp/rm2_organizer_install.sh /tmp/rm2_organizer_config.json
run_with_pass "rm -f /tmp/rm2_organizer.py /tmp/rm2_organizer_install.sh /tmp/rm2_organizer_config.json"

# Show success message
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}           ✅ Installation Complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "The reMarkable Article Organizer is now installed and running."
echo ""
echo -e "${BLUE}Useful commands on your reMarkable:${NC}"
echo -e "  • ${YELLOW}rm2-service status${NC} - Check service status"
echo -e "  • ${YELLOW}rm2-service logs${NC} - View recent logs"
echo -e "  • ${YELLOW}organize-articles${NC} - Run manual organization"
echo -e "  • ${YELLOW}rm2-service stop/start/restart${NC} - Control service"
echo ""
echo -e "${BLUE}Configuration file:${NC} /home/root/.rm2_organizer/config.json"
echo -e "${BLUE}Log file:${NC} /home/root/.rm2_organizer/organizer.log"
echo ""
echo -e "${GREEN}The service will automatically organize your articles as they arrive!${NC}"