# Omarchy ISO

The Omarchy ISO is intended to provide a completely offline-capable installation of Omarchy. It therefore includes packages for everything that the Omarchy web installer requires. It also uses a custom front-end for archinstall that lives in the https://github.com/omacom-io/omarchy-installer repository, which is cloned at ISO build time. (It's kept seperate so it's easier to work on for folks who don't need to know everything about arch ISO building.)

## Creating the ISO

Run `./bin/omarchy-iso-make` and the output goes into `./out`.

## Testing the ISO

Run `./bin/omarchy-iso-boot [out/name.iso]`.

## Signing the ISO

```
$ gpg --local-user [GPG Key ID] \
  --output ./out/*.iso.sig \
  --detach-sig ./out/*.iso
```
