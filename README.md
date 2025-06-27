# reMarkable 2 Article Organizer

Automatically organizes articles sent to your reMarkable 2 via the Chrome "Read on reMarkable" extension into a designated folder.

## Features

- **Smart Article Organization**: Automatically moves new articles to "To Read" folder
- **Reading Progress Detection**: Analyzes annotations, bookmarks, and access patterns to detect when articles are read
- **Automatic Read Status Management**: Moves completed articles from "To Read" to "Read Articles" folder
- **Optional Archiving**: Automatically archive old read articles after a configurable time period
- **Configurable Detection Patterns**: Customizable patterns to identify Chrome extension articles
- **Date Organization**: Optional feature to organize articles by date within each folder
- **Daemon Mode**: Runs continuously in the background
- **Manual Mode**: Run organization on-demand
- **Comprehensive Logging**: Detailed logging of all operations and reading analysis

## Installation

### Prerequisites
- reMarkable 2 with SSH access enabled
- Root access to the device

### Important: Update-Persistent Installation
This tool installs to `/home/root/` which persists across reMarkable system updates, unlike `/opt/` which gets wiped.

### Steps

1. **Enable SSH on your reMarkable 2**:
   - Settings → Help → Copyrights and licenses
   - Tap the "GPLv3 Compliance" menu item multiple times until developer mode is enabled
   - Settings → Help → Developer mode → Enable

2. **Connect to your reMarkable via SSH**:
   ```bash
   ssh root@YOUR_REMARKABLE_IP
   ```

3. **Copy files to your reMarkable**:
   ```bash
   # Copy the Python script
   scp rm2_organizer.py root@YOUR_REMARKABLE_IP:/tmp/
   
   # Copy the config file
   scp rm2_organizer_config.json root@YOUR_REMARKABLE_IP:/tmp/
   
   # Copy the installation script
   scp install.sh root@YOUR_REMARKABLE_IP:/tmp/
   ```

4. **Run the installation script**:
   ```bash
   ssh root@YOUR_REMARKABLE_IP
   cd /tmp
   chmod +x install.sh
   ./install.sh
   ```

## File Locations (Update-Persistent)

All files are stored in locations that survive system updates:

- **Main script**: `/home/root/bin/rm2_organizer.py`
- **Configuration**: `/home/root/.rm2_organizer/config.json`
- **Reading state**: `/home/root/.rm2_organizer/reading_state.json`
- **Logs**: `/home/root/.rm2_organizer/organizer.log`
- **Convenience scripts**: `/home/root/bin/`

## After System Updates

The tool includes **automatic recovery** after system updates:

### **Auto-Recovery (Automatic)**
The installation adds a check to your `.bashrc` that automatically detects and fixes missing services after updates. The next time you SSH into your device, you'll see:

```
🔧 Detected missing reMarkable Article Organizer service after update...
🔄 Auto-reinstalling service...
✅ reMarkable Article Organizer restored!
```

### **Manual Recovery (If Needed)**
If you prefer manual control or need to reinstall immediately:

```bash
# Run this after any system update
/home/root/.rm2_organizer/reinstall-after-update.sh
```

### **What Survives vs. What's Restored**

✅ **Always Preserved** (stored in `/home/root/`):
- All configuration settings
- Reading history and progress tracking  
- Application logs
- Main application scripts

🔄 **Auto-Restored** (recreated after updates):
- Systemd service file
- Service registration and startup

## Configuration

Edit `/home/root/.rm2_organizer/config.json` to customize the behavior:

```json
{
  "folders": {
    "to_read": "To Read",                // Folder for new articles
    "read": "Read Articles",             // Folder for completed articles  
    "archive": "Archived Articles"       // Folder for old read articles
  },
  "source_patterns": [                   // Patterns to identify articles
    "read on remarkable",
    "chrome extension", 
    "web article",
    "http",
    "www.",
    ".com"
  ],
  "poll_interval": 30,                   // Check interval in seconds
  "file_age_threshold": 5,               // Min age in minutes before moving
  "create_folders_if_missing": true,     // Auto-create folders
  "organize_by_date": false,             // Create date-based subfolders
  "date_format": "%Y-%m-%d",             // Date format for subfolders
  "reading_detection": {
    "enable_auto_move": true,            // Auto-move read articles
    "pages_threshold": 0.8,              // % of pages to consider "read"
    "time_threshold": 300,               // Min reading time (seconds)
    "annotation_indicates_read": true,   // Annotations indicate reading
    "bookmark_indicates_progress": true  // Bookmarks show progress
  },
  "archive_read_articles": {
    "enable": false,                     // Auto-archive old articles
    "days_threshold": 30                 // Days before archiving
  }
}
```

