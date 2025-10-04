#!/bin/bash

################################################################################
# cPanel Bulk Package Updater
# 
# Description: Bulk update cPanel account packages via WHM API
# Author: temitrace
# License: MIT
# Version: 1.0.0
#
# Usage: 
#   1. Create text files named after your packages (lowercase)
#   2. Add usernames to each file (one per line)
#   3. Update the package names in the "Main execution" section below
#   4. Run: ./bulk_package_update.sh
#
################################################################################

# Configuration
SCRIPT_DIR="/root/cpanel-bulk-package-updater"
LOGFILE="$SCRIPT_DIR/bulk_package_update_$(date +%Y%m%d_%H%M%S).log"
DELAY=1  # Delay between each API call (seconds) - increase for heavily loaded servers

# Create directory if it doesn't exist
mkdir -p "$SCRIPT_DIR"
cd "$SCRIPT_DIR"

# Color codes for output (optional, remove if not needed)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

################################################################################
# Function: process_package
# Description: Processes a single package file and updates all users
# Parameters:
#   $1 - Package name (capitalized, as appears in WHM)
#   $2 - Filename (lowercase)
################################################################################
process_package() {
    local package_name="$1"
    local filename="$2"
    local count=0
    local success=0
    local failed=0
    
    # Check if file exists
    if [ ! -f "$SCRIPT_DIR/$filename" ]; then
        echo "Warning: File $SCRIPT_DIR/$filename not found. Skipping $package_name package." | tee -a "$LOGFILE"
        return
    fi
    
    # Check if file is not empty
    if [ ! -s "$SCRIPT_DIR/$filename" ]; then
        echo "Warning: File $SCRIPT_DIR/$filename is empty. Skipping $package_name package." | tee -a "$LOGFILE"
        return
    fi
    
    echo "Processing $package_name package from file: $SCRIPT_DIR/$filename" | tee -a "$LOGFILE"
    echo "----------------------------------------" | tee -a "$LOGFILE"
    
    # Read file line by line
    while IFS= read -r username || [ -n "$username" ]; do
        # Skip empty lines and comments (lines starting with #)
        if [[ -z "$username" || "$username" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        # Remove any leading/trailing whitespace
        username=$(echo "$username" | xargs)
        count=$((count + 1))
        
        # Check if user exists on server
        if [ ! -f "/var/cpanel/users/$username" ]; then
            echo "[$count] ERROR: User $username not found on server" | tee -a "$LOGFILE"
            failed=$((failed + 1))
            continue
        fi
        
        # Get current package
        current_pkg=$(grep "PLAN=" /var/cpanel/users/$username 2>/dev/null | cut -d'=' -f2)
        
        echo "[$count] UPDATING: $username ($current_pkg -> $package_name)" | tee -a "$LOGFILE"
        
        # Execute the package change (always update to fix specs)
        if whmapi1 changepackage user="$username" pkg="$package_name" >> "$LOGFILE" 2>&1; then
            echo "[$count] SUCCESS: $username updated to $package_name" | tee -a "$LOGFILE"
            success=$((success + 1))
        else
            echo "[$count] FAILED: $username could not be updated to $package_name" | tee -a "$LOGFILE"
            failed=$((failed + 1))
        fi
        
        # Small delay to prevent overwhelming the server
        sleep $DELAY
        
    done < "$SCRIPT_DIR/$filename"
    
    echo "" | tee -a "$LOGFILE"
    echo "$package_name Summary: $success successful, $failed failed, $count total processed" | tee -a "$LOGFILE"
    echo "========================================" | tee -a "$LOGFILE"
    echo "" | tee -a "$LOGFILE"
}

################################################################################
# Main execution
################################################################################

echo "========================================" | tee "$LOGFILE"
echo "cPanel Bulk Package Updater v1.0.0" | tee -a "$LOGFILE"
echo "========================================" | tee -a "$LOGFILE"
echo "Bulk Package Assignment Started: $(date)" | tee -a "$LOGFILE"
echo "Log file: $LOGFILE" | tee -a "$LOGFILE"
echo "" | tee -a "$LOGFILE"

# Check if files exist
echo "Checking for package files in $SCRIPT_DIR..." | tee -a "$LOGFILE"

# IMPORTANT: Update these package names to match YOUR cPanel packages
# Format: "PackageName" corresponds to file "packagename" (lowercase)
PACKAGES=("Basic:basic" "Standard:standard" "Premium:premium" "Enterprise:enterprise")

for pkg_pair in "${PACKAGES[@]}"; do
    IFS=':' read -r pkg_display pkg_file <<< "$pkg_pair"
    if [ -f "$SCRIPT_DIR/$pkg_file" ]; then
        line_count=$(wc -l < "$SCRIPT_DIR/$pkg_file")
        echo "Found: $SCRIPT_DIR/$pkg_file ($line_count users)" | tee -a "$LOGFILE"
    else
        echo "Missing: $SCRIPT_DIR/$pkg_file" | tee -a "$LOGFILE"
    fi
done
echo "" | tee -a "$LOGFILE"

# Confirmation prompt (comment out if you want to run without confirmation)
echo "This will update all accounts in the package files listed above."
read -p "Do you want to continue? (yes/no): " confirm
if [[ $confirm != "yes" ]]; then
    echo "Operation cancelled by user." | tee -a "$LOGFILE"
    exit 0
fi
echo "" | tee -a "$LOGFILE"

################################################################################
# CONFIGURE YOUR PACKAGES HERE
# Update these lines to match your actual cPanel package names
# First parameter: Package name as it appears in WHM (case-sensitive)
# Second parameter: Filename (lowercase, no extension)
################################################################################

process_package "Basic" "basic"
process_package "Standard" "standard"
process_package "Premium" "premium"
process_package "Enterprise" "enterprise"

# Add more packages as needed:
# process_package "YourPackageName" "yourfilename"

################################################################################
# Final summary
################################################################################

echo "========================================" | tee -a "$LOGFILE"
echo "Bulk Package Assignment Completed: $(date)" | tee -a "$LOGFILE"
echo "========================================" | tee -a "$LOGFILE"
echo "Full log available at: $LOGFILE"
echo ""
echo "To review the log:"
echo "  cat $LOGFILE"
echo ""
echo "To search for errors:"
echo "  grep ERROR $LOGFILE"
echo "  grep FAILED $LOGFILE"
