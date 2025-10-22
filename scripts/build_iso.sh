#!/usr/bin/env bash
set -e

# FIRST: Update repos
cd ..
cd omarchy-advanced
git pull origin feature/omarchy-advanced
cd ..
cd omarchy-advanced-iso
git pull origin feature/advanced-mode

# SECOND: Log current commits immediately (before anything else)
echo "=========================================="
echo "Build Configuration & Current Commits:"
echo "=========================================="
echo "ISO Builder (omarchy-advanced-iso):"
git log -1 --oneline
echo ""
echo "Omarchy Installer (omarchy-advanced, feature/omarchy-advanced):"
(cd ../omarchy-advanced && git log -1 --oneline)
echo "=========================================="
echo ""

# Build Omarchy ISO with Advanced Mode features
# This script builds the ISO from the feature/advanced-mode branch
# and uses the omarchy installer from the feature/omarchy-advanced branch

# Create release directory if it doesn't exist
mkdir -p release

# Generate log file name matching existing convention
# Pattern: omarchy-{timestamp}-{arch}-{installer-branch}_BUILD_LOG.txt
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
ARCH="x86_64"
INSTALLER_BRANCH="feature/omarchy-advanced"
LOG_FILE="release/omarchy-${TIMESTAMP}-${ARCH}-${INSTALLER_BRANCH//\//-}_BUILD_LOG.txt"

echo "Building Omarchy ISO with Advanced Mode features..."
echo ""

# Set environment variables for the build
export OMARCHY_INSTALLER_REPO="stevepresley/omarchy"
export OMARCHY_INSTALLER_REF="feature/omarchy-advanced"

# Track start time
START_TIME=$(date +%s)

# Clean up previous build artifacts to avoid corruption
echo "Cleaning previous build cache..."
sudo rm -rf work/
sudo rm -rf ~/.cache/omarchy/
echo ""

# Run the build with logging (tee shows output AND logs to file)
# --no-boot-offer skips the interactive "Boot ISO?" prompt
./bin/omarchy-iso-make --no-boot-offer 2>&1 | tee -a "$LOG_FILE"
BUILD_EXIT_CODE=${PIPESTATUS[0]}

# Track end time and calculate duration
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

# Check if build failed
if [[ $BUILD_EXIT_CODE -ne 0 ]]; then
  {
    echo ""
    echo "========================================="
    echo "❌ Build FAILED! (took ${MINUTES}m ${SECONDS}s)"
    echo "Build log: $LOG_FILE"
    echo "========================================="
  } >> "$LOG_FILE"

  echo ""
  echo "❌ Build FAILED! (took ${MINUTES}m ${SECONDS}s)"
  echo "Build log: $LOG_FILE"
  exit 1
fi

# Build succeeded - append success message and optionally rename to match ISO
{
  echo ""
  echo "========================================="
  echo "✅ Build SUCCESS! (took ${MINUTES}m ${SECONDS}s)"
  echo "Build log: $LOG_FILE"
  echo "========================================="
} >> "$LOG_FILE"

echo ""
echo "✅ Build SUCCESS! (took ${MINUTES}m ${SECONDS}s)"
echo "Build log: $LOG_FILE"
