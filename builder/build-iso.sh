#!/bin/bash

set -e

# Note that these are packages installed to the Arch container
# used to build the ISO.
pacman-key --init
pacman --noconfirm -Sy archlinux-keyring
pacman --noconfirm -Sy archiso git python-pip sudo base-devel jq

build_cache_dir="/var/cache"
offline_mirror_dir="$build_cache_dir/airootfs/var/cache/omarchy/mirror/offline"
offline_ruby_dir="$build_cache_dir/airootfs/var/cache/omarchy/ruby"

# We need to fiddle with pip settings
# in order to install to the correct place
# as well as ignore some errors to make this less verbose
export PIP_ROOT="$build_cache_dir/airootfs/"
export PIP_ROOT_USER_ACTION="ignore"
export PIP_NO_WARN_SCRIPT_LOCATION=1
export PIP_BREAK_SYSTEM_PACKAGES=1

# These packages will be installed **into** the ISO, and
# won't be available to either archinstall or omarchy installer.
python_packages=(
  terminaltexteffects
)
arch_packages=(
  git
  gum
  jq
  openssl
  plymouth
  tzupdate
)

prepare_offline_mirror() {
  # Certain packages in omarchy.packages are AUR packages.
  # These needs to be pre-built and placed in https://pkgs.omarchy.org/$arch
  echo "Reading and combining packages from all package files..."

  # Combine all packages into one array
  # Start with base ISO packages (including our arch_packages already appended)
  all_packages=($(cat "$build_cache_dir/packages.x86_64"))

  # Add packages from the omarchy installer's unified package list
  all_packages+=($(grep -v '^#' "$build_cache_dir/airootfs/root/omarchy/install/omarchy-base.packages" | grep -v '^$'))
  all_packages+=($(grep -v '^#' "$build_cache_dir/airootfs/root/omarchy/install/omarchy-other.packages" | grep -v '^$'))

  # Add archinstall needed packages
  all_packages+=($(grep -v '^#' /builder/archinstall.packages | grep -v '^$'))

  if [ ${#all_packages[@]} -gt 0 ]; then
    mkdir -p /tmp/offlinedb

    # Download all the packages to the offline mirror inside the ISO
    echo "Downloading all packages (including AUR) to offline mirror: ${all_packages[@]}"
    pacman --config /configs/pacman-online.conf \
      --noconfirm -Syw "${all_packages[@]}" \
      --cachedir $offline_mirror_dir/ \
      --dbpath /tmp/offlinedb

    repo-add --new "$offline_mirror_dir/offline.db.tar.gz" "$offline_mirror_dir/"*.pkg.tar.zst

    rm "$build_cache_dir/airootfs/etc/pacman.d/hooks/uncomment-mirrors.hook"
  fi
}

disable_reflector() {
  # Avoid using reflector for mirror identification as we are relying on the global CDN
  rm "$build_cache_dir/airootfs/etc/systemd/system/multi-user.target.wants/reflector.service"
  rm -rf "$build_cache_dir/airootfs/etc/systemd/system/reflector.service.d"
  rm -rf "$build_cache_dir/airootfs/etc/xdg/reflector"
}

#######################
# Build process start
#######################

mkdir -p $build_cache_dir/
mkdir -p $offline_mirror_dir/
mkdir -p $offline_ruby_dir/

# We base our ISO on the official arch ISO (releng) config
cp -r /archiso/configs/releng/* $build_cache_dir/
rm "$build_cache_dir/airootfs/etc/motd"
disable_reflector

# Bring in our configs
cp -r /configs/* $build_cache_dir/

# Clone Omarchy itself
git clone -b $OMARCHY_INSTALLER_REF https://github.com/$OMARCHY_INSTALLER_REPO.git "$build_cache_dir/airootfs/root/omarchy"

# Make log uploader available in the ISO too
mkdir -p "$build_cache_dir/airootfs/usr/local/bin/"
cp "$build_cache_dir/airootfs/root/omarchy/bin/omarchy-upload-log" "$build_cache_dir/airootfs/usr/local/bin/omarchy-upload-log"

# Copy the Omarchy Plymouth theme to the ISO
mkdir -p "$build_cache_dir/airootfs/usr/share/plymouth/themes/omarchy"
cp -r "$build_cache_dir/airootfs/root/omarchy/default/plymouth/"* "$build_cache_dir/airootfs/usr/share/plymouth/themes/omarchy/"

# Download the configurator
mkdir -p "$build_cache_dir/airootfs/root"
curl -fsSL -o "$build_cache_dir/airootfs/root/configurator" \
  "https://raw.githubusercontent.com/$OMARCHY_CONFIGURATOR_REPO/$OMARCHY_CONFIGURATOR_REF/configurator"

# Add our additional packages to packages.x86_64
printf '%s\n' "${arch_packages[@]}" >>"$build_cache_dir/packages.x86_64"

prepare_offline_mirror

# Download Ruby tarball if not already cached
ruby_tarball="ruby-3.4.5-rails-8.0.2.1-x86_64.tar.gz"
if [ ! -f "$offline_ruby_dir/$ruby_tarball" ]; then
  echo "Downloading Ruby tarball..."
  curl -fsSL -o "$offline_ruby_dir/$ruby_tarball" \
    "https://pkgs.omarchy.org/ruby/$ruby_tarball"
else
  echo "Ruby tarball already cached, skipping download"
fi

# Create a symlink to the offline mirror instead of duplicating it.
# mkarchiso needs packages at /var/cache/omarchy/mirror/offline in the container,
# but they're actually in $build_cache_dir/airootfs/var/cache/omarchy/mirror/offline
mkdir -p /var/cache/omarchy/mirror
ln -s "$offline_mirror_dir" "/var/cache/omarchy/mirror/offline"

# Install Python packages for the installer into the ISO
# file system.
pip install "${python_packages[@]}"

# Copy the pacman.conf to the ISO's /etc directory so the live environment uses our
# same config when booted
cp $build_cache_dir/pacman.conf "$build_cache_dir/airootfs/etc/pacman.conf"

# Finally, we assemble the entire ISO
mkarchiso -v -w "$build_cache_dir/work/" -o "/out/" "$build_cache_dir/"