### Configuration Options

#### Folder Structure
- **folders.to_read**: Folder name for newly arrived articles
- **folders.read**: Folder name for articles that have been read
- **folders.archive**: Folder name for archived old articles

#### Article Detection
- **source_patterns**: List of text patterns that identify Chrome extension articles
- **poll_interval**: How often (in seconds) to check for new articles
- **file_age_threshold**: Minimum age (in minutes) before moving files

#### Reading Detection
- **reading_detection.enable_auto_move**: Enable automatic movement based on reading status
- **reading_detection.pages_threshold**: Percentage of pages that need to be read to consider article "completed"
- **reading_detection.time_threshold**: Minimum reading time (in seconds) to consider article read
- **reading_detection.annotation_indicates_read**: Count annotations as evidence of reading
- **reading_detection.bookmark_indicates_progress**: Count bookmarks as reading progress

#### Organization Options
- **create_folders_if_missing**: Automatically create folders if they don't exist
- **organize_by_date**: Create date-based subfolders within each main folder
- **date_format**: Python datetime format string for date folders

#### Archiving
- **archive_read_articles.enable**: Enable automatic archiving of old read articles
- **archive_read_articles.days_threshold**: Number of days after reading before archiving

## Usage

### Quick Commands
```bash
# Service management
rm2-service start|stop|restart|status|logs

# Manual organization (one-time)
organize-articles
```

### Detailed Usage

### Start the Service
```bash
rm2-service start
```

### Check Status
```bash
rm2-service status
```

### Run Manually (One-time)
```bash
organize-articles
```

### View Logs
```bash
# Application and system logs
rm2-service logs

# Live log monitoring
tail -f /home/root/.rm2_organizer/organizer.log
```

### Stop the Service
```bash
rm2-service stop
```

## How It Works

### Article Lifecycle
1. **New Article Detection**: Monitors reMarkable document metadata for new files from Chrome extension
2. **Initial Organization**: Moves new articles to "To Read" folder
3. **Reading Analysis**: Continuously analyzes reading progress through:
   - Page annotations and highlights
   - Bookmark placement
   - Time spent reading
   - Document access patterns
4. **Automatic Status Updates**: Moves articles from "To Read" to "Read Articles" when completion is detected
5. **Optional Archiving**: Moves old read articles to archive folder after specified time period

### Reading Detection Algorithm
The tool uses multiple signals to determine reading status:

- **Page Coverage**: Tracks annotations across pages to estimate reading progress
- **Annotation Density**: Considers highlights, notes, and drawings as reading indicators  
- **Access Patterns**: Analyzes document open times and frequency
- **Time Threshold**: Considers minimum reading time as completion indicator
- **Bookmarks**: Uses bookmark progression as reading progress signal

### Folder Structure
```
Root/
├── To Read/           # New articles arrive here
│   ├── 2025-06-27/   # Optional date subfolders
│   └── Article 1
├── Read Articles/     # Completed articles move here
│   ├── 2025-06-27/
│   └── Article 2
└── Archived Articles/ # Old articles archive here (optional)
    └── Old Article
```

## Troubleshooting

### Common Issues

1. **Articles not being moved between folders**:
   - Check reading detection settings in configuration
   - Verify that articles have sufficient annotations or reading time
   - Review `/opt/etc/rm2_reading_state.json` for progress tracking
   - Adjust `pages_threshold` or `time_threshold` if needed

2. **Reading status not detected correctly**:
   - Enable more sensitive detection: lower `pages_threshold` to 0.5
   - Reduce `time_threshold` to 120 seconds (2 minutes)
   - Check if `annotation_indicates_read` should be enabled
   - Review logs for reading analysis details

