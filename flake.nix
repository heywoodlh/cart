{
  description = "cart dev shell";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  inputs.nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-24.05";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = inputs @ {
    self,
    nixpkgs,
    nixpkgs-stable,
    flake-utils,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
      stable-pkgs = nixpkgs-stable.legacyPackages.${system};
      cart = pkgs.writeShellScriptBin "cart" ''
        ${self}/cart $@
      '';
    in {
      devShell = pkgs.mkShell {
        name = "nixos-configs devShell";
        buildInputs = with pkgs; [
          lefthook
          stable-pkgs.gitleaks # bug in pkgs.gitleaks currently
          cart
        ];
        shellHook = ''
          lefthook install
        '';
      };
    }
  );
}
