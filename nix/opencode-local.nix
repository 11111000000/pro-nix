{ pkgs ? import <nixpkgs> {} }:

# Local wrapper that imports a development copy of OpenCode from
# ~/Code/opencode if present. This is intentionally easy to override in
# local developer environments: it calls the upstream nix expression
# shipped in the opencode repository and lets that expression drive the
# build.

let
  localPath = "/home/az/Code/opencode";
in

if builtins.pathExists localPath then
  pkgs.callPackage (localPath + "/nix/opencode.nix") {}
else
  # When not present, evaluate to null so callers can fall back.
  null