3. **Articles not being moved from root**:
   - Verify the patterns in `source_patterns` match your article names  
   - Check if folders exist or enable `create_folders_if_missing`
   - Ensure `file_age_threshold` is appropriate for your usage

4. **Service not starting**:
   - Ensure Python 3 is available: `python3 --version`
   - Check service status: `systemctl status rm2-organizer`
   - Review logs: `journalctl -u rm2-organizer -f`

3. **Permission errors**:
   - Ensure the script has proper permissions: `chmod +x /opt/bin/rm2_organizer.py`
   - Verify the service is running as root

### Log Files

- Main log: `/home/root/.rm2_organizer/organizer.log`
- Reading state: `/home/root/.rm2_organizer/reading_state.json` 
- System log: `journalctl -u rm2-organizer`

### Manual Testing

Test the script manually to debug issues:

```bash
# Run once in foreground with verbose logging
/home/root/bin/rm2_organizer.py --once

# Check current reading state
cat /home/root/.rm2_organizer/reading_state.json | python3 -m json.tool

# Test reading detection for specific document
# (add debug logging to the script temporarily)

# Run in daemon mode (foreground)
/home/root/bin/rm2_organizer.py --daemon
```

### Reading Detection Tuning

If articles aren't being detected as read, try these adjustments:

```json
{
  "reading_detection": {
    "enable_auto_move": true,
    "pages_threshold": 0.5,           // Lower threshold (50% instead of 80%)
    "time_threshold": 120,            // 2 minutes instead of 5
    "annotation_indicates_read": true,
    "bookmark_indicates_progress": true
  }
}
```

For very light readers who don't annotate much:
```json
{
  "reading_detection": {
    "pages_threshold": 0.3,           // Very low threshold
    "time_threshold": 60,             // 1 minute reading time
    "annotation_indicates_read": false
  }
}
```

## Customization

### Adding New Detection Patterns

Edit the `source_patterns` in the config file to add patterns that match your article naming:

```json
{
  "source_patterns": [
    "read on remarkable",
    "your custom pattern",
    "another pattern"
  ]
}
```

### Custom Folder Structure

Enable date organization to create a hierarchical structure:

```json
{
  "organize_by_date": true,
  "date_format": "%Y/%m"
}
```

This creates folders like: `Articles/2025/06/`

## Uninstallation

To remove the organizer:

```bash
# Stop and disable service
rm2-service stop
systemctl disable rm2-organizer
rm -f /etc/systemd/system/rm2-organizer.service

# Remove application files
rm -rf /home/root/.rm2_organizer
rm -rf /home/root/bin/rm2_organizer.py
rm -rf /home/root/bin/organize-articles
rm -rf /home/root/bin/rm2-service

# Clean up PATH (optional)
# Remove the PATH export line from /home/root/.bashrc if desired

systemctl daemon-reload
```

## Safety Notes

- **Update Persistence**: All files stored in `/home/root/` survive system updates
- **No Document Deletion**: The script only moves documents, never deletes them
- **Comprehensive Logging**: All operations are logged for audit purposes
- **Original Structure Preserved**: Document metadata and content remain intact
- **Easy Recovery**: Simple reinstall script for post-update restoration

## System Update Workflow

### **Fully Automatic (Recommended)**
1. **Before Update**: No action needed - all data persists
2. **During Update**: System wipes `/etc/systemd/` but preserves `/home/root/`
3. **After Update**: Next SSH login automatically detects and restores the service
4. **Verification**: Check with `rm2-service status`

### **Manual Control**
If you prefer to handle recovery manually:
```bash
# Disable auto-recovery (optional)
sed -i '/rm2_organizer auto-recovery/,/^$/d' /home/root/.bashrc

# Manual restore when needed
/home/root/.rm2_organizer/reinstall-after-update.sh
```

The tool seamlessly adapts to system changes while preserving your configuration and reading history.

## Contributing

This tool is designed to be customizable. Feel free to modify the detection patterns and organization logic to suit your needs.