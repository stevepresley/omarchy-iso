#!/bin/bash

set -e

# Note that these are packages installed to the Arch container
# used to build the ISO.
pacman-key --init
pacman --noconfirm -Sy archlinux-keyring
pacman --noconfirm -Sy archiso git python-pip sudo base-devel

cache_dir=$(realpath --canonicalize-missing ~/.cache/omarchy/iso_$(date +%Y-%m-%d))
aur_cache_dir="/var/cache/omarchy/mirror/aur"

# We need to fiddle with pip settings
# in order to install to the correct place
# as well as ignore some errors to make this less verbose
export PIP_ROOT="$cache_dir/airootfs/"
export PIP_ROOT_USER_ACTION="ignore"
export PIP_NO_WARN_SCRIPT_LOCATION=1
export PIP_BREAK_SYSTEM_PACKAGES=1

# Arch packages to add to the archiso profile packages
# As a base example (the TUI packages needs to be here)
arch_packages=(
	git
	impala
	gum
	openssl
	wget
)
# These are Python specific packages that will get installed
# onto the ISO
python_packages=(
	terminaltexteffects
)
aur_packages=(
	tzupdate
)

build_aur() {
	PACKAGE=$1
	BUILDDEST=$2

	mkdir -p /etc/sudoers.d/
	useradd --create-home --shell /bin/bash aurbuilder
	echo "aurbuilder ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/aurbuilder

	sudo -H -u aurbuilder git clone "https://aur.archlinux.org/$1.git" "/home/aurbuilder/$1"

	# TODO: We should add --sign here, to sign these packages
	# with a key that we trust and want to use. It's only used internally in the ISO.
	# but it would make sure we don't install unsigned packages even during our build process.
	(cd "/home/aurbuilder/$1" && sudo -H -u aurbuilder makepkg --clean --cleanbuild --force --noconfirm --needed --syncdeps --rmdeps)
	mv "/home/aurbuilder/$1/"*.pkg.tar.zst "$BUILDDEST/"

	rm -rf "/home/aurbuilder/$1"

	rm /etc/sudoers.d/aurbuilder
	USERGROUPS_ENAB=yes userdel aurbuilder
}

set_geo_mirror() {
	# https://geo.mirror.pkgbuild.com/
	rm "$cache_dir/airootfs/etc/pacman.d/hooks/uncomment-mirrors.hook"
	echo "Server = $1" > "$cache_dir/airootfs/etc/pacman.d/mirrorlist"
}

mkdir -p $cache_dir/
mkdir -p $aur_cache_dir/

# We base our ISO on the official arch ISO (releng) config
cp -r archiso/configs/releng/* $cache_dir/

# We clone the installer, and move it to the root users home folder
# since this is the default user in the official releng ISO profile.
git clone -b archinstall-syntax --single-branch https://github.com/Torxed/omarchy-installer "$cache_dir/airootfs/root/omarchy-installer"
mv "$cache_dir/airootfs/root/omarchy-installer/installer" "$cache_dir/airootfs/root/installer"
mv "$cache_dir/airootfs/root/omarchy-installer/logo.txt" "$cache_dir/airootfs/root/logo.txt"
rm -rf "$cache_dir/airootfs/root/omarchy-installer"

# Copy in the connectivity check script
cp /check_connectivity.sh "$cache_dir/airootfs/root/check_connectivity.sh"

# We add in our auto-start applications
# First we'll check for an active internet connection
# Then we'll start the omarchy installer
cat <<- _EOF_ | tee $cache_dir/airootfs/root/.automated_script.sh
	#!/usr/bin/env bash

	if [[ \$(tty) == "/dev/tty1" ]]; then
	    sh ./check_connectivity.sh && \
	    sh ./installer && \
	    archinstall \
	    	--config user_configuration.json \
	    	--creds user_credentials.json \
	    	--silent && \
	    wget -qO- https://omarchy.org/install | bash
	fi
_EOF_

# Add Arch packages to the archiso profile packages
for package in "${arch_packages[@]}"; do
	echo "$package" >> "$cache_dir/packages.x86_64"
done

# We have to build the AUR packages one by one
# and place them in a local mirror for the ISO build process.
# Otherwise the ISO won't be able to source them
if [ ${#aur_packages[@]} -gt 0 ]; then
	for package in "${aur_packages[@]}"; do
		if build_aur "$package" "$aur_cache_dir/"; then
			echo "$package" >> "$cache_dir/packages.x86_64"
		fi
	done

	ls -l "$aur_cache_dir/"
	repo-add --new "$aur_cache_dir/aur.db.tar.gz" "$aur_cache_dir/"*.pkg.tar.zst

	# And patch in the mirror to the pacman.conf to include our AUR repo
	(cd $cache_dir/ && git apply /aur-mirror.patch)
fi

# We patch permissions, grub and efi loaders to our liking:
(cd $cache_dir/ && git apply /permissions.patch)
(cd $cache_dir/ && git apply /grub-autoboot.patch)
(cd $cache_dir/ && git apply /efi-autoboot.patch)
# We could also use:
# patch -p1 < aur-mirror.patch
# patch -p1 < permissions.patch
# patch -p1 < grub-autoboot.patch
# patch -p1 < efi-autoboot.patch

# Remove the default motd
rm "$cache_dir/airootfs/etc/motd"

# Install Python packages for the installer into the ISO
# file system.
pip install "${python_packages[@]}"

set_geo_mirror "https://geo.mirror.pkgbuild.com/"

mkarchiso -v -w "$cache_dir/work/" -o "/out/" "$cache_dir/"