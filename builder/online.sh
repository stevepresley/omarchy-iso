#!/bin/bash

set -e

# Note that these are packages installed to the Arch container used to build the ISO.
pacman-key --init
pacman --noconfirm -Sy archlinux-keyring archiso sudo base-devel wget git

# Packages needed for when we run the Omarchy installer
arch_packages=(git wget gum openssl iw)

# We build our iso here
cache_dir=$(realpath --canonicalize-missing ~/.cache/omarchy/iso_$(date +%Y-%m-%d))
mkdir -p $cache_dir/

# We base our ISO on the official arch ISO (releng) config
cp -r archiso/configs/releng/* $cache_dir/

# Insert the configurator in the root users home folder (default user in the official releng ISO profile).
wget -qO "$cache_dir/airootfs/root/installer" https://raw.githubusercontent.com/omacom-io/omarchy-installer/HEAD/installer

# Configure sudoers for passwordless installation
# This allows the installer to run without password prompts
mkdir -p "$cache_dir/airootfs/etc/sudoers.d"
cp /builder/configs/sudo-less-installation "$cache_dir/airootfs/etc/sudoers.d/99-omarchy-installer"

# We add in our auto-start applications
# First we'll check for an active internet connection
# Then we'll start the omarchy installer
cp /builder/cmds/autostart.sh "$cache_dir/airootfs/root/.automated_script.sh"

# We patch permissions, grub and efi loaders to our liking:
(cd $cache_dir/ && git apply /builder/patches/permissions-online.patch)
(cd $cache_dir/ && git apply /builder/patches/grub-autoboot.patch)
(cd $cache_dir/ && git apply /builder/patches/efi-autoboot.patch)

# Remove the default motd
rm "$cache_dir/airootfs/etc/motd"

# Add our needed packages to packages.x86_64
printf '%s\n' "${arch_packages[@]}" >>"$cache_dir/packages.x86_64"

mkdir -p /tmp/cleandb

# Finally, we assemble the entire ISO
mkarchiso -v -w "$cache_dir/work/" -o "/out/" "$cache_dir/"
