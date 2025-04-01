{ config, pkgs, lib, ... }:

with lib;
let
  cfg = config.cart;
in {
  options.cart = {
    enable = mkOption {
      default = false;
      description = ''
        Enable cart package manager.
      '';
      type = types.bool;
    };
    package = mkOption {
      default = null;
      description = ''
        The cart package to install.
      '';
      type = types.package;
    };
    user = mkOption {
      default = "root";
      description = ''
        User to install packages for.
      '';
      type = types.string;
    };
    applications = mkOption {
      default = [];
      description = ''
        List of packages to install.
      '';
      type = with types; listOf (attrsOf str);
      example = literalExpression ''
        [
          {
            url = "https://github.com/utmapp/UTM/releases/download/v4.6.4/UTM.dmg";
            hash = "aad86726152b15a3e963cf778a0b0dfd8e818736b381aed2699d974a18845427";
          }
        ]
      '';
    };
    config = mkOption {
      default = ''
        downloads="/tmp/cart/downloads"
        mountpoints="/tmp/cart/mountpoints"
        local_file="false"
        apps_folder="/Users/${cfg.user}/Applications"
        cart_dir="/Users/${cfg.user}/Library/Application Support/cart"
        cart_debug="true"
      '';
      type = types.string;
    };
  };
  config = let
    configFile = pkgs.writeText "cart-config" cfg.config;
    script = ''
      set -ex
      ${concatStringsSep "\n" (map (p: "/usr/bin/sudo -u ${cfg.user} -E CART_CONFIG=${configFile} ${cfg.package}/bin/cart add ${p.url} ${p.hash}") cfg.applications)}
    '';
    cartInstall = pkgs.writeShellScriptBin "cart-install" script;
  in mkIf cfg.enable {
    environment.systemPackages = [ cartInstall cfg.package ];
    system.activationScripts.postActivation = {
      enable = true;
      text = script;
    };
  };
}
