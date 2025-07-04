#!/bin/bash
# LocalSend Installer for Live Environment
# Created by Claude for Jason

set -e

echo "🚀 Installing LocalSend for file sharing..."

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Install LocalSend
install_localsend() {
    log_info "Downloading and installing LocalSend..."
    
    cd /tmp
    
    # Download the latest LocalSend .deb package
    log_info "Downloading LocalSend..."
    wget -O localsend.deb "https://github.com/localsend/localsend/releases/latest/download/LocalSend-1.15.4-linux-x86-64.deb" || {
        log_error "Failed to download LocalSend"
        exit 1
    }
    
    # Install the package
    log_info "Installing LocalSend package..."
    dpkg -i localsend.deb || {
        log_info "Fixing dependencies..."
        apt update
        apt --fix-broken install -y
    }
    
    log_success "LocalSend installed successfully!"
    
    # Create desktop shortcut
    if [ -d "/home/ubuntu/Desktop" ]; then
        log_info "Creating desktop shortcut..."
        cat > /home/ubuntu/Desktop/LocalSend.desktop << 'EOF'
[Desktop Entry]
Name=LocalSend
Comment=Share files to nearby devices
Exec=localsend_app
Icon=localsend
Type=Application
Categories=Network;FileTransfer;
EOF
        chmod +x /home/ubuntu/Desktop/LocalSend.desktop
        chown ubuntu:ubuntu /home/ubuntu/Desktop/LocalSend.desktop
    fi
    
    log_success "LocalSend is ready to use!"
    log_info "You can start it from the applications menu or run 'localsend_app' in terminal"
}

# Main function
main() {
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
    
    install_localsend
}

main "$@"
