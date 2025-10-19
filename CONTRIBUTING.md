# Contributing to Omarchy Advanced ISO

Thank you for your interest in contributing to the Omarchy Advanced ISO builder! This guide will help you understand our workflow and how to contribute effectively.

## About This Project

Omarchy Advanced ISO is a fork of [Omarchy ISO](https://github.com/omacom-io/omarchy-iso) that builds custom Arch Linux ISOs with the [Omarchy Advanced installer](https://github.com/stevepresley/omarchy-advanced).

The ISO includes:
- Omarchy Configurator with **Advanced Mode** support
- archinstall integration for base system setup
- Automatic Omarchy Advanced installer launch after base installation
- Pre-cached packages for offline installation

## Branch Structure

This repository uses the same three-tier branching strategy as [omarchy-advanced](https://github.com/stevepresley/omarchy-advanced):

### Branch Roles

- **`build`** (default branch) - Our stable public release branch
  - Used for production ISO builds
  - Always in a releasable state
  - All features merge here via pull requests
  - **This is the branch you should use and contribute to**

- **`main`** - Synced with upstream `omacom-io/omarchy-iso`
  - Contains vanilla Omarchy ISO builder
  - Periodically synced with upstream
  - Used to integrate upstream updates into `build`
  - **Do not create feature branches from this branch**

- **`feature/*`** - Development branches
  - Created from `build` branch
  - Merged back to `build` via pull requests
  - Deleted after merge

### Why This Structure?

- **Cleaner upstream merges**: `main` stays clean with only upstream code
- **Stable public branch**: `build` is always ready for release
- **Reduced conflicts**: Feature branches based on `build` include all custom code
- **Clear separation**: Upstream vs custom changes are clearly separated

## How to Contribute

### For New Contributors

1. **Fork the repository** on GitHub

2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/YOUR-USERNAME/omarchy-advanced-iso.git
   cd omarchy-advanced-iso
   ```

3. **Add upstream remote** (to stay in sync):
   ```bash
   git remote add upstream https://github.com/stevepresley/omarchy-advanced-iso.git
   ```

4. **Create a feature branch from `build`**:
   ```bash
   git checkout build
   git pull upstream build
   git checkout -b feature/your-feature-name
   ```

5. **Make your changes** and commit:
   ```bash
   git add .
   git commit -m "Description of your changes"
   ```

6. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```

7. **Create a Pull Request**:
   - Go to GitHub
   - Click "New Pull Request"
   - **Base repository**: `stevepresley/omarchy-advanced-iso`
   - **Base branch**: `build`
   - **Head repository**: `YOUR-USERNAME/omarchy-advanced-iso`
   - **Compare branch**: `feature/your-feature-name`

### For Maintainers

#### Syncing Upstream Changes

Periodically sync with upstream Omarchy ISO:

```bash
# Update main with upstream changes
git checkout main
git pull upstream main
git push origin main

# Create PR to integrate into build
gh pr create --base build --head main \
  --title "Sync upstream Omarchy ISO" \
  --body "Integrates latest changes from omacom-io/omarchy-iso"

# Review, test, and merge the PR
# Resolve any conflicts between upstream and custom features
```

#### Merging Feature Branches

```bash
# Feature branches should come via pull request
# Review the PR on GitHub
# Build and test the ISO before merging
# Merge via GitHub UI (creates merge commit)

# Or via command line:
git checkout build
git pull origin build
git merge --no-ff feature/feature-name
git push origin build
git branch -d feature/feature-name
```

## Branch Naming Conventions

Use descriptive names with appropriate prefixes:

- `feature/feature-name` - New features (e.g., configurator enhancements)
- `fix/bug-description` - Bug fixes
- `docs/documentation-update` - Documentation changes
- `refactor/code-improvement` - Code refactoring
- `sync/upstream-vX.X` - Upstream sync PRs (main → build)

## Development Guidelines

### ISO Building

Build the ISO locally to test your changes:

```bash
# Use build branch for production builds
export OMARCHY_INSTALLER_REPO="stevepresley/omarchy-advanced"
export OMARCHY_INSTALLER_REF="build"

./bin/omarchy-iso-make

# For testing unreleased features, use specific feature branch
export OMARCHY_INSTALLER_REF="feature/my-feature"
./bin/omarchy-iso-make
```

### Testing

ISO changes require thorough testing:

1. **Build the ISO**: Run `omarchy-iso-make` successfully
2. **Boot Test**: Use `omarchy-iso-boot` or test in VM (VirtualBox/VMware/QEMU)
3. **Standard Mode Test**: Run through standard installation flow
4. **Advanced Mode Test**: Test all advanced options (Workstation + VM profiles)
5. **Feature Verification**: Verify SSH/VNC/autologin work as expected

### Code Style

Follow the existing code style:
- Bash best practices for shell scripts
- Follow patterns in `configs/airootfs/root/` scripts
- Use `gum` for interactive prompts
- Add comments for complex logic

### Commit Messages

Write clear, descriptive commit messages:

```
Add VM profile default settings to configurator

- Set LUKS default to N for VM profile
- Set SSH default to Y for VM profile
- Set VNC default to Y for VM profile
- Update summary display with profile info

Closes #123
```

## Project Structure

Key directories and files:

```
omarchy-advanced-iso/
├── bin/                           # ISO utilities
│   ├── omarchy-iso-make          # Build the ISO
│   ├── omarchy-iso-boot          # Test ISO in VM
│   ├── omarchy-iso-sign          # Sign ISO with GPG
│   └── omarchy-iso-upload        # Upload to hosting
├── configs/                       # archiso configuration
│   ├── airootfs/                 # Files copied to ISO
│   │   └── root/                 # Root user files
│   │       ├── configurator      # Interactive installer UI
│   │       └── .automated_script.sh  # Automated install flow
│   ├── packages.x86_64           # Packages included in ISO
│   └── profiledef.sh             # ISO metadata
├── archiso/                      # archiso submodule
└── README.md                     # Project overview
```

### Modifying the Configurator

The configurator (`configs/airootfs/root/configurator`) is the main user-facing script:

1. Uses `gum` for interactive prompts
2. Generates archinstall JSON configs
3. Creates state file for Omarchy installer
4. Handles both Standard and Advanced modes

When modifying:
- Test both Standard and Advanced paths
- Verify JSON generation is valid
- Ensure state file has all required variables
- Test summary screen displays correctly

### Adding Packages to ISO

Edit `configs/packages.x86_64`:
- One package per line
- Comments start with `#`
- Packages are pre-cached for offline installation

### Environment Variables

Build-time environment variables:

- `OMARCHY_INSTALLER_REPO` - GitHub repository for installer (default: `stevepresley/omarchy-advanced`)
- `OMARCHY_INSTALLER_REF` - Git branch/tag for installer (default: `build`)

## ISO Release Process

For maintainers performing releases:

1. **Ensure `build` branch is stable** - all features tested
2. **Build the ISO**:
   ```bash
   export OMARCHY_INSTALLER_REPO="stevepresley/omarchy-advanced"
   export OMARCHY_INSTALLER_REF="build"
   ./bin/omarchy-iso-make
   ```
3. **Test the ISO** thoroughly (both modes, both profiles)
4. **Sign the ISO** (optional): `./bin/omarchy-iso-sign [gpg-user] [iso-file]`
5. **Upload/release** as appropriate

## Questions or Issues?

- **Bug reports**: Open an issue on GitHub
- **Feature requests**: Open an issue with detailed description
- **ISO build failures**: Include full build log in issue
- **Questions**: Start a discussion on GitHub Discussions

## Related Repositories

- **[omarchy-advanced](https://github.com/stevepresley/omarchy-advanced)** - The installer that runs after base installation
- **[omarchy-iso](https://github.com/omacom-io/omarchy-iso)** - Upstream vanilla Omarchy ISO
- **[omarchy](https://github.com/basecamp/omarchy)** - Upstream vanilla Omarchy installer

## License

By contributing to Omarchy Advanced ISO, you agree that your contributions will be licensed under the same license as the upstream project.

---

**Thank you for contributing to Omarchy Advanced ISO!**
