#!/bin/bash
# Resumable ISO Download Script for Ventoy Setup
# Created by Claude for Jason
# Project: ventoy-recovery-toolkit

set -e

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

# Project directory
PROJECT_DIR="/home/jason/ventoy-recovery-toolkit"
DOWNLOAD_DIR="$PROJECT_DIR/isos"
CHECKSUMS_FILE="$DOWNLOAD_DIR/.checksums"

# Ensure we're in the right directory
cd "$PROJECT_DIR"
mkdir -p "$DOWNLOAD_DIR"

log_info "🚀 Resumable ISO downloader for Ventoy Recovery Toolkit"
log_info "Project directory: $PROJECT_DIR"
log_info "Download directory: $DOWNLOAD_DIR"

# Function to get file size
get_file_size() {
    local file="$1"
    if [ -f "$file" ]; then
        stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Function to get remote file size
get_remote_size() {
    local url="$1"
    local size=$(curl -sI "$url" | grep -i content-length | awk '{print $2}' | tr -d '\r\n' | head -1)
    # Ensure we return a valid integer
    if [[ "$size" =~ ^[0-9]+$ ]]; then
        echo "$size"
    else
        echo "0"
    fi
}

# Function to check if download is complete
is_download_complete() {
    local file="$1"
    local expected_size="$2"
    local actual_size
    
    if [ ! -f "$file" ]; then
        return 1
    fi
    
    actual_size=$(get_file_size "$file")
    
    # Ensure both values are valid integers
    if [[ "$actual_size" =~ ^[0-9]+$ ]] && [[ "$expected_size" =~ ^[0-9]+$ ]] && [ "$expected_size" -gt 0 ]; then
        if [ "$actual_size" -eq "$expected_size" ]; then
            return 0
        fi
    fi
    
    return 1
}

# Function to download with resume support
download_iso() {
    local url="$1"
    local filename="$2"
    local description="$3"
    local min_expected_size="$4"  # Minimum expected size in bytes
    
    local filepath="$DOWNLOAD_DIR/$filename"
    
    log_info "📥 Processing $description..."
    log_info "URL: $url"
    log_info "File: $filename"
    
    # Check if file exists and get its size
    local current_size=$(get_file_size "$filepath")
    local remote_size=$(get_remote_size "$url")
    
    # If we have a minimum expected size, use it if remote size detection fails
    if [[ ! "$remote_size" =~ ^[0-9]+$ ]] || [ "$remote_size" -eq 0 ]; then
        if [ -n "$min_expected_size" ] && [[ "$min_expected_size" =~ ^[0-9]+$ ]]; then
            remote_size="$min_expected_size"
        else
            remote_size="0"
        fi
    fi
    
    log_info "Current file size: $(numfmt --to=iec $current_size 2>/dev/null || echo "0")"
    if [[ "$remote_size" =~ ^[0-9]+$ ]] && [ "$remote_size" -gt 0 ]; then
        log_info "Expected size: $(numfmt --to=iec $remote_size 2>/dev/null || echo "Unknown")"
    fi
    
    # Check if download is already complete
    if is_download_complete "$filepath" "$remote_size"; then
        log_success "✅ $filename already downloaded and complete"
        echo "$filename:$remote_size:$(date +%s)" >> "$CHECKSUMS_FILE"
        return 0
    fi
    
    # Check if partial file exists and we can resume
    if [[ "$current_size" =~ ^[0-9]+$ ]] && [[ "$remote_size" =~ ^[0-9]+$ ]] && \
       [ "$current_size" -gt 0 ] && [ "$current_size" -lt "$remote_size" ]; then
        log_info "🔄 Resuming download from $(numfmt --to=iec $current_size 2>/dev/null || echo "$current_size bytes")"
        # Use wget with resume support
        wget -c -O "$filepath" --progress=bar:force "$url" || {
            log_error "Failed to resume download of $filename"
            log_warning "Removing partial file and trying fresh download..."
            rm -f "$filepath"
            wget -O "$filepath" --progress=bar:force "$url" || {
                log_error "Fresh download failed for $filename"
                return 1
            }
        }
    else
        log_info "🆕 Starting fresh download..."
        # Remove any partial/corrupted file
        rm -f "$filepath"
        wget -O "$filepath" --progress=bar:force "$url" || {
            log_error "Failed to download $filename"
            return 1
        }
    fi
    
    # Verify final size
    local final_size=$(get_file_size "$filepath")
    log_success "Downloaded $filename ($(numfmt --to=iec $final_size))"
    
    # Save download info
    echo "$filename:$final_size:$(date +%s)" >> "$CHECKSUMS_FILE"
    
    return 0
}

# Function to show download status
show_status() {
    log_info "=== DOWNLOAD STATUS ==="
    
    if [ -f "$CHECKSUMS_FILE" ]; then
        while IFS=':' read -r filename size timestamp; do
            if [ -f "$DOWNLOAD_DIR/$filename" ]; then
                local human_size=$(numfmt --to=iec "$size")
                local date_str=$(date -d "@$timestamp" 2>/dev/null || date -r "$timestamp" 2>/dev/null || echo "Unknown")
                log_success "✅ $filename ($human_size) - $date_str"
            fi
        done < "$CHECKSUMS_FILE"
    fi
    
    echo
    echo "📂 Current downloads:"
    ls -lh "$DOWNLOAD_DIR"/*.iso 2>/dev/null || log_warning "No ISO files found yet"
    
    local total_size=$(du -sh "$DOWNLOAD_DIR" 2>/dev/null | cut -f1 || echo "0")
    echo
    log_info "Total size: $total_size"
}

# Clear old checksums file for this session
rm -f "$CHECKSUMS_FILE"

log_info "=== UBUNTU DOWNLOADS ==="

# Ubuntu 24.04.2 LTS (Noble Numbat) - ~5.7GB
download_iso "https://releases.ubuntu.com/24.04.2/ubuntu-24.04.2-desktop-amd64.iso" \
    "ubuntu-24.04.2-desktop-amd64.iso" \
    "Ubuntu 24.04.2 LTS (Noble Numbat)" \
    "5900000000"

# Ubuntu 24.10 (Oracular Oriole) - ~5.6GB
download_iso "https://releases.ubuntu.com/24.10/ubuntu-24.10-desktop-amd64.iso" \
    "ubuntu-24.10-desktop-amd64.iso" \
    "Ubuntu 24.10 (Oracular Oriole)" \
    "5600000000"

# Ubuntu 25.04 (Plucky Puffin) - ~5.8GB
download_iso "https://releases.ubuntu.com/25.04/ubuntu-25.04-desktop-amd64.iso" \
    "ubuntu-25.04-desktop-amd64.iso" \
    "Ubuntu 25.04 (Plucky Puffin)" \
    "5800000000"

log_info "=== DEBIAN DOWNLOADS ==="

# Debian 12.11 (Bookworm) Live with GNOME - ~3.2GB
download_iso "https://cdimage.debian.org/debian-cd/current-live/amd64/iso-hybrid/debian-live-12.11.0-amd64-gnome.iso" \
    "debian-live-12.11.0-amd64-gnome.iso" \
    "Debian 12.11 (Bookworm) Live with GNOME" \
    "3200000000"

# Debian 13 (Trixie) Testing - Network Installer - ~810MB
download_iso "https://cdimage.debian.org/cdimage/weekly-builds/amd64/iso-cd/debian-testing-amd64-netinst.iso" \
    "debian-testing-amd64-netinst.iso" \
    "Debian 13 (Trixie) Testing - Network Installer" \
    "850000000"

log_info "=== DOWNLOAD SUMMARY ==="
show_status

log_success "🎉 ISO downloads completed!"
log_info "=== NEXT STEPS ==="
log_info "1. Run: cd $PROJECT_DIR"
log_info "2. Install Ventoy: sudo ./setup-ventoy.sh"
log_info "3. Or copy ISOs manually to your Ventoy USB"

# Create a simple resume script
cat > "$PROJECT_DIR/resume-downloads.sh" << 'EOF'
#!/bin/bash
# Quick resume script
cd "$(dirname "$0")"
./download-isos.sh
EOF
chmod +x "$PROJECT_DIR/resume-downloads.sh"

log_success "📝 Created resume-downloads.sh for easy resuming"
