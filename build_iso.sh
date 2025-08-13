#!/bin/bash

set -e

# Note that these are packages installed to the Arch container
# used to build the ISO.
pacman-key --init
pacman --noconfirm -Sy archlinux-keyring
pacman --noconfirm -Sy archiso git python-pip sudo base-devel jq wget

cache_dir=$(realpath --canonicalize-missing ~/.cache/omarchy/iso_$(date +%Y-%m-%d))
offline_mirror_dir="$cache_dir/airootfs/var/cache/omarchy/mirror/offline"
aur_mirror_dir="/var/cache/omarchy/mirror/aur"

# We need to fiddle with pip settings
# in order to install to the correct place
# as well as ignore some errors to make this less verbose
export PIP_ROOT="$cache_dir/airootfs/"
export PIP_ROOT_USER_ACTION="ignore"
export PIP_NO_WARN_SCRIPT_LOCATION=1
export PIP_BREAK_SYSTEM_PACKAGES=1

# Function using the AUR web JSON RPC to query if a package exists in AUR
is_aur_package() {
	resultcount=`wget -qO- "https://aur.archlinux.org/rpc/?v=5&type=info&arg=$1" 2>/dev/null | jq .resultcount`
	[ "$resultcount" = "1" ]
}

# These packages will be installed **into** the ISO, and
# won't be available to either archinstall or omarchy installer.
python_packages=(
	terminaltexteffects
)
arch_packages=(
	git
	impala
	gum
	openssl
	wget
)
aur_packages=(
	tzupdate
)

# The following package lists are what will be available
# in the ISO as "offline mirror packages".
offline_arch_packages=()
offline_aur_packages=()

prep_aur_builder() {
	mkdir -p /etc/sudoers.d/
	useradd --create-home --shell /bin/bash aurbuilder
	echo "aurbuilder ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/aurbuilder
}

cleanup_aur_builder() {
	# Not sure why killall gpg-agent produces "gpg-agent(27): Operation not permitted" yet.
	# so || true it is.
	sudo -H -u aurbuilder killall gpg-agent 2>/dev/null || true
	sudo -H -u aurbuilder killall dirmngr 2>/dev/null || true
	sudo -H -u aurbuilder killall keyboxd 2>/dev/null || true

	rm /etc/sudoers.d/aurbuilder

	# Make sure no remaining processes are running under aurbuilder
	# pkill -u aurbuilder
	killall --user aurbuilder

	# Weirdly, certain processes will be hanging a while
	# so we need to sleep before running userdel
	USERGROUPS_ENAB=yes userdel aurbuilder
}

build_aur() {
	local PACKAGE=$1
	local BUILDDEST=$2
	# Certain packages name, such as "yaru-icon-theme" differs from the actual
	# package/build name, in this example it's "yaru" and we use PackageBase to approximate this.
	local AUR_PKG_BASE=`wget -qO- "https://aur.archlinux.org/rpc/?v=5&type=info&arg=$PACKAGE" 2>/dev/null | jq -r .results[0].PackageBase`

	sudo -H -u aurbuilder git clone "https://aur.archlinux.org/$AUR_PKG_BASE.git" "/home/aurbuilder/$PACKAGE"

	# Import any GPG keys defined in the PKGBUILD
	# This is normally now how you should treat AUR packages (blind trust).
	# But it will be okay if we manually verify packages before each ISO build.
	(
		cd "/home/aurbuilder/$PACKAGE"
		source PKGBUILD
		if [ -n "${validpgpkeys[*]}" ]; then
			for key in "${validpgpkeys[@]}"; do
				sudo -H -u aurbuilder gpg --recv-keys "$key" || true
			done
		fi
	)
	
	# TODO: We should add --sign here, to sign these packages
	# with a key that we trust and want to use. It's only used internally in the ISO.
	# but it would make sure we don't install unsigned packages even during our build process.
	
	(cd "/home/aurbuilder/$PACKAGE" && sudo -H -u aurbuilder makepkg --clean --cleanbuild --force --noconfirm --needed --syncdeps --rmdeps)
	mv "/home/aurbuilder/$PACKAGE/"*.pkg.tar.zst "$BUILDDEST/"

	rm -rf "/home/aurbuilder/$PACKAGE"
}

