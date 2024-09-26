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

For documentation on how to configure and use `cart` please refer to [the documentation](./docs/main.md)

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
  - [ ] repository verification (detect MITM -- i.e. something like GPG key verification?)
- [ ] Nix-Darwin module
