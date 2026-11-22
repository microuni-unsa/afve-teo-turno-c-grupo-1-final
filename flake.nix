{
  description = "A flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      nixpkgs,
      nixpkgs-unstable,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
        unstable = import nixpkgs-unstable {
          inherit system;
          config.allowUnfree = true;
        };
      in
      {
        devShells.default = pkgs.mkShell {
          packages = pkgs.lib.flatten [
            (with pkgs; [
              dafny
              bun
              nodejs
              uppaal
            ])
            (with unstable; [
              typst
              typstyle
            ])
          ];
          shellHook = ''
            unset SOURCE_DATE_EPOCH
          '';
          buildInputs = [ pkgs.bashInteractive ];
        };
      }
    );
}
