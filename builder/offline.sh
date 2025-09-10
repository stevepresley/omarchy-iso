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
  tzupdate # This is technically an AUR package
)

prepare_offline_mirror() {
  # Certain packages in omarchy.packages are AUR packages.
  # These needs to be pre-built and placed in https://pkgs.omarchy.org/$arch
  echo "Reading and combining packages from all package files..."

  # Combine all packages into one array
  # Start with base ISO packages (including our arch_packages already appended)
  all_packages=($(cat "$build_cache_dir/packages.x86_64"))

  # Add packages from omarchy and archinstall
  [ -f /builder/packages/omarchy.packages ] && all_packages+=($(grep -v '^#' /builder/packages/omarchy.packages | grep -v '^$'))
  [ -f /builder/packages/archinstall.packages ] && all_packages+=($(grep -v '^#' /builder/packages/archinstall.packages | grep -v '^$'))

  if [ ${#all_packages[@]} -gt 0 ]; then
    # This assume we've manually built all the AUR packages
    # and made them accessible "online" during the build process:
    (cd $build_cache_dir/ && git apply /builder/patches/offline/aur-mirror.patch)
    (cd $build_cache_dir/ && git apply /builder/patches/offline/enable-multilib.patch)

    mkdir -p /tmp/offlinedb

    # Download all the paclibffikages to the offline mirror inside the ISO
    echo "Downloading all packages (including AUR) to offline mirror: ${all_packages[@]}"
    pacman --config $build_cache_dir/pacman.conf \
      --noconfirm -Syw "${all_packages[@]}" \
      --cachedir $offline_mirror_dir/ \
      --dbpath /tmp/offlinedb

    repo-add --new "$offline_mirror_dir/offline.db.tar.gz" "$offline_mirror_dir/"*.pkg.tar.zst

    rm "$build_cache_dir/airootfs/etc/pacman.d/hooks/uncomment-mirrors.hook"

    # Revert the "online" AUR patch, as we'll replace it with the proper
    # offline patched mirror for the ISO later.
    (cd $build_cache_dir && git apply -R /builder/patches/offline/aur-mirror.patch)
  fi
}

make_archiso_offline() {
  # This function will simply disable any online activity we have.
  # for instance the reflector.service which tries to optimize
  # mirror order by fetching the latest mirror list by default.

  # Disable reflector
  rm "$build_cache_dir/airootfs/etc/systemd/system/multi-user.target.wants/reflector.service"
  rm -rf "$build_cache_dir/airootfs/etc/systemd/system/reflector.service.d"
  rm -rf "$build_cache_dir/airootfs/etc/xdg/reflector"
}

mkdir -p $build_cache_dir/
mkdir -p $offline_mirror_dir/
mkdir -p $offline_ruby_dir/

# We base our ISO on the official arch ISO (releng) config
cp -r archiso/configs/releng/* $build_cache_dir/

# Add our needed packages to packages.x86_64 right away
printf '%s\n' "${arch_packages[@]}" >>"$build_cache_dir/packages.x86_64"

# Apply all the general patches early (same as online.sh)
# Need to do this from the cache_dir
cd $build_cache_dir
for patch in /builder/patches/*.patch; do
  git apply "$patch"
done
cd -

prepare_offline_mirror
make_archiso_offline

# Download Ruby tarball if not already cached
ruby_tarball="ruby-3.4.5-rails-8.0.2.1-x86_64.tar.gz"
if [ ! -f "$offline_ruby_dir/$ruby_tarball" ]; then
  echo "Downloading Ruby tarball..."
  curl -fsSL -o "$offline_ruby_dir/$ruby_tarball" \
    "https://pkgs.omarchy.org/ruby/$ruby_tarball"
else
  echo "Ruby tarball already cached, skipping download"
fi

# Insert the configurator in the root users home folder (default user in the official releng ISO profile).
mkdir -p "$build_cache_dir/airootfs/root"
curl -fsSL -o "$build_cache_dir/airootfs/root/configurator" \
  "https://raw.githubusercontent.com/$OMARCHY_CONFIGURATOR_REPO/$OMARCHY_CONFIGURATOR_REF/configurator"

# Clone Omarchy itself
git clone -b $OMARCHY_INSTALLER_REF --single-branch https://github.com/$OMARCHY_INSTALLER_REPO.git "$build_cache_dir/airootfs/root/omarchy"

# Copy icons to the airootfs for offline installation
mkdir -p "$build_cache_dir/airootfs/root/.local/share/applications/icons"
cp /builder/icons/*.png "$build_cache_dir/airootfs/root/.local/share/applications/icons/"

# Copy the autostart script (we'll need to create an offline version)
cp /builder/cmds/autostart-offline.sh $build_cache_dir/airootfs/root/.automated_script.sh

# Copy the log upload utility to /usr/local/bin
mkdir -p "$build_cache_dir/airootfs/usr/local/bin"
cp /builder/cmds/omarchy-upload-install-log "$build_cache_dir/airootfs/usr/local/bin/"
chmod +x "$build_cache_dir/airootfs/usr/local/bin/omarchy-upload-install-log"

# Remove the default motd
rm "$build_cache_dir/airootfs/etc/motd"

# Ensure pacman cache directory exists with proper permissions
mkdir -p "$build_cache_dir/airootfs/var/cache/pacman/pkg"
chmod 755 "$build_cache_dir/airootfs/var/cache/pacman/pkg"

# Install Python packages for the installer into the ISO
# file system.
pip install "${python_packages[@]}"

# We have to do this, because `mkarchiso` copies in the pacman.conf
# in use during the build process - so it needs to be made offline.
(cd $build_cache_dir/ && git apply --reverse /builder/patches/offline/enable-multilib.patch)
(cd "$build_cache_dir" && git apply /builder/patches/offline/offline-mirror.patch)
cp $build_cache_dir/pacman.conf "$build_cache_dir/airootfs/etc/pacman.conf"

# And we also need to duplicate the offline mirror.
# Because inside the ISO it will look for packages in /var/cache/omarchy/mirror/offline
# but that means the build of the ISO itself will also look at this location
# but in the container.
mkdir -p /var/cache/omarchy/mirror
cp -r "$offline_mirror_dir" "/var/cache/omarchy/mirror/"

# Finally, we assemble the entire ISO
mkarchiso -v -w "$build_cache_dir/work/" -o "/out/" "$build_cache_dir/"
