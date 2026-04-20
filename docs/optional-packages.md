# Optional heavy packages

This repository now treats the heaviest GUI and tooling packages as optional. By default they are disabled to keep `nixos-rebuild` and `nix build` lightweight.

How it works

- `system-packages.nix` accepts an argument `enableOptional` (default false).
- When `enableOptional = true` the following packages are added to `environment.systemPackages`:

- chromium
- firefox
- tor-browser
- telegram-desktop
- element-desktop
- jami
- ffmpeg-full
- deluge
- haskellPackages.haskell-language-server
- ollama

Enable optional packages (system-wide)

Edit `configuration.nix` (or your host-specific imported file) and set the import to pass `enableOptional = true`:

```nix
environment.systemPackages = with pkgs; [ just jq ] ++ (import ./system-packages.nix { inherit pkgs emacsPkg; enableOptional = true; });
```

Then rebuild:

```bash
sudo nixos-rebuild switch --flake .#your-host
```

Enable optional packages (per-user via home-manager)

You can avoid system-wide rebuild by installing individual packages in your Home Manager profile or by using `nix profile install`.

Example (Home Manager):

```nix
home.packages = with pkgs; [ pkgs.chromium pkgs.firefox ];
```

Example (imperative):

```bash
nix profile install nixpkgs#firefox
```

Notes

- Secrets and provider keys remain outside Nix and are unaffected by this change.
- Optional packages are intended to reduce CI and developer machine build time.
