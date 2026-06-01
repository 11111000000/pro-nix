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

    telega = super.emacsPackages.emacsPackageFromRepository {
      pname = "telega";
      repository = "zevlg/telega.el";
      revision = "v1.6";
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

    golden-ratio = super.emacsPackages.emacsPackageFromRepository {
      pname = "golden-ratio";
      repository = "roman/golden-ratio.el";
      revision = "v0.8";
    };
  } else {};

  # Local recipes — always applied
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
    agent-shell = super.callPackage ../emacs-recipes/agent-shell.nix {};
    acapella = super.callPackage ../emacs-recipes/acapella.nix {};
    atlas = super.callPackage ../emacs-recipes/atlas.nix {};
    tao-theme-emacs = super.callPackage ../emacs-recipes/tao-theme-emacs.nix {};
    tao-theme = super.emacsPackages.tao-theme-emacs;
  };
in {
  emacsPackages = super.emacsPackages // repoExtras // localRecipes;
}
