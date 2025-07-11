#!/bin/bash
# Quick recovery wrapper - ensures dependencies and runs recovery
# For use when you just cloned the repo and need to recover NOW

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "🚨 Quick Recovery Wrapper"
echo "========================"
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERROR]${NC} This script must be run as root"
    echo "Please run: sudo ./quick-recovery.sh"
    exit 1
fi

echo -e "${BLUE}[INFO]${NC} Checking system type..."

# Detect if we have apt (Ubuntu/Debian)
if ! command -v apt >/dev/null 2>&1; then
    echo -e "${RED}[ERROR]${NC} This script requires apt (Ubuntu/Debian systems)"
    echo "For other distributions, please install cryptsetup manually and run ./auto-recovery.sh"
    exit 1
fi

echo -e "${BLUE}[INFO]${NC} Checking for required tools..."

# Check and install cryptsetup if needed
if ! command -v cryptsetup >/dev/null 2>&1; then
    echo -e "${YELLOW}[WARNING]${NC} cryptsetup not found - needed for encrypted systems"
    echo -e "${BLUE}[INFO]${NC} Installing cryptsetup..."
    
    # Update package list first
    apt update 2>/dev/null || echo -e "${YELLOW}[WARNING]${NC} Could not update package list"
    
    # Install cryptsetup
    if apt install -y cryptsetup; then
        echo -e "${GREEN}[SUCCESS]${NC} cryptsetup installed successfully"
    else
        echo -e "${YELLOW}[WARNING]${NC} Could not install cryptsetup - encrypted partitions won't work"
    fi
else
    echo -e "${GREEN}[OK]${NC} cryptsetup is already installed"
fi

# Make scripts executable
echo -e "${BLUE}[INFO]${NC} Setting script permissions..."
chmod +x auto-recovery.sh test-recovery-env.sh 2>/dev/null || true

# Run diagnostic test first
echo
echo -e "${BLUE}[INFO]${NC} Running system diagnostic..."
echo "========================================="
./test-recovery-env.sh

echo
echo "========================================="
echo -e "${BLUE}[INFO]${NC} Diagnostic complete. Starting recovery..."
echo
read -p "Press Enter to continue with recovery, or Ctrl+C to cancel..."
echo

# Run the main recovery script
./auto-recovery.sh 