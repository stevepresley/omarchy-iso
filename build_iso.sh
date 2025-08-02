#!/bin/bash

set -e

pacman-key --init
pacman --noconfirm -Sy archlinux-keyring
pacman --noconfirm -Sy archiso git

# Packages to add to the archiso profile packages
# As a base example (the TUI packages needs to be here)
packages=(
	git
	impala
)

cache_dir=$(realpath --canonicalize-missing ~/.cache/omarchy/iso_$(date +%Y-%m-%d))

mkdir -p $cache_dir/
cp -r archiso/configs/releng/* $cache_dir/

# We add in our auto-start applications
# First we'll check for an active internet connection
# Then we'll start omarchy-tui
cat <<- _EOF_ | tee $cache_dir/airootfs/root/.zprofile
	check_connectivity.sh && omarchy-tui
_EOF_

# Add packages to the archiso profile packages
for package in "${packages[@]}"; do
	echo "$package" >> "$cache_dir/packages.x86_64"
done

# We patch grub to our liking:
(cd $cache_dir/ && git apply /grub-autoboot.patch)
# We could also use:
# patch -p1 < grub-autoboot.patch

mkarchiso -v -w "$cache_dir/work/" -o "/out/" "$cache_dir/"