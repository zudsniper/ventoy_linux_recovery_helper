# Contributing to Ventoy Linux Recovery Helper

Thank you for considering contributing to this project! 🎉

## 🚀 Quick Start

1. Fork the repository
2. Clone your fork: `git clone https://github.com/yourusername/ventoy_linux_recovery_helper.git`
3. Create a branch: `git checkout -b feature/your-feature-name`
4. Make your changes
5. Test thoroughly
6. Commit: `git commit -m "Add your feature"`
7. Push: `git push origin feature/your-feature-name`
8. Open a Pull Request

## 🎯 Areas We Need Help With

### High Priority
- **Testing on different hardware** - Intel, AMD, various USB controllers
- **Additional Linux distributions** - Fedora, openSUSE, Arch, etc.
- **Recovery edge cases** - encrypted systems, LVM, RAID configurations
- **Documentation improvements** - More examples, troubleshooting guides

### Medium Priority
- **Automated hardware diagnostics** - Memory tests, disk health checks
- **Cloud integration** - Backup/restore from cloud services
- **Performance optimizations** - Faster downloads, better error handling
- **Internationalization** - Support for multiple languages

### Future Ideas
- **Windows PE integration** - Windows recovery tools
- **ARM64 support** - Raspberry Pi and other ARM systems
- **Web interface** - Browser-based recovery management
- **Custom ISO building** - User-specific recovery environments

## 🧪 Testing Guidelines

### Before Submitting
- [ ] Test on at least 2 different systems
- [ ] Verify resumable downloads work correctly
- [ ] Test recovery scripts on broken VM
- [ ] Check all scripts have proper error handling
- [ ] Ensure new features don't break existing functionality

### Test Environments
We especially need testing on:
- Different USB drive brands/sizes
- Various Linux distributions
- UEFI vs Legacy BIOS systems
- Different filesystem types (ext4, btrfs, xfs)
- Encrypted systems

## 📝 Code Style

### Shell Scripts
- Use `#!/bin/bash` shebang
- Enable strict mode: `set -e`
- Use descriptive variable names
- Add comments for complex logic
- Include error handling for all operations
- Use consistent indentation (4 spaces)

### Example:
```bash
#!/bin/bash
set -e

# Function to safely mount partition
mount_partition() {
    local device="$1"
    local mount_point="$2"
    
    if [ ! -b "$device" ]; then
        log_error "Device $device not found"
        return 1
    fi
    
    mkdir -p "$mount_point"
    mount "$device" "$mount_point" || {
        log_error "Failed to mount $device"
        return 1
    }
    
    log_success "Mounted $device at $mount_point"
}
```

### Documentation
- Update README.md for user-facing changes
- Add inline comments for complex functions
- Include usage examples
- Document any new dependencies

## 🐛 Bug Reports

When reporting bugs, please include:

- **OS and version** (Ubuntu 24.04, Debian 12, etc.)
- **Hardware details** (USB drive model, system specs)
- **Error messages** (full output with `--verbose` if available)
- **Steps to reproduce** (as detailed as possible)
- **Expected vs actual behavior**

Use this template:

```markdown
**Environment:**
- Host OS: Ubuntu 24.04
- USB Drive: SanDisk Extreme 64GB
- Target System: Dell Laptop with UEFI

**Bug Description:**
Brief description of the issue

**Steps to Reproduce:**
1. Run `./download-isos.sh`
2. Execute `sudo ./setup-ventoy.sh`
3. Boot from USB and...

**Expected Behavior:**
What should happen

**Actual Behavior:**
What actually happens

**Error Output:**
```
Paste any error messages here
```

**Additional Context:**
Any other relevant information
```

## 🎨 Feature Requests

For new features, please:

1. **Check existing issues** to avoid duplicates
2. **Describe the use case** - why is this needed?
3. **Propose a solution** - how should it work?
4. **Consider alternatives** - are there other approaches?
5. **Think about impact** - will this affect existing users?

## 📚 Development Setup

### Prerequisites
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install git wget curl bash coreutils util-linux

# Test environment (optional)
sudo apt install qemu-kvm virt-manager
```

### Running Tests
```bash
# Download test ISOs (small ones)
./download-isos.sh

# Test in a VM first
# Create a broken VM to test recovery scripts

# Test resumable downloads
pkill wget  # Interrupt download
./download-isos.sh  # Should resume
```

## 🔄 Release Process

### Version Numbering
We use semantic versioning: `MAJOR.MINOR.PATCH`
- **MAJOR**: Breaking changes
- **MINOR**: New features, backward compatible
- **PATCH**: Bug fixes

### Release Checklist
- [ ] Update version numbers
- [ ] Test on multiple systems
- [ ] Update CHANGELOG.md
- [ ] Tag release: `git tag v1.0.0`
- [ ] Push tags: `git push --tags`
- [ ] Create GitHub release with notes

## 🤝 Community

### Communication
- **GitHub Issues**: Bug reports, feature requests
- **GitHub Discussions**: General questions, ideas
- **Pull Requests**: Code contributions

### Code of Conduct
- Be respectful and inclusive
- Help newcomers learn
- Focus on constructive feedback
- Give credit where due
- Keep discussions on-topic

## 💡 Tips for Contributors

### Good First Issues
Look for issues labeled:
- `good first issue`
- `help wanted`
- `documentation`
- `testing`

### Making Impact
- **Start small** - Fix typos, improve error messages
- **Test extensively** - Quality over quantity
- **Document everything** - Future you will thank you
- **Ask questions** - Better to clarify than assume

### Technical Tips
- **Use existing patterns** - Follow established code style
- **Handle errors gracefully** - Always check return codes
- **Log appropriately** - Info, warnings, and errors
- **Be backwards compatible** - Don't break existing setups

## 🏆 Recognition

Contributors will be:
- Listed in README.md acknowledgments
- Mentioned in release notes for significant contributions
- Invited as collaborators for sustained contributions

## 📞 Getting Help

Stuck? Need guidance?
- **Create a discussion** for general questions
- **Join existing issues** to collaborate
- **Read the code** - it's well-commented
- **Test locally** before asking

---

**Happy contributing! 🚀**

*Every contribution, no matter how small, makes this project better for everyone.*
