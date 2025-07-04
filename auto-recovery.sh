#!/bin/bash
# Auto-Recovery Script for Ubuntu/Debian Systems
# Created by Claude for Jason
set -e

echo "🚀 Auto-Recovery Script Starting..."
echo "=================================="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to detect root partition automatically
detect_root_partition() {
    log_info "Detecting root partition..."
    
    # Look for ext4/btrfs/xfs partitions that could be root
    ROOT_CANDIDATES=$(lsblk -f | grep -E "(ext4|btrfs|xfs)" | grep -v "boot" | head -5)
    
    if [ -z "$ROOT_CANDIDATES" ]; then
        log_error "No suitable root partitions found!"
        exit 1
    fi
    
    echo "Found potential root partitions:"
    echo "$ROOT_CANDIDATES"
    echo
    
    # Try to auto-detect the most likely root partition
    ROOT_PART=$(lsblk -f | grep -E "(ext4|btrfs|xfs)" | grep -v "boot" | head -1 | awk '{print $1}' | sed 's/[├└─]//g' | xargs)
    
    if [ -n "$ROOT_PART" ]; then
        log_info "Auto-detected root partition: /dev/$ROOT_PART"
        return 0
    else
        log_error "Could not auto-detect root partition"
        exit 1
    fi
}

# Function to detect boot partition
detect_boot_partition() {
    log_info "Detecting boot partition..."
    
    # Look for boot/EFI partitions
    BOOT_PART=$(lsblk -f | grep -iE "(boot|efi)" | head -1 | awk '{print $1}' | sed 's/[├└─]//g' | xargs)
    
    if [ -n "$BOOT_PART" ]; then
        log_info "Auto-detected boot partition: /dev/$BOOT_PART"
    else
        log_warning "No separate boot partition detected - using root partition"
        BOOT_PART=""
    fi
}

# Function to safely mount filesystems
mount_system() {
    log_info "Mounting filesystems for recovery..."
    
    if [ ! -d "/mnt/recovery" ]; then
        mkdir -p /mnt/recovery
    fi
    
    # Mount root partition
    log_info "Mounting root partition /dev/$ROOT_PART to /mnt/recovery"
    mount /dev/$ROOT_PART /mnt/recovery
    
    # Mount boot partition if it exists
    if [ -n "$BOOT_PART" ]; then
        log_info "Mounting boot partition /dev/$BOOT_PART to /mnt/recovery/boot"
        if [ ! -d "/mnt/recovery/boot" ]; then
            mkdir -p /mnt/recovery/boot
        fi
        mount /dev/$BOOT_PART /mnt/recovery/boot
    fi
    
    # Bind mount virtual filesystems
    log_info "Binding virtual filesystems..."
    mount --bind /dev /mnt/recovery/dev
    mount --bind /proc /mnt/recovery/proc
    mount --bind /sys /mnt/recovery/sys
    mount --bind /run /mnt/recovery/run
    
    log_success "All filesystems mounted successfully"
}

# Function to check filesystem integrity
check_filesystem() {
    log_info "Checking filesystem integrity..."
    
    # Check root filesystem
    log_info "Running fsck on /dev/$ROOT_PART"
    fsck -y /dev/$ROOT_PART || log_warning "Filesystem check completed with warnings"
    
    # Check boot filesystem if separate
    if [ -n "$BOOT_PART" ]; then
        log_info "Running fsck on /dev/$BOOT_PART"
        fsck -y /dev/$BOOT_PART || log_warning "Boot filesystem check completed with warnings"
    fi
    
    log_success "Filesystem checks completed"
}

