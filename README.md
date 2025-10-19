# Omarchy Advanced ISO

> **Note**: This is a fork of [Omarchy ISO](https://github.com/omacom-io/omarchy-iso) that builds ISOs with [Omarchy Advanced](https://github.com/stevepresley/omarchy-advanced) features.

The Omarchy Advanced ISO streamlines the installation of Omarchy with advanced configuration options. It includes the enhanced Omarchy Configurator with **Advanced Mode** support as a front-end to archinstall, and automatically launches the [Omarchy Advanced Installer](https://github.com/stevepresley/omarchy-advanced) after base Arch has been setup.

## What's Different

This ISO builder adds **Advanced Mode** to the configurator, offering:

- **Installation Profiles** - Choose between Workstation or VM configurations
- **Optional LUKS Encryption** - Enable or disable disk encryption based on your needs
- **SSH Server Setup** - Optionally install and configure OpenSSH
- **VNC Remote Access** - Install wayvnc for headless VM operation
- **Configurable Autologin** - Control authentication behavior

The resulting ISO can install systems optimized for virtual machines, development environments, or testing scenarios.

## Downloading the latest ISO

Custom ISOs are built from this repository. See [Creating the ISO](#creating-the-iso) below.

For vanilla Omarchy, visit [iso.omarchy.org](https://iso.omarchy.org).

## Branches

This repository uses a multi-tier branching strategy:

- **`build`** (default) - Stable release branch for building production ISOs - **use this branch**
- **`main`** - Synced with upstream [omacom-io/omarchy-iso](https://github.com/omacom-io/omarchy-iso)
- **`feature/*`** - Development branches

**For contributors**: Please read [CONTRIBUTING.md](CONTRIBUTING.md) to understand our workflow.

## Creating the ISO

Run `./bin/omarchy-iso-make` and the output goes into `./release`.

### Environment Variables

You can customize the repositories used during the build process:

- `OMARCHY_INSTALLER_REPO` - GitHub repository for the installer (default: `stevepresley/omarchy-advanced`)
- `OMARCHY_INSTALLER_REF` - Git ref (branch/tag) for the installer (default: `build`)

**Production builds** (use stable `build` branch):
```bash
export OMARCHY_INSTALLER_REPO="stevepresley/omarchy-advanced"
export OMARCHY_INSTALLER_REF="build"
./bin/omarchy-iso-make
```

**Testing builds** (use specific feature branch):
```bash
export OMARCHY_INSTALLER_REPO="stevepresley/omarchy-advanced"
export OMARCHY_INSTALLER_REF="feature/my-feature"
./bin/omarchy-iso-make
```

## Testing the ISO

Run `./bin/omarchy-iso-boot [release/omarchy.iso]`.

## Signing the ISO

Run `./bin/omarchy-iso-sign [gpg-user] [release/omarchy.iso]`.

## Uploading the ISO

Run `./bin/omarchy-iso-upload [release/omarchy.iso]`. This requires you've configured rclone (use `rclone config`).

## Full release of the ISO

Run `./bin/omarchy-iso-release` to create, test, sign, and upload the ISO in one flow.
