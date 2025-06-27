# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Python application for the reMarkable 2 tablet that automatically organizes articles sent via the Chrome "Read on reMarkable" extension. It monitors document metadata, tracks reading progress, and moves articles between folders based on their status.

## Common Development Tasks

### Running the Application

```bash
# Run once (manual mode)
python3 rm2_organizer.py --once

# Run in daemon mode (continuous monitoring)
python3 rm2_organizer.py --daemon

# Install systemd service
python3 rm2_organizer.py --install-service
```

### Testing Changes

Since this project doesn't include unit tests, testing is done manually:

```bash
# Test the script directly
python3 rm2_organizer.py --once

# Check logs for errors
tail -f /home/root/.rm2_organizer/organizer.log

# Verify reading state
cat /home/root/.rm2_organizer/reading_state.json | python3 -m json.tool
```

### Linting

This project uses pure Python with no external dependencies. To ensure code quality:

```bash
# Check Python syntax
python3 -m py_compile rm2_organizer.py

# Basic style check (if pylint available)
python3 -m pylint rm2_organizer.py || true
```

## Architecture and Key Components

### Core Files

- **rm2_organizer.py**: Main application containing all logic
  - `RemarkableOrganizer` class: Core functionality
  - Reading detection algorithm: Analyzes annotations, bookmarks, and access patterns
  - Folder management: Creates and organizes articles into "To Read", "Read Articles", and "Archived Articles"

- **rm2_organizer_install.sh**: Installation script that:
  - Sets up persistent file locations in `/home/root/` (survives system updates)
  - Creates systemd service
  - Adds auto-recovery mechanism to `.bashrc`
  - Creates convenience scripts

### Key Design Decisions

1. **Persistence Strategy**: All files stored in `/home/root/` instead of `/opt/` to survive reMarkable system updates
2. **Auto-Recovery**: Automatic service restoration after system updates via `.bashrc` check
3. **No External Dependencies**: Uses only Python standard library for maximum compatibility
4. **Reading Detection**: Multi-signal algorithm combining:
   - Page coverage analysis
   - Annotation density tracking
   - Time-based thresholds
   - Bookmark progression

### Data Flow

1. **Document Monitoring**: Scans `/home/root/.local/share/remarkable/xochitl/*.metadata` files
2. **Pattern Matching**: Identifies Chrome extension articles using configurable patterns
3. **State Tracking**: Maintains reading progress in `/home/root/.rm2_organizer/reading_state.json`
4. **Folder Organization**: Moves documents between folders based on reading status

### Configuration Structure

The application reads configuration from `/home/root/.rm2_organizer/config.json`:
- Folder names and structure
- Article detection patterns
- Reading detection thresholds
- Archive settings
- Date-based organization options

## Development Guidelines

### Making Changes

1. Always test changes directly on reMarkable device or in compatible environment
2. Preserve compatibility with reMarkable's limited Python environment
3. Maintain the no-dependency approach - use only standard library
4. Consider the device's limited resources when implementing features

### Important Paths

- **reMarkable documents**: `/home/root/.local/share/remarkable/xochitl/`
- **Application data**: `/home/root/.rm2_organizer/`
- **Systemd service**: `/etc/systemd/system/rm2-organizer.service`

### Debugging

Enable debug logging by modifying the logging level in rm2_organizer.py:
```python
logging.basicConfig(level=logging.DEBUG, ...)
```

Check system logs:
```bash
journalctl -u rm2-organizer -f
```