# Function to perform recovery operations
perform_recovery() {
    log_info "Performing recovery operations in chroot environment..."
    
    # Create the chroot recovery script
    cat > /mnt/recovery/tmp/recovery_chroot.sh << 'CHROOT_EOF'
#!/bin/bash
set -e

echo "🔧 Inside chroot environment..."

# Update package database
echo "Updating package database..."
apt update || echo "Warning: Could not update package database"

# Fix broken packages
echo "Fixing broken packages..."
dpkg --configure -a
apt --fix-broken install -y || echo "Warning: Some package fixes failed"

# Rebuild initramfs
echo "Rebuilding initramfs..."
update-initramfs -u || echo "Warning: initramfs rebuild had issues"

# Update GRUB
echo "Updating GRUB bootloader..."
update-grub || echo "Warning: GRUB update had issues"

# Check for failed services
echo "Checking for failed systemd services..."
systemctl --failed --no-pager || echo "No failed services to display"

# Show recent critical errors
echo "Recent critical errors from journal:"
journalctl -p err --since "24 hours ago" --no-pager | tail -20 || echo "No recent critical errors"

echo "✅ Chroot recovery operations completed"
CHROOT_EOF

    chmod +x /mnt/recovery/tmp/recovery_chroot.sh
    
    # Execute the recovery script in chroot
    log_info "Executing recovery script in chroot..."
    chroot /mnt/recovery /tmp/recovery_chroot.sh
    
    log_success "Recovery operations completed"
}

# Function to show system status
show_system_status() {
    log_info "System Recovery Status Report"
    echo "============================="
    
    echo
    echo "📊 Disk Usage:"
    df -h /mnt/recovery | tail -n +2
    
    echo
    echo "🔍 Recent Boot Errors:"
    chroot /mnt/recovery journalctl -p err -b -1 --no-pager | tail -10 || echo "No recent boot errors found"
    
    echo
    echo "⚠️  Failed Services:"
    chroot /mnt/recovery systemctl --failed --no-pager || echo "No failed services"
    
    echo
    echo "🔧 Package Status:"
    chroot /mnt/recovery dpkg -l | grep -E "^ii|^iU|^rc" | tail -5 || echo "Package check completed"
}

# Function to cleanup and unmount
cleanup_and_unmount() {
    log_info "Cleaning up and unmounting filesystems..."
    
    # Remove the chroot script
    rm -f /mnt/recovery/tmp/recovery_chroot.sh
    
    # Unmount in reverse order
    umount /mnt/recovery/run 2>/dev/null || true
    umount /mnt/recovery/sys 2>/dev/null || true
    umount /mnt/recovery/proc 2>/dev/null || true
    umount /mnt/recovery/dev 2>/dev/null || true
    
    if [ -n "$BOOT_PART" ]; then
        umount /mnt/recovery/boot 2>/dev/null || true
    fi
    
    umount /mnt/recovery 2>/dev/null || true
    
    log_success "Cleanup completed"
}

# Function to install useful recovery tools
install_recovery_tools() {
    log_info "Installing useful recovery tools..."
    
    # List of useful tools for system recovery
    TOOLS="curl wget git htop ncdu tree localsend"
    
    chroot /mnt/recovery bash -c "
        apt update
        apt install -y $TOOLS || echo 'Some tools failed to install'
        
        # Install LocalSend if not available in repos
        if ! command -v localsend >/dev/null 2>&1; then
            echo 'Installing LocalSend manually...'
            cd /tmp
            wget -O localsend.deb https://github.com/localsend/localsend/releases/latest/download/LocalSend-*-linux-x86-64.deb || echo 'LocalSend download failed'
            dpkg -i localsend.deb || apt --fix-broken install -y
        fi
    " || log_warning "Some recovery tools installation failed"
    
    log_success "Recovery tools installation attempted"
}

# Main recovery function
main() {
    log_info "Starting automated Linux recovery process..."
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
    
    # Detect partitions
    detect_root_partition
    detect_boot_partition
    
    # Confirmation
    echo
    log_warning "About to perform recovery on:"
    log_warning "Root partition: /dev/$ROOT_PART"
    [ -n "$BOOT_PART" ] && log_warning "Boot partition: /dev/$BOOT_PART"
    echo
    read -p "Continue with recovery? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Recovery cancelled by user"
        exit 0
    fi
    
    # Set up error handling
    trap cleanup_and_unmount EXIT
    
    # Perform recovery steps
    check_filesystem
    mount_system
    perform_recovery
    install_recovery_tools
    show_system_status
    
    log_success "🎉 Recovery process completed successfully!"
    log_info "You can now reboot and test your system"
    log_info "If issues persist, check the error messages above"
}

# Run main function
main "$@"
