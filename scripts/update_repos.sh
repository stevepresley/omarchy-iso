#!/usr/bin/env bash
# Update both omarchy-advanced and omarchy-advanced-iso repositories
# to their latest versions from the feature branches

set -e

echo "Updating omarchy-advanced repository..."
cd ..
cd omarchy-advanced
git pull origin feature/omarchy-advanced

echo ""
echo "Updating omarchy-advanced-iso repository..."
cd ..
cd omarchy-advanced-iso
git pull origin feature/advanced-mode

echo ""
echo "✓ Both repositories updated successfully"
