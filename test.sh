#!/usr/bin/env zsh
mkdir -p /tmp/cart-test
cat >/tmp/cart.config <<EOL
downloads="/tmp/cart-test/downloads"
mountpoints="/tmp/cart-test/mountpoints"
local_file="false"
apps_folder="/tmp/cart-test/Applications"
cart_dir="/tmp/cart-test"
EOL

export cart_debug="true"
export CART_CONFIG=/tmp/cart.config

# DMG test
./cart add https://github.com/utmapp/UTM/releases/download/v4.5.4/UTM.dmg 1b3c2890afeaf12dfc95b39584680d6aa6c3000af21c9f5e0400161a9b8e40e1
./cart list | grep -i UTM
# Fail if app doesn't exist
[[ -e /tmp/cart-test/Applications/UTM.app ]] || exit 20
./cart del UTM
# Fail if app does exist
[[ ! -e /tmp/cart-test/Applications/UTM.app ]] || exit 21

# Zip test
./cart add https://iterm2.com/downloads/stable/iTerm2-3_5_5.zip
./cart list | grep -i iTerm
# Fail if app doesn't exist
[[ -e /tmp/cart-test/Applications/iTerm.app ]] || exit 20
./cart del iTerm
# Fail if app does exist
[[ ! -e /tmp/cart-test/Applications/iTerm.app ]] || exit 21

# App with spaces test
./cart add https://github.com/podman-desktop/podman-desktop/releases/download/v1.19.2/podman-desktop-1.19.2-arm64.dmg 7208c4c29124bd7ec97c153a9f6ad670ff2b09e72435a373d98d9c1bcd3b3f94
./cart list | grep -i "Podman Desktop"
# Fail if app doesn't exist
[[ -e "/tmp/cart-test/Applications/Podman Desktop.app" ]] || exit 20
./cart del "Podman Desktop"
# Fail if app does exist
[[ ! -e "/tmp/cart-test/Applications/Podman Desktop.app" ]] || exit 21

# Test if jq installation works, if overridding CART_CONFIG works
printf jq_force_install="true" >> /tmp/cart.config
./cart add https://iterm2.com/downloads/stable/iTerm2-3_5_5.zip
# Test if jq binary was installed
[[ -e /tmp/cart-test/bin/jq ]] || exit 22
./cart del iTerm
rm -rf /tmp/cart-test /tmp/cart.config
