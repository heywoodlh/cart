## Cart Documentation

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

## Installation with Nix

Run the following to install `cart` via Nix flake on MacOS:

```
nix profile install "github:heywoodlh/cart"
```

# Installing packages

Cart's `add` subcommand expects an argument containing a URL to a DMG file, or Zip file containing a .app, for example:

```
cart add https://github.com/utmapp/UTM/releases/download/v4.5.4/UTM.dmg
```

Alternatively, a local filesystem path can be provided:

```
cart add ~/Downloads/UTM.dmg
```

# Verifying downloaded files

Optionally, provide a SHA256 sum for the downloaded (or local) file:

```
cart add https://github.com/utmapp/UTM/releases/download/v4.5.4/UTM.dmg 1b3c2890afeaf12dfc95b39584680d6aa6c3000af21c9f5e0400161a9b8e40e1
```

To initially get a hash via TOFU (Trust on First Use), provide an invalid hash to `cart`. If you provide an invalid hash, `cart` will print the correct hash for the file and then exit, for example:

```
❯ cart add https://github.com/utmapp/UTM/releases/download/v4.5.4/UTM.dmg somehash
...
Incorrect file hash provided.
/tmp/cart/downloads/UTM.dmg hash: 1b3c2890afeaf12dfc95b39584680d6aa6c3000af21c9f5e0400161a9b8e40e1
Exiting.⏎
```

Re-run the `cart add` command using the correct hash.

## Obtaining a hash manually

If you don't want to use `cart`'s builtin hash printing capability, here is an example snippet to manually grab a hash for an app:

```
curl -L https://github.com/utmapp/UTM/releases/download/v4.5.4/UTM.dmg -o ~/Downloads/UTM.dmg
shasum -a 256 ~/Downloads/UTM.dmg | awk '{print $1}'
```

# Uninstalling packages

To uninstall an application, use `cart list` and `cart del`:

```
cart list
cart del <name>
```

If you invoke `cart` as root (i.e. via `sudo`), `cart` will install applications to `/Applications` and use the root user's `$HOME` (`/var/root` by default) for operations.

# Configuration

Cart can read a configuration file containing variables to override. A config file with all possible configuration variables is available in the root of this repository: [cart.config](../cart.config)

The configuration file is a file containing shell variables. Therefore, any valid ZSH variable value should function. The `cart.config` file can be placed in the following locations (prioritized in this order, will stop on first file that exists in this list):

- `./cart.config`
- `$HOME/Library/Application Support/cart/cart.config`
- `~/.config/cart/cart.config`
