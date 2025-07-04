# 🛠️ Ventoy Linux Recovery Helper

A comprehensive, automated toolkit for creating multi-boot USB recovery drives using Ventoy. Perfect for system administrators, Linux enthusiasts, and anyone who needs reliable system recovery tools.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Platform](https://img.shields.io/badge/platform-Linux-green.svg)
![Ventoy](https://img.shields.io/badge/Ventoy-1.0.99-orange.svg)

## 🚀 Features

- **🔄 Resumable Downloads** - Never re-download ISOs
- **🎯 Smart Recovery** - Automated system repair with one command
- **📱 File Sharing** - LocalSend integration for wireless transfers
- **🖥️ Multi-OS Support** - Ubuntu LTS/Current + Debian Stable/Testing
- **⚡ One-Click Setup** - Fully automated Ventoy installation
- **🔧 Comprehensive Tools** - Filesystem repair, GRUB fix, package management

## 📦 What's Included

### Operating Systems
- **Ubuntu 24.04.2 LTS** (Noble Numbat) - 5 year support until 2029
- **Ubuntu 24.10** (Oracular Oriole) - Current release  
- **Ubuntu 25.04** (Plucky Puffin) - Latest release
- **Debian 12.11** (Bookworm) - Current stable
- **Debian 13** (Trixie) - Testing/next release

### Recovery Tools
- `auto-recovery.sh` - Automated system repair (filesystem, GRUB, packages)
- `install-localsend.sh` - Cross-platform file sharing
- `master-recovery.sh` - Interactive recovery menu
- Smart partition detection and mounting

## 🔧 Quick Start

### 1. Clone and Setup
```bash
git clone https://github.com/zudsniper/ventoy_linux_recovery_helper.git
cd ventoy_linux_recovery_helper

# Download ISOs (resumable)
./download-isos.sh

# Install to USB drive (will detect your drive)
sudo ./setup-ventoy.sh
```

### 2. Using for Recovery
1. Boot from your Ventoy USB
2. Select any Linux ISO from the menu
3. In the live environment:
```bash
sudo mount /dev/sda1 /mnt
cd /mnt/recovery_scripts
sudo ./master-recovery.sh
```

## 💾 System Requirements

- **USB Drive**: 32GB+ (64GB recommended)
- **Target Systems**: x86_64 (AMD64) architecture
- **Network**: Required for downloads and some recovery operations
- **Host OS**: Linux with bash, wget, curl

## 📊 Storage Usage

| Component | Size | Purpose |
|-----------|------|---------|
| Ubuntu 24.04.2 LTS | ~6.0GB | Primary recovery OS |
| Ubuntu 24.10 | ~5.3GB | Current release |
| Ubuntu 25.04 | ~5.9GB | Latest features |
| Debian 12.11 | ~3.3GB | Stable alternative |
| Debian 13 (testing) | ~810MB | Next-gen tools |
| Recovery scripts | ~1MB | Automation tools |
| **Total** | **~21.3GB** | Fits on 32GB+ USB |

## 🛠️ Advanced Usage

### Resume Interrupted Downloads
```bash
./download-isos.sh        # Automatically resumes from where it stopped
# OR
./resume-downloads.sh     # Quick alias
```

### Manual System Recovery
```bash
# Mount broken system
sudo mkdir -p /mnt/recovery
sudo mount /dev/[root-partition] /mnt/recovery
sudo mount --bind /dev /mnt/recovery/dev
sudo mount --bind /proc /mnt/recovery/proc
sudo mount --bind /sys /mnt/recovery/sys

# Enter system
sudo chroot /mnt/recovery

# Fix issues
update-grub
update-initramfs -u
apt --fix-broken install
```

### Emergency One-Liner
```bash
sudo mount /dev/sda1 /mnt && cd /mnt/recovery_scripts && sudo ./auto-recovery.sh
```

## 🆘 Common Recovery Scenarios

| Problem | Solution |
|---------|----------|
| Won't boot / GRUB error | Auto-recovery fixes GRUB automatically |
| Package conflicts | `dpkg --configure -a` + `apt --fix-broken install` |
| Kernel panic | Rebuild initramfs and update GRUB |
| File system corruption | Automated `fsck` repair |
| Need files from broken system | Mount + LocalSend for wireless transfer |

## 🔄 Updating Your Toolkit

```bash
cd ventoy_linux_recovery_helper
git pull                    # Get latest scripts
./download-isos.sh         # Download new ISOs
sudo ./setup-ventoy.sh     # Reinstall to USB
```

## 📁 Project Structure

```
ventoy_linux_recovery_helper/
├── download-isos.sh          # Resumable ISO downloader
├── setup-ventoy.sh           # Complete Ventoy installation
├── auto-recovery.sh          # Automated system repair
├── install-localsend.sh      # File sharing setup
├── resume-downloads.sh       # Quick resume alias
├── README.md                 # This file
├── LICENSE                   # MIT License
└── .gitignore               # Git ignore rules
```

## 🤝 Contributing

Contributions welcome! Please read our contributing guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Areas for Contribution
- Additional Linux distributions
- More recovery automation
- Hardware-specific fixes
- Documentation improvements
- Testing on different systems

## 📋 Roadmap

- [ ] Add more Linux distributions (Fedora, openSUSE, etc.)
- [ ] Windows PE recovery tools integration
- [ ] Automated hardware diagnostics
- [ ] Cloud backup integration
- [ ] Web-based recovery interface
- [ ] Support for ARM64 systems

## ⚠️ Disclaimer

This toolkit will **completely erase** your target USB drive. Always backup important data before running the setup script. Use at your own risk - while extensively tested, system recovery operations can potentially cause data loss if used incorrectly.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Ventoy Team](https://www.ventoy.net/) for the amazing multi-boot solution
- [Ubuntu](https://ubuntu.com/) and [Debian](https://www.debian.org/) communities
- [LocalSend](https://localsend.org/) for cross-platform file sharing
- All contributors and testers

## 📞 Support

- 🐛 [Report Bugs](https://github.com/zudsniper/ventoy_linux_recovery_helper/issues)
- 💡 [Request Features](https://github.com/zudsniper/ventoy_linux_recovery_helper/issues)
- 📖 [Documentation](https://github.com/zudsniper/ventoy_linux_recovery_helper/wiki)
- 💬 [Discussions](https://github.com/zudsniper/ventoy_linux_recovery_helper/discussions)

---

**Made with ❤️ for the Linux community**

*Star ⭐ this repo if it helped you recover a system!*
