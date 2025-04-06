---

## 0.1.0

- Converted applist.txt to JSON `applist.json` (fixes [#1](https://github.com/heywoodlh/cart/issues/1)):
  - Parses JSON
- Automatically install Apple's Command Line tools if not detected
- Added `--all` and `--json` flags to `list` subcommand

## 0.0.4

- Added Nix-Darwin module, minimal example
- Added support for `$CART_CONFIG` environment variable
- Added logic to reliably source configuration file
- Quiet by default, use `cart_debug=true` for output
- Fixed bug that would crash `cart` if archive file was already downloaded but the package was not yet installed (i.e. if installation was interrupted and archive file not cleaned up)

## 0.0.3

- Refactored sections into functions for better organization/modularity
- Support config file
- Subcommands: add, del, list
- Nix flake package
- Support zip files containing .app directories

## 0.0.2

- Allow installing dmg's from local filesystem
- Print help if anything aside from URL/local file is provided as an argument
- Support system-wide installations if invoked as root

## 0.0.1

Initial functionality:
- Basic docs
- Ability to install dmg files from URLs
- Hash verification
