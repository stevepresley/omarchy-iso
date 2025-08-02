# omarchy-iso

This will create an ISO that does two things:

1. Auto-boot into Live Arch Linux (without prompt)
2. Will auto-launch `omarchy-tui`

# Build instructions

First, get the submodules (archiso):
```
$ git submodule update --remote --merge
```

Then build the ISO in a docker container using the arch image as the foundation:

```
$ docker run --rm \
	--privileged \
	-v "./out/:/out/" \
	-v "./build_iso.sh:/build_iso.sh:ro" \
	-v "./archiso:/archiso:ro" \
	-v "./grub-autoboot.patch:/grub-autoboot.patch:ro" \
	-v "./efi-autoboot.patch:/efi-autoboot.patch:ro" \
	-v "./permissions.patch:/permissions.patch:ro" \
	-v "./aur-mirror.patch:/aur-mirror.patch:ro" \
	-v "./check_connectivity.sh:/check_connectivity.sh:ro" \
	archlinux/archlinux:latest /build_iso.sh
```

Finished result should be in `./out`.
Note that `--privileged` is used. The main reason being `mkarchiso` mounts `/sys/proc` and other locations, which requires privileged permissions.

# Signing

```
$ gpg --local-user 0xD4B58E897A929F2E \
  --output ./out/*.iso.sig \
  --detach-sig ./out/*.iso
```

Note that `gpg --list-keys --fingerprint --keyid-format 0xLONG torxed@archlinux.org` can give you your GPG Key ID. In my case `ed25519/0xD4B58E897A929F2E`.