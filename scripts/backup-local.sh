#!/bin/bash
# Backup script for critical local files that should stay gitignored
# Creates timestamped backup of scripts/, CLAUDE.local.md, and other local configs

# Get project name from current directory path
PROJECT_NAME=$(basename "$(pwd)")

# Create backup filename with timestamp
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Create backup directory structure if it doesn't exist
BACKUP_DIR="../__Backups/$PROJECT_NAME"
mkdir -p "$BACKUP_DIR"

BACKUP_FILE="$BACKUP_DIR/$PROJECT_NAME-local-backup-$TIMESTAMP.tar.gz"

echo "Creating backup of local files..."
echo "Backup file: $BACKUP_FILE"

# Create tar.gz backup of all critical local files
tar -czf "$BACKUP_FILE" \
    scripts/ \
    CLAUDE.local.md \
    2>/dev/null || true

# Check if backup was created successfully
if [ -f "$BACKUP_FILE" ]; then
    echo "✅ Backup created successfully: $BACKUP_FILE"
    echo "Files backed up:"
    echo "  - scripts/ directory (build scripts, local helpers)"
    echo "  - CLAUDE.local.md (local behavior directives)"

    # Show backup file size
    BACKUP_SIZE=$(ls -lh "$BACKUP_FILE" | awk '{print $5}')
    echo "Backup size: $BACKUP_SIZE"

	echo "  "
	echo "Copying to Dropbox for cloud backup..."
	# Copy backup to Dropbox folder if it exists
	DROPBOX_DIR="/Volumes/Storage/Dead Crow Customs Dropbox/Steve Presley/Projects/__Backups/$PROJECT_NAME"
	mkdir -p "$DROPBOX_DIR"
	if [ -d "$DROPBOX_DIR" ]; then
		cp "$BACKUP_FILE" "$DROPBOX_DIR/"
		echo "✅ Backup copied to Dropbox: $DROPBOX_DIR/$(basename "$BACKUP_FILE")"
	else
		echo "⚠️ Dropbox directory not found, skipping Dropbox copy."
	fi

	exit 0
else
    echo "❌ Backup creation failed"
    exit 1
fi
