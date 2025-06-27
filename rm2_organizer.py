#!/usr/bin/env python3
"""
reMarkable 2 Article Organizer
Automatically moves articles sent via Chrome extension to a designated folder
"""

import os
import json
import time
import shutil
import logging
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional
import argparse

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/home/root/.rm2_organizer/organizer.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class RemarkableOrganizer:
    def __init__(self, config_file: str = '/home/root/.rm2_organizer/config.json'):
        self.config_file = config_file
        self.config = self.load_config()
        self.documents_path = Path('/home/root/.local/share/remarkable/xochitl')
        self.processed_files = set()
        self.reading_state_file = '/home/root/.rm2_organizer/reading_state.json'
        self.reading_state = self.load_reading_state()
        
    def load_config(self) -> Dict:
        """Load configuration from JSON file"""
        default_config = {
            "folders": {
                "to_read": "To Read",
                "read": "Read Articles", 
                "archive": "Archived Articles"
            },
            "source_patterns": [
                "read on remarkable",
                "chrome extension",
                "web article"
            ],
            "poll_interval": 30,
            "file_age_threshold": 5,
            "create_folders_if_missing": True,
            "organize_by_date": False,
            "date_format": "%Y-%m-%d",
            "reading_detection": {
                "enable_auto_move": True,
                "pages_threshold": 0.8,
                "time_threshold": 300,
                "annotation_indicates_read": True,
                "bookmark_indicates_progress": True
            },
            "archive_read_articles": {
                "enable": False,
                "days_threshold": 30
            }
        }
        
        try:
            if os.path.exists(self.config_file):
                with open(self.config_file, 'r') as f:
                    config = json.load(f)
                # Merge with defaults
                for key, value in default_config.items():
                    if key not in config:
                        config[key] = value
                return config
            else:
                # Create default config file
                with open(self.config_file, 'w') as f:
                    json.dump(default_config, f, indent=2)
                logger.info(f"Created default config file at {self.config_file}")
                return default_config
                
        except Exception as e:
            logger.error(f"Error loading config: {e}")
            return default_config
    
    def get_documents_metadata(self) -> Dict[str, Dict]:
        """Get metadata for all documents"""
        metadata = {}
        
        for metadata_file in self.documents_path.glob('*.metadata'):
            try:
                with open(metadata_file, 'r') as f:
                    data = json.load(f)
                    doc_id = metadata_file.stem
                    metadata[doc_id] = data
            except Exception as e:
                logger.warning(f"Error reading metadata file {metadata_file}: {e}")
                
        return metadata
    
    def load_reading_state(self) -> Dict:
        """Load reading state tracking data"""
        try:
            if os.path.exists(self.reading_state_file):
                with open(self.reading_state_file, 'r') as f:
                    return json.load(f)
            else:
                return {}
        except Exception as e:
            logger.error(f"Error loading reading state: {e}")
            return {}
    
    def save_reading_state(self):
        """Save reading state tracking data"""
        try:
            with open(self.reading_state_file, 'w') as f:
                json.dump(self.reading_state, f, indent=2)
        except Exception as e:
            logger.error(f"Error saving reading state: {e}")
    
    def get_document_content(self, doc_id: str) -> Optional[Dict]:
        """Get document content data"""
        try:
            content_file = self.documents_path / f"{doc_id}.content"
            if content_file.exists():
                with open(content_file, 'r') as f:
                    return json.load(f)
        except Exception as e:
            logger.warning(f"Error reading content file for {doc_id}: {e}")
        return None
    
    def get_document_pagedata(self, doc_id: str) -> List[Dict]:
        """Get page data for a document"""
        pagedata = []
        try:
            # Look for page files
            for page_file in self.documents_path.glob(f"{doc_id}/*.rm"):
                page_path = page_file.parent / f"{page_file.stem}-metadata.json"
                if page_path.exists():
                    with open(page_path, 'r') as f:
                        page_meta = json.load(f)
                        pagedata.append(page_meta)
        except Exception as e:
            logger.warning(f"Error reading page data for {doc_id}: {e}")
        return pagedata
    
    def analyze_reading_progress(self, doc_id: str, metadata: Dict) -> Dict:
        """Analyze reading progress for a document"""
        analysis = {
            'pages_read': 0,
            'total_pages': 0,
            'has_annotations': False,
            'has_bookmarks': False,
            'last_opened': 0,
            'reading_time': 0,
            'completion_ratio': 0.0,
            'likely_read': False
        }
        
        try:
            # Get last modified time
            analysis['last_opened'] = int(metadata.get('lastOpened', 0))
            
            # Get content data
            content = self.get_document_content(doc_id)
            if content:
                # Count total pages
                analysis['total_pages'] = len(content.get('pages', []))
                
                # Check for bookmarks
                if content.get('bookmarks'):
                    analysis['has_bookmarks'] = True
                
                # Analyze page data for annotations and reading progress
                pages_data = self.get_document_pagedata(doc_id)
                annotated_pages = 0
                
                for page_data in pages_data:
                    # Check for annotations (strokes, highlights, etc.)
                    if page_data.get('layers'):
                        for layer in page_data['layers']:
                            if layer.get('strokes') or layer.get('highlights'):
                                annotated_pages += 1
                                analysis['has_annotations'] = True
                                break
                
                # Estimate reading progress based on annotations and access patterns
                if analysis['total_pages'] > 0:
                    # Basic heuristic: pages with annotations or estimated reading progress
                    if annotated_pages > 0:
                        analysis['pages_read'] = annotated_pages
                    else:
                        # Fallback: estimate based on last opened time and access patterns
                        current_time = time.time()
                        time_since_opened = current_time - (analysis['last_opened'] / 1000)
                        
                        # If opened recently and multiple times, assume some progress
                        if time_since_opened < 86400:  # Within 24 hours
                            analysis['pages_read'] = min(analysis['total_pages'], 
                                                       max(1, analysis['total_pages'] // 4))
                    
                    analysis['completion_ratio'] = analysis['pages_read'] / analysis['total_pages']
            
            # Check previous reading state
            if doc_id in self.reading_state:
                prev_state = self.reading_state[doc_id]
                prev_opened = prev_state.get('last_opened', 0)
                
                # Calculate reading time based on access pattern
                if analysis['last_opened'] > prev_opened:
                    session_time = min(3600, analysis['last_opened'] - prev_opened)  # Max 1 hour per session
                    analysis['reading_time'] = prev_state.get('reading_time', 0) + session_time
                else:
                    analysis['reading_time'] = prev_state.get('reading_time', 0)
            
            # Determine if likely read based on multiple factors
            reading_config = self.config.get('reading_detection', {})
            pages_threshold = reading_config.get('pages_threshold', 0.8)
            time_threshold = reading_config.get('time_threshold', 300)  # 5 minutes
            
            analysis['likely_read'] = (
                analysis['completion_ratio'] >= pages_threshold or
                (reading_config.get('annotation_indicates_read', True) and 
                 analysis['has_annotations'] and analysis['completion_ratio'] > 0.3) or
                analysis['reading_time'] >= time_threshold
            )
            
        except Exception as e:
            logger.error(f"Error analyzing reading progress for {doc_id}: {e}")
        
        return analysis
        """Find the ID of a folder by name"""
        for doc_id, data in metadata.items():
            if (data.get('type') == 'CollectionType' and 
                data.get('visibleName') == folder_name and
                not data.get('deleted', False)):
                return doc_id
        return None
    
    def create_folder(self, folder_name: str) -> str:
        """Create a new folder and return its ID"""
        import uuid
        
        folder_id = str(uuid.uuid4())
        folder_metadata = {
            "deleted": False,
            "lastModified": str(int(time.time() * 1000)),
            "metadatamodified": True,
            "modified": True,
            "parent": "",
            "pinned": False,
            "synced": False,
            "type": "CollectionType",
            "version": 1,
            "visibleName": folder_name
        }
        
        metadata_file = self.documents_path / f"{folder_id}.metadata"
        content_file = self.documents_path / f"{folder_id}.content"
        
        # Write metadata
        with open(metadata_file, 'w') as f:
            json.dump(folder_metadata, f)
            
        # Write empty content file
        with open(content_file, 'w') as f:
            json.dump({}, f)
            
        logger.info(f"Created folder '{folder_name}' with ID {folder_id}")
        return folder_id
    
    def is_article_document(self, metadata: Dict) -> bool:
        """Check if a document is likely an article from Chrome extension"""
        if metadata.get('type') != 'DocumentType':
            return False
            
        if metadata.get('deleted', False):
            return False
            
        visible_name = metadata.get('visibleName', '').lower()
        
        # Check for patterns that indicate Chrome extension articles
        patterns = self.config.get('source_patterns', [])
        for pattern in patterns:
            if pattern.lower() in visible_name:
                return True
                
        # Additional heuristics
        # Articles from Chrome extension often have URLs or web-like names
        if any(indicator in visible_name for indicator in [
            'http', 'www.', '.com', '.org', '.net', 'article', 'blog'
        ]):
            return True
            
        return False
    
    def move_document_to_folder(self, doc_id: str, folder_id: str, metadata: Dict[str, Dict]):
        """Move a document to the specified folder"""
        try:
            # Update document metadata
            doc_metadata = metadata[doc_id].copy()
            doc_metadata['parent'] = folder_id
            doc_metadata['lastModified'] = str(int(time.time() * 1000))
            doc_metadata['metadatamodified'] = True
            doc_metadata['modified'] = True
            
            # Write updated metadata
            metadata_file = self.documents_path / f"{doc_id}.metadata"
            with open(metadata_file, 'w') as f:
                json.dump(doc_metadata, f)
                
            doc_name = doc_metadata.get('visibleName', doc_id)
            logger.info(f"Moved document '{doc_name}' to folder")
            
        except Exception as e:
            logger.error(f"Error moving document {doc_id}: {e}")
    
    def get_document_current_folder(self, doc_id: str, metadata: Dict[str, Dict]) -> Optional[str]:
        """Get the current folder type for a document"""
        doc_metadata = metadata.get(doc_id)
        if not doc_metadata:
            return None
            
        parent_id = doc_metadata.get('parent', '')
        if not parent_id:
            return 'root'
            
        # Find which configured folder this document is in
        folders = self.config.get('folders', {})
        for folder_type, folder_name in folders.items():
            folder_id = self.find_folder_id(folder_name, metadata)
            if folder_id == parent_id:
                return folder_type
                
        return 'other'
    
    def should_move_to_read_folder(self, doc_id: str, analysis: Dict) -> bool:
        """Determine if document should be moved to read folder"""
        if not self.config.get('reading_detection', {}).get('enable_auto_move', True):
            return False
            
        return analysis.get('likely_read', False)
    
    def should_archive_document(self, doc_id: str, analysis: Dict) -> bool:
        """Determine if document should be archived"""
        archive_config = self.config.get('archive_read_articles', {})
        if not archive_config.get('enable', False):
            return False
            
        if not analysis.get('likely_read', False):
            return False
            
        days_threshold = archive_config.get('days_threshold', 30)
        current_time = time.time()
        last_opened = analysis.get('last_opened', 0) / 1000
        
        days_since_read = (current_time - last_opened) / 86400
        return days_since_read >= days_threshold
        """Create date-based subfolder if organize_by_date is enabled"""
        if not self.config.get('organize_by_date', False):
            return folder_id
            
        try:
            # Get document creation date
            last_modified = int(doc_metadata.get('lastModified', 0))
            if last_modified:
                date_obj = datetime.fromtimestamp(last_modified / 1000)
                date_str = date_obj.strftime(self.config.get('date_format', '%Y-%m-%d'))
            else:
                date_str = datetime.now().strftime(self.config.get('date_format', '%Y-%m-%d'))
                
            # Check if date folder exists, create if not
            metadata = self.get_documents_metadata()
            date_folder_id = None
            
            for doc_id, data in metadata.items():
                if (data.get('type') == 'CollectionType' and 
                    data.get('visibleName') == date_str and
                    data.get('parent') == folder_id and
                    not data.get('deleted', False)):
                    date_folder_id = doc_id
                    break
                    
            if not date_folder_id:
                date_folder_id = self.create_date_folder(date_str, folder_id)
                
            return date_folder_id
            
        except Exception as e:
            logger.error(f"Error creating date folder: {e}")
            return folder_id
    
    def create_date_folder(self, date_str: str, parent_id: str) -> str:
        """Create a date-based subfolder"""
        import uuid
        
        folder_id = str(uuid.uuid4())
        folder_metadata = {
            "deleted": False,
            "lastModified": str(int(time.time() * 1000)),
            "metadatamodified": True,
            "modified": True,
            "parent": parent_id,
            "pinned": False,
            "synced": False,
            "type": "CollectionType",
            "version": 1,
            "visibleName": date_str
        }
        
        metadata_file = self.documents_path / f"{folder_id}.metadata"
        content_file = self.documents_path / f"{folder_id}.content"
        
        with open(metadata_file, 'w') as f:
            json.dump(folder_metadata, f)
            
        with open(content_file, 'w') as f:
            json.dump({}, f)
            
        logger.info(f"Created date folder '{date_str}' with ID {folder_id}")
        return folder_id
    
    def process_new_articles(self):
        """Main processing function to organize new articles"""
        try:
            metadata = self.get_documents_metadata()
            
            # Ensure all required folders exist
            folder_ids = self.ensure_folders_exist(metadata)
            if not folder_ids:
                logger.error("Could not create or find required folders")
                return
            
            # Process articles and track reading status
            articles_processed = 0
            articles_moved_to_read = 0
            articles_archived = 0
            file_age_threshold = self.config.get('file_age_threshold', 5)
            current_time = time.time()
            
            for doc_id, doc_metadata in metadata.items():
                if not self.is_article_document(doc_metadata):
                    continue
                    
                # Check if file is recent enough (skip very new files)
                last_modified = int(doc_metadata.get('lastModified', 0)) / 1000
                if current_time - last_modified < file_age_threshold * 60:
                    continue
                
                # Analyze reading progress
                analysis = self.analyze_reading_progress(doc_id, doc_metadata)
                
                # Update reading state
                self.reading_state[doc_id] = {
                    'last_opened': analysis['last_opened'],
                    'reading_time': analysis['reading_time'],
                    'completion_ratio': analysis['completion_ratio'],
                    'has_annotations': analysis['has_annotations'],
                    'last_checked': int(current_time)
                }
                
                # Determine current folder location
                current_folder_type = self.get_document_current_folder(doc_id, metadata)
                doc_name = doc_metadata.get('visibleName', doc_id)
                
                # Determine target folder based on reading status and current location
                target_folder_type = None
                
                if current_folder_type == 'root' and doc_id not in self.processed_files:
                    # New article - move to "to_read" folder
                    target_folder_type = 'to_read'
                    articles_processed += 1
                    self.processed_files.add(doc_id)
                    
                elif current_folder_type == 'to_read' and self.should_move_to_read_folder(doc_id, analysis):
                    # Article has been read - move to "read" folder
                    target_folder_type = 'read'
                    articles_moved_to_read += 1
                    logger.info(f"Article '{doc_name}' appears to have been read (completion: {analysis['completion_ratio']:.1%})")
                    
                elif current_folder_type == 'read' and self.should_archive_document(doc_id, analysis):
                    # Old read article - move to archive
                    target_folder_type = 'archive'
                    articles_archived += 1
                    logger.info(f"Archiving old article '{doc_name}'")
                
                # Move document if target folder is different
                if target_folder_type and target_folder_type in folder_ids:
                    target_folder_id = folder_ids[target_folder_type]
                    
                    # Apply date organization if enabled
                    final_folder_id = self.organize_by_date_if_enabled(target_folder_id, doc_metadata)
                    
                    # Move the document
                    self.move_document_to_folder(doc_id, final_folder_id, metadata)
                    
                    folder_name = self.config['folders'][target_folder_type]
                    logger.info(f"Moved '{doc_name}' to {folder_name}")
            
            # Save reading state
            self.save_reading_state()
            
            # Log summary
            if articles_processed > 0 or articles_moved_to_read > 0 or articles_archived > 0:
                logger.info(f"Processing summary: {articles_processed} new articles organized, "
                          f"{articles_moved_to_read} moved to read folder, "
                          f"{articles_archived} archived")
                
        except Exception as e:
            logger.error(f"Error processing articles: {e}")
    
    def run_daemon(self):
        """Run the organizer as a daemon"""
        poll_interval = self.config.get('poll_interval', 30)
        logger.info(f"Starting reMarkable organizer daemon (poll interval: {poll_interval}s)")
        
        try:
            while True:
                self.process_new_articles()
                time.sleep(poll_interval)
        except KeyboardInterrupt:
            logger.info("Daemon stopped by user")
        except Exception as e:
            logger.error(f"Daemon error: {e}")

def main():
    parser = argparse.ArgumentParser(description='reMarkable 2 Article Organizer')
    parser.add_argument('--config', default='/home/root/.rm2_organizer/config.json',
                       help='Path to configuration file')
    parser.add_argument('--daemon', action='store_true',
                       help='Run as daemon')
    parser.add_argument('--once', action='store_true',
                       help='Run once and exit')
    parser.add_argument('--install-service', action='store_true',
                       help='Install systemd service')
    
    args = parser.parse_args()
    
    if args.install_service:
        install_systemd_service()
        return
    
    organizer = RemarkableOrganizer(args.config)
    
    if args.daemon:
        organizer.run_daemon()
    else:
        organizer.process_new_articles()

def install_systemd_service():
    """Install systemd service for the organizer"""
    import os
    
    service_content = f"""[Unit]
Description=reMarkable 2 Article Organizer
After=multi-user.target

[Service]
Type=simple
ExecStart={os.path.abspath(__file__)} --daemon
Restart=always
RestartSec=10
User=root
Group=root
WorkingDirectory=/home/root

[Install]
WantedBy=multi-user.target
"""
    
    try:
        # Write service file
        with open('/etc/systemd/system/rm2-organizer.service', 'w') as f:
            f.write(service_content)
        
        # Reload systemd and enable service
        os.system('systemctl daemon-reload')
        os.system('systemctl enable rm2-organizer.service')
        
        print("✓ Systemd service installed and enabled")
        print("Start with: systemctl start rm2-organizer")
        
    except Exception as e:
        print(f"Error installing service: {e}")
        print("You may need to run with sudo privileges")

if __name__ == '__main__':
    main()