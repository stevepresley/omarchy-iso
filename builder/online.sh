#!/bin/bash
set -e

# Note that these are packages installed to the Arch container used to build the ISO.
pacman-key --init
pacman --noconfirm -Sy archlinux-keyring archiso sudo base-devel wget git

# Packages needed for when we run the Omarchy installer
arch_packages=(git wget gum openssl iw)

# We build our iso here
cache_dir=$(realpath --canonicalize-missing ~/.cache/omarchy/iso_$(date +%Y-%m-%d))
mkdir -p $cache_dir
cd $cache_dir

# We base our ISO on the official arch ISO (releng) config
cp -r /archiso/configs/releng/* $cache_dir/

# Insert the configurator in the root users home folder (default user in the official releng ISO profile).
wget -qO "airootfs/root/installer" https://raw.githubusercontent.com/omacom-io/omarchy-installer/HEAD/installer

# Avoid using reflector for mirror identification
rm "airootfs/etc/systemd/system/multi-user.target.wants/reflector.service"
rm -rf "airootfs/etc/systemd/system/reflector.service.d"
rm -rf "airootfs/etc/xdg/reflector"

# Configure sudoers for passwordless installation
# This allows the installer to run without password prompts
# mkdir -p "$cache_dir/airootfs/etc/sudoers.d"
# cp /builder/configs/sudo-less-installation "$cache_dir/airootfs/etc/sudoers.d/99-omarchy-installer"

# Ensure the Omarchy installer launches automatically on boot
cp /builder/cmds/autostart.sh airootfs/root/.automated_script.sh

# Patch the default archiso install files
git apply /builder/patches/profiledef.patch
git apply /builder/patches/grub-autoboot.patch
git apply /builder/patches/efi-autoboot.patch

# Remove the default motd
rm airootfs/etc/motd

# Add our needed packages to packages.x86_64
printf '%s\n' "${arch_packages[@]}" >>"packages.x86_64"

mkdir -p /tmp/cleandb

# Finally, we assemble the entire ISO
mkarchiso -v -w "$cache_dir/work/" -o "/out/" "$cache_dir/"
