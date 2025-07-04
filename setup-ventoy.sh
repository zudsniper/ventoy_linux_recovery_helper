#!/bin/bash
# Ventoy Recovery Toolkit Setup Script
# Run this manually with sudo privileges
# Created by Claude for Jason

set -e

PROJECT_DIR="/home/jason/ventoy-recovery-toolkit"
USB_DEVICE="/dev/sda"  # Your SanDisk Extreme

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

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

echo "🚀 VENTOY RECOVERY TOOLKIT SETUP 🚀"
echo "===================================="
echo
echo "Project directory: $PROJECT_DIR"
echo "Target USB device: $USB_DEVICE (SanDisk Extreme 58.4GB)"
echo
echo "This will install:"
echo "• Ubuntu 24.04.2 LTS, 24.10, 25.04"
echo "• Debian 12.11 (Bookworm), 13 (Trixie)"
echo "• Auto-recovery scripts"
echo "• LocalSend installer"
echo
echo "⚠️  WARNING: This will COMPLETELY ERASE $USB_DEVICE!"

# Ensure we're in the project directory
cd "$PROJECT_DIR"

# Step 1: Confirmation
read -p "Continue with setup? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Setup cancelled."
    exit 0
fi

# Step 2: Check if ISOs are downloaded
echo
log_info "📋 STEP 1: CHECKING ISO DOWNLOADS"
echo "=================================="

iso_count=$(find isos/ -name "*.iso" -type f 2>/dev/null | wc -l)
log_info "Found $iso_count ISO files"

if [ "$iso_count" -eq 0 ]; then
    log_warning "No ISOs found. Running download script..."
    ./download-isos.sh
