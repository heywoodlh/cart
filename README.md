# Cart package manager

Cart is an unprivileged MacOS package manager that uses built-in MacOS utilities for installing packages.

# Usage

For documentation on installation, configuration and usage of `cart` please refer to [the documentation](./docs/README.md)

## Planned features

- [x] Ability to install .dmg files from URLs
  - [ ] Ability to symlink executables within dmg
- [x] Hash verification of files
- [x] Subcommands
  - [x] add
  - [x] del
  - [x] clean
- [x] Track state of apps (i.e. what's currently installed)
  - [x] app name
  - [x] app source url
  - [x] app url hash
  - [x] repo files should match the same format
- [ ] Symlink executables to ~/bin
- [x] Support archive formats handled by built-in macOS tools
  - [x] Zip files
  - [x] Tar archives (including `.tar.xz`)
  - [ ] Pkg files
  - [ ] Executables?
- [x] Configuration file `$HOME/Library/Application Support/cart/cart.config`
- [ ] Repository list support (i.e. remote webserver/file with lists of apps)
  - [ ] github release helper
  - [ ] repo subcommand
    - [ ] add
    - [ ] del
    - [ ] update
  - [ ] repository verification (detect MITM -- i.e. something like GPG key verification?)
- [x] Nix-Darwin module

## Main branch and release-tag mirroring

`main` and all tag refs are mirrored bidirectionally between GitHub and Tangled:

- GitHub Actions pushes GitHub `main` and tags to
  `git@tangled.org:heywoodlh.io/cart`.
  Configure the repository Actions secret `TANGLED_SSH_PRIVATE_KEY` with a
  write-capable key registered on Tangled.
- Tangled Spindle pushes Tangled `main` and tags to GitHub. Configure its `GITHUB_TOKEN`
  secret as a fine-grained GitHub token with **Contents: read and write** access
  to `heywoodlh/cart`.

Both workflows use normal, non-force Git pushes. A moved tag or divergent
`main` history is rejected and must be reconciled manually before mirroring can
resume. Ref deletion is intentionally not mirrored.
