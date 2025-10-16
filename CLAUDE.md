# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a fork of `omacom-io/omarchy-iso` to `stevepresley/omarchy-iso` for implementing Advanced Mode features.

The Omarchy ISO streamlines the installation of Omarchy by providing:
- The Omarchy Configurator (front-end to archinstall)
- Automatic launch of the Omarchy Installer after base Arch setup

## Fork Configuration

- **Origin**: `stevepresley/omarchy-iso` (push target)
- **Upstream**: `omacom-io/omarchy-iso` (for pulling updates)
- **Local user**: `stevepresley <github@stevepresley.net>` (configured for this repo)

## Key Files

- **`configs/airootfs/root/configurator`** - Interactive configuration script that:
  - Collects user inputs (keyboard, username, password, hostname, timezone, disk)
  - Generates JSON configuration files for archinstall
  - **Advanced Mode modifications**: Adds Standard/Advanced mode selection, profile selection, LUKS/SSH/VNC/autologin prompts

- **`configs/airootfs/root/.automated_script.sh`** - Orchestrates the installation:
  - Runs configurator to gather user input
  - Executes archinstall with generated JSON
  - Chroots into new system and runs omarchy installer
  - **Advanced Mode modifications**: Copies state file into new system, sets environment variables

- **`builder/build-iso.sh`** - Main ISO build script
- **`bin/omarchy-iso-make`** - Builds the ISO (output: `./release/`)

## Environment Variables for Build

When building the ISO, you can specify which omarchy fork/branch to include:

```bash
OMARCHY_INSTALLER_REPO="stevepresley/omarchy" \
OMARCHY_INSTALLER_REF="feature/omarchy-advanced" \
./bin/omarchy-iso-make
```

This tells the ISO builder to use your forked omarchy repository and feature branch.

## Development Workflow

### Git Workflow
- **NEVER commit directly to main branch**
- Always work on feature branches (e.g., `feature/advanced-mode`)
- All commits use: `stevepresley <github@stevepresley.net>`
- This fork pushes to `stevepresley/omarchy-iso` (not `omacom-io/omarchy-iso`)

### Testing
- Use `./bin/omarchy-iso-make` to build ISO
- Use `./bin/omarchy-iso-boot release/omarchy.iso` to test in VM
- Test both Standard and Advanced modes in configurator

## Advanced Mode Implementation

See the main project documentation at `stevepresley/omarchy` for the complete Advanced Mode feature plan.

### Changes in this repository:
1. **Configurator modifications** (`configs/airootfs/root/configurator`):
   - Add Standard/Advanced mode selection (first step)
   - Add profile selection (Workstation/VM)
   - Add LUKS encryption toggle (optional based on profile)
   - Add SSH/VNC/autologin prompts
   - Generate state file with user choices
   - Conditionally generate archinstall JSON (with or without LUKS)

2. **Automated script modifications** (`configs/airootfs/root/.automated_script.sh`):
   - Copy state file to new system
   - Pass state file path to omarchy installer via environment variable

### State File Format
The configurator generates `/tmp/omarchy-advanced-state.json`:
```json
{
  "installation_mode": "Advanced",
  "install_profile": "VM",
  "enable_luks": "false",
  "enable_ssh": "true",
  "enable_wayvnc": "true",
  "enable_autologin": "true"
}
```

This file is copied to the new system and read by the omarchy installer to apply advanced configuration.
