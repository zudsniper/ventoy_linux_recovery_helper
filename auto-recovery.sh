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

# Function to check if partition might be encrypted
is_encrypted_partition() {
    local part=$1
    # Check if it's a crypto/LUKS partition
    if lsblk -f | grep "$part" | grep -q "crypto"; then
        return 0
    fi
    # Also check with cryptsetup
    if command -v cryptsetup >/dev/null 2>&1; then
        if cryptsetup isLuks "/dev/$part" 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# Function to unlock encrypted partition
unlock_encrypted_partition() {
    local part=$1
    log_info "Partition /dev/$part appears to be encrypted (LUKS)"
    
    if ! command -v cryptsetup >/dev/null 2>&1; then
        log_error "cryptsetup not found - cannot unlock encrypted partitions"
        log_info "Install cryptsetup with: apt install cryptsetup"
        return 1
    fi
    
    # Check if already unlocked
    local mapper_name="recovery_${part}"
    if [ -b "/dev/mapper/$mapper_name" ]; then
        log_info "Encrypted partition already unlocked at /dev/mapper/$mapper_name"
        ROOT_PART="mapper/$mapper_name"
        return 0
    fi
    
    log_info "Please enter the passphrase to unlock the encrypted partition:"
    if cryptsetup luksOpen "/dev/$part" "$mapper_name"; then
        log_success "Encrypted partition unlocked successfully"
        ROOT_PART="mapper/$mapper_name"
        return 0
    else
        log_error "Failed to unlock encrypted partition"
        return 1
    fi
}

# Function to detect root partition automatically
detect_root_partition() {
    log_info "Detecting root partition..."
    
    # First check for encrypted partitions
    CRYPTO_PARTS=$(lsblk -f | grep "crypto" | awk '{print $1}' | sed 's/[├└─]//g' | xargs)
    
    if [ -n "$CRYPTO_PARTS" ]; then
        log_warning "Found encrypted partition(s): $CRYPTO_PARTS"
        echo
        echo "Your system appears to use disk encryption."
        read -p "Is your root partition encrypted? (y/N): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # If only one encrypted partition, use it
            CRYPTO_COUNT=$(echo "$CRYPTO_PARTS" | wc -w)
            if [ "$CRYPTO_COUNT" -eq 1 ]; then
                if unlock_encrypted_partition "$CRYPTO_PARTS"; then
                    return 0
                fi
            else
                # Multiple encrypted partitions, let user choose
                log_info "Multiple encrypted partitions found. Please select:"
                echo "$CRYPTO_PARTS" | tr ' ' '\n' | nl -nln
                read -p "Enter the number of your root partition: " choice
                SELECTED_PART=$(echo "$CRYPTO_PARTS" | tr ' ' '\n' | sed -n "${choice}p")
                if [ -n "$SELECTED_PART" ]; then
                    if unlock_encrypted_partition "$SELECTED_PART"; then
                        return 0
                    fi
                fi
            fi
        fi
    fi
    
    # Look for ext4/btrfs/xfs partitions that could be root, excluding loop devices
    # Also exclude small partitions (less than 5GB) which are likely /boot
    ROOT_CANDIDATES=$(lsblk -f -b | grep -E "(ext4|btrfs|xfs)" | grep -v -E "(loop)" | while read line; do
        part=$(echo "$line" | awk '{print $1}' | sed 's/[├└─]//g')
        # Get partition size in bytes
        size=$(lsblk -b -n -o SIZE "/dev/$part" 2>/dev/null || echo 0)
        # Only consider partitions larger than 5GB (5368709120 bytes)
        if [ "$size" -gt 5368709120 ]; then
            echo "$line"
        fi
    done)
    
    if [ -z "$ROOT_CANDIDATES" ]; then
        log_error "No suitable root partitions found!"
        log_info "Available partitions:"
        lsblk -f
        exit 1
    fi
    
    echo "Found potential root partitions:"
    echo "$ROOT_CANDIDATES"
    echo
    
    # Try to auto-detect the most likely root partition
    ROOT_PART=$(echo "$ROOT_CANDIDATES" | head -1 | awk '{print $1}' | sed 's/[├└─]//g' | xargs)
    
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
    
    # Look for EFI partitions (FAT32/vfat)
    EFI_PART=$(lsblk -f | grep -E "(vfat|FAT)" | grep -v "loop" | head -1 | awk '{print $1}' | sed 's/[├└─]//g' | xargs)
    
    # Look for ext4 boot partitions (small ext4 partitions)
    BOOT_PART=$(lsblk -f -b | grep -E "ext4" | grep -v "loop" | while read line; do
        part=$(echo "$line" | awk '{print $1}' | sed 's/[├└─]//g')
        # Get partition size in bytes
        size=$(lsblk -b -n -o SIZE "/dev/$part" 2>/dev/null || echo 0)
        # Boot partitions are typically less than 2GB
        if [ "$size" -lt 2147483648 ] && [ "$size" -gt 0 ]; then
            echo "$part"
            break
        fi
    done)
    
    # Prefer EFI partition if found
    if [ -n "$EFI_PART" ]; then
        log_info "Auto-detected EFI partition: /dev/$EFI_PART"
        EFI_PART_DETECTED="$EFI_PART"
    fi
    
    if [ -n "$BOOT_PART" ] && [ "$BOOT_PART" != "$ROOT_PART" ]; then
        log_info "Auto-detected boot partition: /dev/$BOOT_PART"
        BOOT_PART_DETECTED="$BOOT_PART"
    fi
    
    # Use boot partition if found, otherwise no separate /boot
    if [ -n "$BOOT_PART_DETECTED" ]; then
        BOOT_PART="$BOOT_PART_DETECTED"
    else
        log_warning "No separate boot partition detected - system may use root partition for /boot"
        BOOT_PART=""
    fi
}

# Function to safely mount filesystems
mount_system() {
    log_info "Mounting filesystems for recovery..."
    
    # Create mount point if it doesn't exist
    if [ ! -d "/mnt/recovery" ]; then
        mkdir -p /mnt/recovery
    fi
    
    # Mount root partition
    log_info "Mounting root partition /dev/$ROOT_PART to /mnt/recovery"
    if ! mount /dev/$ROOT_PART /mnt/recovery; then
        log_error "Failed to mount root partition!"
        exit 1
    fi
    
    # Verify mount succeeded
    if ! mountpoint -q /mnt/recovery; then
        log_error "Root partition mount verification failed!"
        exit 1
    fi
    
    # Create necessary directories for bind mounts
    log_info "Creating necessary directories..."
    for dir in dev proc sys run boot boot/efi; do
        if [ ! -d "/mnt/recovery/$dir" ]; then
            mkdir -p "/mnt/recovery/$dir"
        fi
    done
    
    # Mount boot partition if it exists and is valid
    if [ -n "$BOOT_PART" ] && [ -b "/dev/$BOOT_PART" ]; then
        log_info "Mounting boot partition /dev/$BOOT_PART to /mnt/recovery/boot"
        if ! mount /dev/$BOOT_PART /mnt/recovery/boot; then
            log_warning "Failed to mount boot partition - continuing without it"
            BOOT_PART=""
        fi
    fi
    
    # Mount EFI partition if it exists
    if [ -n "$EFI_PART_DETECTED" ] && [ -b "/dev/$EFI_PART_DETECTED" ]; then
        # Determine mount point - could be /boot/efi or /efi
        if [ -d "/mnt/recovery/boot/efi" ]; then
            EFI_MOUNT="/mnt/recovery/boot/efi"
        elif [ -d "/mnt/recovery/efi" ]; then
            mkdir -p "/mnt/recovery/efi"
            EFI_MOUNT="/mnt/recovery/efi"
        else
            EFI_MOUNT="/mnt/recovery/boot/efi"
        fi
        
        log_info "Mounting EFI partition /dev/$EFI_PART_DETECTED to $EFI_MOUNT"
        if ! mount /dev/$EFI_PART_DETECTED "$EFI_MOUNT"; then
            log_warning "Failed to mount EFI partition - UEFI updates may not work"
        fi
    fi
    
    # Bind mount virtual filesystems
    log_info "Binding virtual filesystems..."
    for fs in dev proc sys run; do
        log_info "Mounting /$fs to /mnt/recovery/$fs"
        if ! mount --bind /$fs /mnt/recovery/$fs; then
            log_warning "Failed to bind mount /$fs - some recovery operations may be limited"
        fi
    done
    
    log_success "Filesystems mounted successfully"
}

# Function to check filesystem integrity
check_filesystem() {
    log_info "Checking filesystem integrity..."
    
    # Unmount if already mounted to run fsck
    umount /dev/$ROOT_PART 2>/dev/null || true
    
    # Check root filesystem
    log_info "Running fsck on /dev/$ROOT_PART"
    fsck -y /dev/$ROOT_PART || log_warning "Filesystem check completed with warnings"
    
    # Check boot filesystem if separate and valid
    if [ -n "$BOOT_PART" ] && [ -b "/dev/$BOOT_PART" ] && [[ "$BOOT_PART" != loop* ]]; then
        umount /dev/$BOOT_PART 2>/dev/null || true
        log_info "Running fsck on /dev/$BOOT_PART"
        fsck -y /dev/$BOOT_PART || log_warning "Boot filesystem check completed with warnings"
    fi
    
    log_success "Filesystem checks completed"
}

# Function to perform recovery operations
perform_recovery() {
    log_info "Performing recovery operations in chroot environment..."
    
    # Check if we can access the chroot environment
    if [ ! -f "/mnt/recovery/bin/bash" ]; then
        log_error "Cannot find bash in mounted system - is this a valid Linux installation?"
        return 1
    fi
    
    # Create the chroot recovery script
    cat > /mnt/recovery/tmp/recovery_chroot.sh << 'CHROOT_EOF'
#!/bin/bash
set +e  # Don't exit on error, we want to try all recovery steps

echo "🔧 Inside chroot environment..."

# Check if we're in a Debian/Ubuntu system
if [ ! -f /etc/debian_version ]; then
    echo "Warning: This doesn't appear to be a Debian/Ubuntu system"
    echo "Recovery operations may not work as expected"
fi

# Update package database
echo "Updating package database..."
if command -v apt >/dev/null 2>&1; then
    apt update 2>&1 || echo "Warning: Could not update package database"
else
    echo "Warning: apt not found - skipping package operations"
fi

# Fix broken packages
echo "Fixing broken packages..."
if command -v dpkg >/dev/null 2>&1; then
    dpkg --configure -a 2>&1 || echo "Warning: dpkg configure failed"
    apt --fix-broken install -y 2>&1 || echo "Warning: Some package fixes failed"
else
    echo "Warning: dpkg not found - skipping package fixes"
fi

# Rebuild initramfs
echo "Rebuilding initramfs..."
if command -v update-initramfs >/dev/null 2>&1; then
    update-initramfs -u -k all 2>&1 || echo "Warning: initramfs rebuild had issues"
else
    echo "Warning: update-initramfs not found - skipping"
fi

# Update GRUB
echo "Updating GRUB bootloader..."
if command -v update-grub >/dev/null 2>&1; then
    update-grub 2>&1 || echo "Warning: GRUB update had issues"
elif command -v grub-mkconfig >/dev/null 2>&1; then
    grub-mkconfig -o /boot/grub/grub.cfg 2>&1 || echo "Warning: GRUB config generation had issues"
else
    echo "Warning: GRUB tools not found - skipping bootloader update"
fi

# Check for failed services
echo "Checking for failed systemd services..."
if command -v systemctl >/dev/null 2>&1; then
    systemctl --failed --no-pager 2>&1 || echo "No systemd found or no failed services"
fi

# Show recent critical errors
echo "Recent critical errors from journal:"
if command -v journalctl >/dev/null 2>&1; then
    journalctl -p err --since "24 hours ago" --no-pager 2>&1 | tail -20 || echo "No journal available"
fi

echo "✅ Chroot recovery operations completed"
CHROOT_EOF

    chmod +x /mnt/recovery/tmp/recovery_chroot.sh
    
    # Execute the recovery script in chroot
    log_info "Executing recovery script in chroot..."
    if ! chroot /mnt/recovery /tmp/recovery_chroot.sh; then
        log_warning "Some recovery operations failed - check messages above"
    fi
    
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
    
    # Remove the chroot script if it exists
    rm -f /mnt/recovery/tmp/recovery_chroot.sh 2>/dev/null || true
    
    # Kill any processes using the mount points
    fuser -km /mnt/recovery 2>/dev/null || true
    sleep 1
    
    # Unmount in reverse order
    for fs in run sys proc dev; do
        if mountpoint -q "/mnt/recovery/$fs" 2>/dev/null; then
            umount "/mnt/recovery/$fs" 2>/dev/null || log_warning "Could not unmount /mnt/recovery/$fs"
        fi
    done
    
    # Unmount EFI if mounted
    if [ -n "$EFI_MOUNT" ] && mountpoint -q "$EFI_MOUNT" 2>/dev/null; then
        umount "$EFI_MOUNT" 2>/dev/null || log_warning "Could not unmount EFI partition"
    fi
    
    if [ -n "$BOOT_PART" ] && mountpoint -q /mnt/recovery/boot 2>/dev/null; then
        umount /mnt/recovery/boot 2>/dev/null || log_warning "Could not unmount boot partition"
    fi
    
    if mountpoint -q /mnt/recovery 2>/dev/null; then
        umount /mnt/recovery 2>/dev/null || log_warning "Could not unmount root partition"
    fi
    
    # Close encrypted volume if we opened one
    if [[ "$ROOT_PART" == mapper/* ]]; then
        local mapper_name=$(basename "$ROOT_PART")
        if [ -b "/dev/mapper/$mapper_name" ]; then
            log_info "Closing encrypted volume $mapper_name"
            cryptsetup luksClose "$mapper_name" 2>/dev/null || log_warning "Could not close encrypted volume"
        fi
    fi
    
    log_success "Cleanup completed"
}

# Function to install useful recovery tools
install_recovery_tools() {
    log_info "Installing useful recovery tools..."
    
    # Check if we can run apt in chroot
    if [ ! -f "/mnt/recovery/usr/bin/apt" ]; then
        log_warning "apt not found in mounted system - skipping tool installation"
        return 0
    fi
    
    # List of useful tools for system recovery
    TOOLS="curl wget git htop ncdu tree"
    
    chroot /mnt/recovery bash -c "
        set +e  # Don't exit on error
        
        # Check internet connectivity
        if ! ping -c 1 google.com >/dev/null 2>&1; then
            echo 'Warning: No internet connection - skipping tool installation'
            exit 0
        fi
        
        apt update 2>&1 || echo 'Warning: apt update failed'
        
        for tool in $TOOLS; do
            if ! command -v \$tool >/dev/null 2>&1; then
                echo \"Installing \$tool...\"
                apt install -y \$tool 2>&1 || echo \"Failed to install \$tool\"
            else
                echo \"\$tool is already installed\"
            fi
        done
    " || log_warning "Tool installation had errors"
    
    log_success "Recovery tools installation attempted"
}

# Function to manually select partitions
manual_partition_selection() {
    log_info "Manual partition selection mode"
    echo
    echo "Available partitions:"
    lsblk -f
    echo
    
    # Get root partition
    while true; do
        read -p "Enter root partition (e.g., nvme0n1p3 or sda2): " ROOT_PART
        ROOT_PART=$(echo "$ROOT_PART" | sed 's|/dev/||')  # Remove /dev/ if provided
        
        if [ -b "/dev/$ROOT_PART" ]; then
            log_success "Selected root partition: /dev/$ROOT_PART"
            break
        else
            log_error "Invalid partition: /dev/$ROOT_PART"
        fi
    done
    
    # Get boot partition (optional)
    read -p "Enter boot partition (press Enter to skip): " BOOT_PART
    if [ -n "$BOOT_PART" ]; then
        BOOT_PART=$(echo "$BOOT_PART" | sed 's|/dev/||')  # Remove /dev/ if provided
        if [ -b "/dev/$BOOT_PART" ]; then
            log_success "Selected boot partition: /dev/$BOOT_PART"
        else
            log_warning "Invalid boot partition - proceeding without it"
            BOOT_PART=""
        fi
    fi
}

# Main recovery function
main() {
    log_info "Starting automated Linux recovery process..."
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
    
    # Ask for auto-detect or manual selection
    echo
    echo "Partition Detection Options:"
    echo "1) Auto-detect partitions (recommended)"
    echo "2) Manual partition selection"
    echo
    read -p "Select option (1 or 2): " -n 1 -r
    echo
    echo
    
    if [[ $REPLY == "2" ]]; then
        manual_partition_selection
    else
        # Detect partitions
        detect_root_partition
        detect_boot_partition
    fi
    
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