prepare_offline_mirror() {
	# We have to build the AUR packages one by one
	# and place them in a local mirror for the ISO build process.
	# Otherwise the ISO won't be able to source them

	# So first we need to figure out if packages are AUR packages or not.
	# As we will have to build the AUR before adding them to our mirror.
	echo "Categorizing packages..."
	for package_file in omarchy.packages archinstall.packages; do
		if [ -f "$package_file" ]; then
			echo "Processing $package_file..."
			while IFS= read -r package; do
				# Skip empty lines and comments
				[[ -z "$package" || "$package" =~ ^[[:space:]]*# ]] && continue

				# Check if it exists in AUR
				if is_aur_package "$package"; then
					offline_aur_packages+=("$package")
					echo "  AUR: $package"
				else
					offline_arch_packages+=("$package")
					echo "  Arch: $package"
				fi
			done < "$package_file"
		fi
	done

	if [ ${#offline_aur_packages[@]} -gt 0 ]; then
		prep_aur_builder

		for package in "${offline_aur_packages[@]}"; do
			build_aur "$package" "$offline_mirror_dir/"
		done

		cleanup_aur_builder
	fi

	if [ ${#offline_arch_packages[@]} -gt 0 ]; then
		mkdir -p /tmp/offlinedb
		
		# Download all our official packages 
		pacman --noconfirm -Syw "${offline_arch_packages[@]}" \
			--cachedir $offline_mirror_dir/ \
			--dbpath /tmp/offlinedb
	fi

	# Apply offline mirror "patches" if we have any offline packages
	# This will disable online mirrors completely,
	# for now this is the best option to avoid errors trying to sync official mirrors.
	if [ ${#offline_aur_packages[@]} -gt 0 ] || [ ${#offline_arch_packages[@]} -gt 0 ]; then
		repo-add --new "$offline_mirror_dir/offline.db.tar.gz" "$offline_mirror_dir/"*.pkg.tar.zst

		rm "$cache_dir/airootfs/etc/pacman.d/hooks/uncomment-mirrors.hook"
		
		# Comment out the [core] and [extra] repository sections to disable online repos
		# Otherwise they might interfere
		sed -i 's/^\[core\]/#\[core\]/' "$cache_dir/airootfs/etc/pacman.conf"
		sed -i '/^\[core\]/,/^Include = \/etc\/pacman\.d\/mirrorlist$/ s/^Include = \/etc\/pacman\.d\/mirrorlist$/#Include = \/etc\/pacman\.d\/mirrorlist/' "$cache_dir/airootfs/etc/pacman.conf"
		sed -i 's/^\[extra\]/#\[extra\]/' "$cache_dir/airootfs/etc/pacman.conf"
		sed -i '/^\[extra\]/,/^Include = \/etc\/pacman\.d\/mirrorlist$/ s/^Include = \/etc\/pacman\.d\/mirrorlist$/#Include = \/etc\/pacman\.d\/mirrorlist/' "$cache_dir/airootfs/etc/pacman.conf"
		
		# Add offline repository to pacman.conf so the installers can do
		# package lookups and installs
		cat >> "$cache_dir/airootfs/etc/pacman.conf" << EOF

		[offline]
		SigLevel = Optional TrustAll
		Server = file:///var/cache/omarchy/mirror/offline/
EOF
	fi
}

make_archiso_offline() {
	# This function will simply disable any online activity we have.
	# for instance the reflector.service which tries to optimize
	# mirror order by fetching the latest mirror list by default.
	#
	# We'll leave some things online, like NTP as that won't
	# interfere with anything, on the flip side it will help if we do
	# have internet connectivity.

	rm "$cache_dir/airootfs/etc/systemd/system/multi-user.target.wants/reflector.service"
	rm -rf "$cache_dir/airootfs/etc/systemd/system/reflector.service.d"
	rm -rf "$cache_dir/airootfs/etc/xdg/reflector"
}

mkdir -p $cache_dir/
mkdir -p $aur_mirror_dir/

# We base our ISO on the official arch ISO (releng) config
cp -r archiso/configs/releng/* $cache_dir/

mkdir -p $offline_mirror_dir/

# Change DownloadUser from alpm to root to fix permission issues when downloading to cache dir
# TODO: We should move the build root from /root/.cache/omarchy/ into /var/cache instead.
#       That way alpm:alpm will have access, which is the default pacman download user now days.
sed -i 's/^#*DownloadUser = alpm/DownloadUser = root/' /etc/pacman.conf

prepare_offline_mirror
make_archiso_offline

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

# We have to build the AUR packages one by one
# and place them in a local mirror for the ISO build process.
# Otherwise the ISO won't be able to source them
if [ ${#aur_packages[@]} -gt 0 ]; then
	for package in "${aur_packages[@]}"; do
		if build_aur "$package" "$aur_mirror_dir/"; then
			echo "$package" >> "$cache_dir/packages.x86_64"
		fi
	done

	ls -l "$aur_mirror_dir/"
	repo-add --new "$aur_mirror_dir/aur.db.tar.gz" "$aur_mirror_dir/"*.pkg.tar.zst

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

mkarchiso -v -w "$cache_dir/work/" -o "/out/" "$cache_dir/"