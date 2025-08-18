# omarchy-iso

This will create an ISO that does two things:

1. Auto-boot into Live Arch Linux (without prompt)
2. Will auto-launch `omarchy-installer`

# Build instructions

Run `./bin/omarchy-iso-make` and the output goes into `./out`.

# Signing

```
$ gpg --local-user [GPG Key ID] \
  --output ./out/*.iso.sig \
  --detach-sig ./out/*.iso
```
