self: super:
let
  haveRepoFunc = builtins.hasAttr "emacsPackageFromRepository" (super.emacsPackages or {});
  repoExtras = if haveRepoFunc then {
    embark = super.emacsPackages.emacsPackageFromRepository {
      pname = "embark";
      repository = "oantolin/embark";
      revision = "v0.20";
    };

    embark-consult = super.emacsPackages.emacsPackageFromRepository {
      pname = "embark-consult";
      repository = "oantolin/embark-consult";
      revision = "v0.9";
    };

    eldoc-box = super.emacsPackages.emacsPackageFromRepository {
      pname = "eldoc-box";
      repository = "vitalie/eldoc-box";
      revision = "v0.3.0";
    };


    acp = super.emacsPackages.emacsPackageFromRepository {
      pname = "acp";
      repository = "xenodium/acp.el";
      revision = "master";
    };

    # golden-ratio: pin roman/golden-ratio.el@v0.8 заменён на
    # `super.emacsPackages.golden-ratio` (тот же derivation в nixpkgs 25.11,
    # но без нашего pin на конкретный tag, который периодически не резолвится
    # через git fetcher). Это эквивалентная пересборка, но без нашего
    # внешнего pin'а.
    golden-ratio = super.emacsPackages.golden-ratio;
  } else {};

  # Local recipes — always applied
  # Все sources идут из submodules/ — единый источник истины.
  # helper-switch.sh автоматически подтягивает свежий main/master перед сборкой.
  localRecipes = {
    buffer-move = super.emacsPackages.emacsPackageFromRepository {
      pname = "buffer-move";
      repository = "lukhas/buffer-move";
      revision = "master";
      version = "0.6.2";
    };
    pro-tabs = super.callPackage ../emacs-recipes/pro-tabs.nix {
      all-the-icons = super.emacsPackages.all-the-icons or null;
    };
    carriage = super.callPackage ../emacs-recipes/carriage.nix {
      gptel = super.emacsPackages.gptel or null;
    };
    telega = super.callPackage ../emacs-recipes/telega.nix {};
    agent-shell = super.callPackage ../emacs-recipes/agent-shell.nix {};
    agent-shell-hud = super.callPackage ../emacs-recipes/agent-shell-hud.nix {};
    acapella = super.callPackage ../emacs-recipes/acapella.nix {};
    atlas = super.callPackage ../emacs-recipes/atlas.nix {};
    tao-theme = super.callPackage ../emacs-recipes/tao-theme.nix {};
    shaoline = super.callPackage ../emacs-recipes/shaoline.nix {};
    shaoline-package = super.emacsPackages.shaoline;
  };
in {
  emacsPackages = super.emacsPackages // repoExtras // localRecipes;
  # telega-server: a CLI binary used by telega.el as a TDLib JSON bridge.
  # Exposed as a regular package (not under emacsPackages) so that
  # `home.packages` can include it. The elisp side references it via PATH.
  telega-server = super.callPackage ../emacs-recipes/telega-server.nix {};
}
