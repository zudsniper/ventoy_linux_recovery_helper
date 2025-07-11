#!/bin/bash
# Test script for recovery environment
# Tests partition detection and basic recovery readiness

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "🔍 Recovery Environment Diagnostic Test"
echo "======================================"
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERROR]${NC} This script must be run as root (use sudo)"
    exit 1
fi

echo -e "${BLUE}[TEST]${NC} System Information:"
uname -a
echo

echo -e "${BLUE}[TEST]${NC} Available Block Devices:"
lsblk -f
echo

echo -e "${BLUE}[TEST]${NC} Disk Partitions (excluding loop devices):"
lsblk -f | grep -v loop | grep -E "(ext4|btrfs|xfs|vfat|fat32)"
echo

echo -e "${BLUE}[TEST]${NC} Detecting potential root partitions:"
ROOT_CANDIDATES=$(lsblk -f | grep -E "(ext4|btrfs|xfs)" | grep -v -E "(boot|loop)" | head -5)
if [ -n "$ROOT_CANDIDATES" ]; then
    echo -e "${GREEN}[FOUND]${NC} Potential root partitions:"
    echo "$ROOT_CANDIDATES"
else
    echo -e "${RED}[WARNING]${NC} No potential root partitions found"
fi
echo

echo -e "${BLUE}[TEST]${NC} Detecting potential boot partitions:"
BOOT_CANDIDATES=$(lsblk -f | grep -iE "(boot|efi)" | grep -v "loop")
if [ -n "$BOOT_CANDIDATES" ]; then
    echo -e "${GREEN}[FOUND]${NC} Potential boot partitions:"
    echo "$BOOT_CANDIDATES"
else
    echo -e "${YELLOW}[INFO]${NC} No separate boot partitions found (system may use root partition for /boot)"
fi
echo

echo -e "${BLUE}[TEST]${NC} Mount points:"
mount | grep -E "(ext4|btrfs|xfs|vfat)" | grep -v loop
echo

echo -e "${BLUE}[TEST]${NC} Testing directory creation:"
TEST_DIR="/tmp/recovery_test_$$"
if mkdir -p "$TEST_DIR"; then
    echo -e "${GREEN}[PASS]${NC} Can create directories"
    rmdir "$TEST_DIR"
else
    echo -e "${RED}[FAIL]${NC} Cannot create directories"
fi
echo

echo -e "${BLUE}[TEST]${NC} Required tools check:"
TOOLS="mount umount chroot fsck lsblk"
for tool in $TOOLS; do
    if command -v $tool >/dev/null 2>&1; then
        echo -e "${GREEN}[PASS]${NC} $tool is available"
    else
        echo -e "${RED}[FAIL]${NC} $tool is NOT available"
    fi
done
echo

echo -e "${BLUE}[TEST]${NC} Network connectivity:"
if ping -c 1 google.com >/dev/null 2>&1; then
    echo -e "${GREEN}[PASS]${NC} Internet connection is available"
else
    echo -e "${YELLOW}[WARNING]${NC} No internet connection (recovery will work but tool installation may fail)"
fi
echo

echo "======================================"
echo -e "${GREEN}Diagnostic test complete!${NC}"
echo
echo "Next steps:"
echo "1. Review the output above to ensure your partitions are detected"
echo "2. If partitions look correct, run: sudo ./auto-recovery.sh"
echo "3. If partitions are not detected properly, use manual selection in auto-recovery.sh"
echo 