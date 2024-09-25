# Cart package manager

Cart is an unprivileged MacOS package manager that uses built-in MacOS utilities for installing packages.

# Installation

```
mkdir -p ~/bin
curl -L 'https://raw.githubusercontent.com/heywoodlh/cart/refs/heads/main/cart' -o ~/bin/cart
chmod +x ~/bin/cart
export PATH="$HOME/bin:$PATH"
```

To ensure ability to use `cart` executable between shell sessions, add the following to your shell's configuration file:

```
export PATH="$HOME/bin:$PATH"
```

# Usage

Cart expects an argument for a URL to a DMG file, for example:

```
cart https://github.com/utmapp/UTM/releases/download/v4.5.4/UTM.dmg
```

Alternatively, a local filesystem path can be provided:

```
cart ~/Downloads/UTM.dmg
```

Optionally, provide a SHA256 sum for the downloaded DMG file:

```
cart https://github.com/utmapp/UTM/releases/download/v4.5.4/UTM.dmg 1b3c2890afeaf12dfc95b39584680d6aa6c3000af21c9f5e0400161a9b8e40e1
```

If you provide an invalid hash, `cart` will print the correct hash for the file.

To uninstall an application, simply remove it from your `~/Applications` folder:

```
ls ~/Applications
rm -rf ~/Applications/myapp.app
```

If you run `cart` as root (i.e. via `sudo`), `cart` will install applications to `/Applications`.

## Planned features

- [x] Ability to install .dmg files from URLs
  - [ ] Ability to symlink executables within dmg
- [x] Hash verification of files
- [ ] Subcommands
  - [ ] add
  - [ ] del
  - [ ] clean
- [ ] Track state of apps (i.e. what's currently installed)
  - [ ] app name
  - [ ] app source url
  - [ ] app url hash
  - [ ] repo files should match the same format
- [ ] Symlink executables to ~/bin
- [ ] Support other formats
  - [ ] Zip files
  - [ ] Pkg files
  - [ ] Executables?
- [ ] Configuration file `$HOME/Library/Application Support/cart/config.yaml`
- [ ] Repository list support (i.e. remote webserver/file with lists of apps)
  - [ ] github release helper
  - [ ] repo subcommand
    - [ ] add
    - [ ] del
    - [ ] update
- [ ] Nix-Darwin module