else
    log_info "ISOs found. You can add more by running: ./download-isos.sh"
    ls -lh isos/*.iso
fi

# Step 3: Unmount existing partitions
echo
log_info "📋 STEP 2: PREPARING USB DEVICE"
echo "==============================="

log_info "Unmounting any mounted partitions from $USB_DEVICE..."
umount ${USB_DEVICE}* 2>/dev/null || true
log_success "USB device prepared"

# Step 4: Install Ventoy
echo
log_info "📋 STEP 3: INSTALLING VENTOY"
echo "============================"

if [ ! -d "ventoy-1.0.99" ]; then
    log_error "Ventoy directory not found. Please run download script first."
    exit 1
fi

cd ventoy-1.0.99
log_warning "Installing Ventoy to $USB_DEVICE..."
log_warning "This will erase all data on the device!"

read -p "Proceed with Ventoy installation? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Ventoy installation cancelled."
    exit 0
fi

sudo ./Ventoy2Disk.sh -i "$USB_DEVICE"

if [ $? -eq 0 ]; then
    log_success "✅ Ventoy installed successfully!"
else
    log_error "❌ Ventoy installation failed!"
    exit 1
fi

cd ..

# Step 5: Wait and detect Ventoy mount
echo
log_info "📋 STEP 4: DETECTING VENTOY PARTITION"
echo "====================================="

log_info "Waiting for system to detect Ventoy partitions..."
sleep 3

# Try to find where Ventoy mounted
VENTOY_MOUNT=""
for mount_point in "/media/jason/Ventoy" "/media/$USER/Ventoy" "/mnt/Ventoy"; do
    if [ -d "$mount_point" ]; then
        VENTOY_MOUNT="$mount_point"
        break
    fi
done

# If not auto-mounted, mount manually
if [ -z "$VENTOY_MOUNT" ]; then
    log_warning "Ventoy not auto-mounted. Mounting manually..."
    VENTOY_MOUNT="/mnt/ventoy"
    sudo mkdir -p "$VENTOY_MOUNT"
    sudo mount ${USB_DEVICE}1 "$VENTOY_MOUNT"
fi

log_success "Ventoy partition mounted at: $VENTOY_MOUNT"

# Step 6: Copy ISOs
echo
log_info "📋 STEP 5: COPYING ISOs TO VENTOY"
echo "================================"

log_info "Copying ISO files to Ventoy..."
iso_files=$(find isos/ -name "*.iso" -type f 2>/dev/null)

if [ -z "$iso_files" ]; then
    log_warning "No ISO files to copy"
else
    for iso in $iso_files; do
        filename=$(basename "$iso")
        log_info "Copying $filename..."
        sudo cp "$iso" "$VENTOY_MOUNT/"
    done
    log_success "✅ All ISOs copied to Ventoy"
fi

# Step 7: Setup recovery scripts
echo
log_info "📋 STEP 6: INSTALLING RECOVERY SCRIPTS"
echo "======================================"

sudo mkdir -p "$VENTOY_MOUNT/recovery_scripts"
sudo cp auto-recovery.sh "$VENTOY_MOUNT/recovery_scripts/"
sudo cp install-localsend.sh "$VENTOY_MOUNT/recovery_scripts/"

# Create the master recovery menu
sudo tee "$VENTOY_MOUNT/recovery_scripts/master-recovery.sh" > /dev/null << 'EOF'
#!/bin/bash
# Master Recovery Script - Jason's Emergency Toolkit
echo "🔧 JASON'S EMERGENCY RECOVERY TOOLKIT 🔧"
echo "========================================"
echo
echo "Available options:"
echo "1. 🚀 Auto System Recovery (Fix boot/packages/grub)"
echo "2. 📱 Install LocalSend (File sharing)"
echo "3. 🔧 Manual chroot environment"
echo "4. 📊 System information"
echo "5. 💾 Disk information"
echo "6. 🌐 Network tools"
echo "7. 👋 Exit"
echo
read -p "Choose option (1-7): " choice

case $choice in
    1) sudo ./auto-recovery.sh ;;
    2) sudo ./install-localsend.sh ;;
    3) 
        echo "🔧 Manual chroot setup:"
        echo "sudo mkdir -p /mnt/recovery"
        echo "sudo mount /dev/[ROOT_PARTITION] /mnt/recovery"
        echo "sudo mount --bind /dev /mnt/recovery/dev"
        echo "sudo mount --bind /proc /mnt/recovery/proc"
        echo "sudo mount --bind /sys /mnt/recovery/sys"
        echo "sudo chroot /mnt/recovery"
        ;;
    4) lsblk -f; echo; df -h; echo; free -h ;;
    5) sudo fdisk -l; echo; lsblk -o NAME,SIZE,TYPE,MOUNTPOINT ;;
    6) ip addr; echo; ping -c 3 8.8.8.8 ;;
    7) echo "👋 Good luck!"; exit 0 ;;
    *) echo "❌ Invalid option" ;;
esac
EOF

sudo chmod +x "$VENTOY_MOUNT/recovery_scripts/"*.sh
log_success "✅ Recovery scripts installed"

# Step 8: Create README
echo
log_info "📋 STEP 7: CREATING DOCUMENTATION"
echo "================================="

sudo tee "$VENTOY_MOUNT/README-JASON.txt" > /dev/null << EOF
🚀 JASON'S VENTOY RECOVERY TOOLKIT
=================================

This USB contains:

OPERATING SYSTEMS:
• Ubuntu 24.04.2 LTS (Noble Numbat) - 5 year support
• Ubuntu 24.10 (Oracular Oriole) - Current
• Ubuntu 25.04 (Plucky Puffin) - Latest
• Debian 12.11 (Bookworm) - Stable
• Debian 13 (Trixie) - Testing

RECOVERY TOOLS:
• Auto-recovery script (fixes most boot issues)
• LocalSend installer (file sharing)
• Manual recovery guides

HOW TO USE:
1. Boot from this USB
2. Select any Linux ISO from Ventoy menu
3. Once in live environment, open terminal
4. Mount this USB: sudo mount /dev/sda1 /mnt
5. Run: cd /mnt/recovery_scripts
6. Run: sudo ./master-recovery.sh

QUICK RECOVERY:
If system won't boot:
1. Boot Ubuntu 24.04 LTS from this USB
2. sudo mount /dev/sda1 /mnt
3. cd /mnt/recovery_scripts
4. sudo ./auto-recovery.sh

Created: $(date)
Project: /home/jason/ventoy-recovery-toolkit
EOF

log_success "✅ Documentation created"

# Step 9: Final summary
echo
log_success "🎉 VENTOY RECOVERY TOOLKIT SETUP COMPLETE!"
echo "=========================================="
echo
log_info "📊 SETUP SUMMARY:"
echo "• Ventoy installed on $USB_DEVICE"
echo "• Mount point: $VENTOY_MOUNT"
echo "• ISOs installed: $(find "$VENTOY_MOUNT" -name "*.iso" 2>/dev/null | wc -l)"
echo "• Recovery scripts: Ready"
echo "• Total USB usage: $(du -sh "$VENTOY_MOUNT" 2>/dev/null | cut -f1)"
echo
log_info "📖 USAGE:"
echo "• Boot from USB → Select OS → Terminal → cd /mnt/recovery_scripts → sudo ./master-recovery.sh"
echo
log_info "🔄 TO UPDATE:"
echo "• cd $PROJECT_DIR"
echo "• ./download-isos.sh (for new ISOs)"
echo "• ./setup-ventoy.sh (to reinstall)"

# Safely unmount
sync
sudo umount "$VENTOY_MOUNT" 2>/dev/null || true

log_success "🚀 Your recovery toolkit is ready! Keep this USB handy."
