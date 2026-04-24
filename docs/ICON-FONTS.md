Installing icon fonts for pro-nix Emacs
=====================================

This project uses icon fonts (Nerd Fonts / all-the-icons) to render icons in
the minibuffer, dired and completion UIs. On NixOS / Home-Manager you should
install fonts declaratively via your Home-Manager configuration.

Home-Manager (example):

  fonts.fonts = with pkgs; [
    (pkgs.fetchFromGitHub {
      owner = "ryanoasis";
      repo = "nerd-fonts";
      rev = "v2.1.0"; # example
      sha256 = "000..."; # fill appropriately or use builtins.fetchTarball
    })
  ];

Alternatively, install `nerd-fonts` or specific patched fonts (FiraCode Nerd
Font, Hack Nerd Font) via your system packages or by placing them in
~/.local/share/fonts and running `fc-cache -f`.

If you prefer `all-the-icons`, run `M-x all-the-icons-install-fonts` once and
follow the prompts (requires font installation with root/GUI access).

After installing fonts, run M-x pro-ui-check-icon-fonts to validate.
