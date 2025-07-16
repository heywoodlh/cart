{
  description = "cart flake";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  inputs.nix-darwin = {
    inputs.nixpkgs.follows = "nixpkgs";
  };
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = inputs @ {
    self,
    nixpkgs,
    flake-utils,
    nix-darwin,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
      lib = pkgs.lib;
      stdenv = pkgs.stdenv;
      cartpkg = stdenv.mkDerivation {
        name = "cart";
        builder = pkgs.bash;
        args = [ "-c" "${pkgs.coreutils}/bin/mkdir -p $out/bin && ${pkgs.coreutils}/bin/cp ${self}/cart $out/bin/cart" ];
      };
    in {
      packages = rec {
        cart = cartpkg;
        default = cart;
      };
      devShell = pkgs.mkShell {
        name = "nixos-configs devShell";
        buildInputs = with pkgs; [
          cartpkg
          lefthook
          gitleaks
          cartpkg
          jq
        ];
        shellHook = ''
          lefthook install
        '';
      };
    }
  );
}
