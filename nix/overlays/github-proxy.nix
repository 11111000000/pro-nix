/*
  Overlay: github-proxy

  Purpose: provide a lightweight, opt-in mechanism to route GitHub
  downloads through a proxy. Many networks (in particular the user's
  network) block GitHub "release assets" CDN (Fastly). This overlay
  allows prefixing GitHub URLs with a proxy (for example
  https://ghproxy.com/) by setting the environment variable
  NIX_GITHUB_PROXY. The overlay is intentionally small and conservative:
  it only rewrites URLs when a `url` attribute is present and starts
  with "https://github.com/".

  Usage:
    export NIX_GITHUB_PROXY="https://ghproxy.example.com/"
    nix build ...

  If NIX_GITHUB_PROXY is empty or unset, behaviour is unchanged.
*/

final: prev: let
  lib = final.lib;
  githubProxy = builtins.getEnv "NIX_GITHUB_PROXY";
in {
  # Use the `override` form so we preserve the fetchurl function's
  # extensibility (override/args) and avoid breaking other overlays that
  # expect fetchurl to support .override.
  fetchurl = prev.fetchurl.override (old: {
    rewriteURL = old.rewriteURL or (url: url);
  } // {
    # wrap rewriteURL to apply proxy prefix for GitHub release URLs
    rewriteURL = url:
      let
        base = (old.rewriteURL or (x: x)) url;
      in
      if githubProxy != "" && lib.strings.hasPrefix "https://github.com/" base then
        githubProxy + base
      else
        base;
  });
}
