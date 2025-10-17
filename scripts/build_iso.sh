#!/usr/bin/env bash
set -e

# Build Omarchy ISO with Advanced Mode features
# This script builds the ISO from the feature/advanced-mode branch
# and uses the omarchy installer from the feature/omarchy-advanced branch

# Create release directory if it doesn't exist
mkdir -p release

# Generate temporary log file (we'll rename it to match the ISO later)
TEMP_LOG_FILE="release/build_log_temp_$$.txt"

echo "Building Omarchy ISO with Advanced Mode features..."
echo ""
echo "Configuration:"
echo "  ISO Branch: feature/advanced-mode"
echo "  Installer Repo: stevepresley/omarchy"
echo "  Installer Branch: feature/omarchy-advanced"
echo ""

# Set environment variables for the build
export OMARCHY_INSTALLER_REPO="stevepresley/omarchy"
export OMARCHY_INSTALLER_REF="feature/omarchy-advanced"

# Track start time
START_TIME=$(date +%s)

# Run the build with logging (tee shows output AND logs to file)
# --no-boot-offer skips the interactive "Boot ISO?" prompt
./bin/omarchy-iso-make --no-boot-offer 2>&1 | tee "$TEMP_LOG_FILE"
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
    echo "Build log: $TEMP_LOG_FILE"
    echo "========================================="
  } >> "$TEMP_LOG_FILE"

  echo ""
  echo "❌ Build FAILED! (took ${MINUTES}m ${SECONDS}s)"
  echo "Build log: $TEMP_LOG_FILE"
  exit 1
fi

# Find the ISO that was just created and rename log to match
LATEST_ISO=$(ls -t release/*.iso | head -n1)
if [[ -f "$LATEST_ISO" ]]; then
  ISO_BASENAME="${LATEST_ISO%.iso}"
  FINAL_LOG_FILE="${ISO_BASENAME}_BUILD_LOG.txt"

  # Append build summary to log file before renaming
  {
    echo ""
    echo "========================================="
    echo "Build complete! (took ${MINUTES}m ${SECONDS}s)"
    echo "ISO: $LATEST_ISO"
    echo "Build log: $FINAL_LOG_FILE"
    echo "========================================="
  } >> "$TEMP_LOG_FILE"

  mv "$TEMP_LOG_FILE" "$FINAL_LOG_FILE"

  echo ""
  echo "Build complete! (took ${MINUTES}m ${SECONDS}s)"
  echo "ISO: $LATEST_ISO"
  echo "Build log: $FINAL_LOG_FILE"
else
  echo ""
  echo "Build completed but ISO not found in expected location"
  echo "Build log: $TEMP_LOG_FILE"
fi
