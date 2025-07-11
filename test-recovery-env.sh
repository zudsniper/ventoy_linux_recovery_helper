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

echo -e "${BLUE}[TEST]${NC} Partition Sizes:"
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT | grep -v loop
echo

echo -e "${BLUE}[TEST]${NC} Disk Partitions (excluding loop devices):"
lsblk -f | grep -v loop | grep -E "(ext4|btrfs|xfs|vfat|fat32|crypto)"
echo

echo -e "${BLUE}[TEST]${NC} Detecting encrypted partitions:"
CRYPTO_PARTS=$(lsblk -f | grep "crypto" | awk '{print $1}' | sed 's/[├└─]//g' | xargs)
if [ -n "$CRYPTO_PARTS" ]; then
    echo -e "${YELLOW}[FOUND]${NC} Encrypted partitions detected:"
    for part in $CRYPTO_PARTS; do
        echo "  - /dev/$part (LUKS encrypted)"
        # Check if already unlocked
        if ls /dev/mapper/* 2>/dev/null | grep -q "${part}"; then
            echo "    Status: Already unlocked"
        else
            echo "    Status: Locked (will need passphrase)"
        fi
    done
else
    echo -e "${GREEN}[INFO]${NC} No encrypted partitions found"
fi
echo

echo -e "${BLUE}[TEST]${NC} Detecting potential root partitions:"
# Look for large ext4/btrfs/xfs partitions
ROOT_CANDIDATES=$(lsblk -f -b | grep -E "(ext4|btrfs|xfs)" | grep -v "loop" | while read line; do
    part=$(echo "$line" | awk '{print $1}' | sed 's/[├└─]//g')
    size=$(lsblk -b -n -o SIZE "/dev/$part" 2>/dev/null || echo 0)
    size_gb=$((size / 1073741824))
    if [ "$size" -gt 5368709120 ]; then  # > 5GB
        echo "  - /dev/$part ($(lsblk -n -o FSTYPE /dev/$part), ${size_gb}GB)"
    fi
done)

if [ -n "$ROOT_CANDIDATES" ]; then
    echo -e "${GREEN}[FOUND]${NC} Potential root partitions (>5GB):"
    echo "$ROOT_CANDIDATES"
else
    echo -e "${RED}[WARNING]${NC} No potential root partitions found"
    echo "  Note: Your root partition might be encrypted"
fi
echo

echo -e "${BLUE}[TEST]${NC} Detecting boot/EFI partitions:"
# EFI partitions
EFI_PARTS=$(lsblk -f | grep -E "(vfat|FAT)" | grep -v loop | awk '{print $1}' | sed 's/[├└─]//g')
if [ -n "$EFI_PARTS" ]; then
    echo -e "${GREEN}[FOUND]${NC} EFI partition(s):"
    for part in $EFI_PARTS; do
        size=$(lsblk -h -n -o SIZE "/dev/$part" 2>/dev/null || echo "unknown")
        echo "  - /dev/$part (FAT32, $size)"
    done
fi

# Small ext4 partitions (likely /boot)
BOOT_PARTS=$(lsblk -f -b | grep -E "ext4" | grep -v loop | while read line; do
    part=$(echo "$line" | awk '{print $1}' | sed 's/[├└─]//g')
    size=$(lsblk -b -n -o SIZE "/dev/$part" 2>/dev/null || echo 0)
    if [ "$size" -lt 2147483648 ] && [ "$size" -gt 0 ]; then  # < 2GB
        size_mb=$((size / 1048576))
        echo "  - /dev/$part (ext4, ${size_mb}MB)"
    fi
done)

if [ -n "$BOOT_PARTS" ]; then
    echo -e "${GREEN}[FOUND]${NC} Potential /boot partition(s) (<2GB):"
    echo "$BOOT_PARTS"
fi

if [ -z "$EFI_PARTS" ] && [ -z "$BOOT_PARTS" ]; then
    echo -e "${YELLOW}[INFO]${NC} No separate boot/EFI partitions found"
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
TOOLS="mount umount chroot fsck lsblk cryptsetup"
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
echo "Summary for your system:"
if [ -n "$CRYPTO_PARTS" ]; then
    echo -e "${YELLOW}⚠️  Your system uses disk encryption${NC}"
    echo "   The recovery script will prompt for your passphrase"
fi
echo
echo "Next steps:"
echo "1. Run: sudo ./auto-recovery.sh"
echo "2. If prompted about encryption, answer 'y' and enter your passphrase"
echo "3. The script will handle mounting and recovery automatically"
echo 