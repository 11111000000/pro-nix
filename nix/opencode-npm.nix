{ pkgs ? import <nixpkgs> {} }:

# Reproducible derivation that uses upstream nix expression when possible.
# This file imports the upstream `nix/opencode.nix` from the official repo
# tarball and lets the upstream expression drive the build. The fetch sha256
# is locked to the upstream archive used during local development.

let
  src = pkgs.fetchFromGitHub {
    owner = "anomalyco";
    repo = "opencode";
    rev = "v1.14.19";
    sha256 = "1ynrrikp6qjwqrh57pcw69i5h92ikz96d6zyd5j5vyd5zwqnm8ch";
  };
in

pkgs.callPackage (src + "/nix/opencode.nix") {}
