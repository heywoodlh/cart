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

# Overview

Cart expects an argument for a URL to a DMG file, for example:

```
cart add https://github.com/utmapp/UTM/releases/download/v4.5.4/UTM.dmg
```

Alternatively, a local filesystem path can be provided:

```
cart add ~/Downloads/UTM.dmg
```

Optionally, provide a SHA256 sum for the downloaded DMG file:

```
cart add https://github.com/utmapp/UTM/releases/download/v4.5.4/UTM.dmg 1b3c2890afeaf12dfc95b39584680d6aa6c3000af21c9f5e0400161a9b8e40e1
```

If you provide an invalid hash, `cart` will print the correct hash for the file.

To uninstall an application, use `cart list` and `cart del`:

```
cart list
cart del <name>
```

If you invoke `cart` as root (i.e. via `sudo`), `cart` will install applications to `/Applications` and use the root user's `$HOME` (`/var/root` by default) for operations.
