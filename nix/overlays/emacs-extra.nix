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


    # acp/emcp intentionally NOT in repoExtras: they live in
    # `localRecipes` below, sourced from submodules. This keeps the build
    # reproducible without a network fetch at activation time (the flake
    # URL has to capture submodules via `?submodules=1`, see AGENTS.md §6c).

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
  #
  # buffer-move: НЕ определяется здесь — `pkgs.emacsPackages.buffer-move` уже
  # доступен в nixpkgs 25.11. Раньше мы переопределяли его через
  # `emacsPackageFromRepository`, но в новых nixpkgs эта функция удалена,
  # и весь `localRecipes` падал. Берём апстрим-версию напрямую.
  localRecipes = {
    # visual-fill-column: upstream-рецепт в nixpkgs запинен на
    # codeberg.org/joostkremers/visual-fill-column@a38e3a28 — коммит
    # больше недоступен (HTTP 404), Nix по кругу перебирает NIX_MIRRORS_*.
    # Переопределяем source на GitHub-mirror (HEAD: 577fd2d, синхронизирован
    # с codeberg). Остальные attrs (meta, propagatedInputs, recipe) берём
    # из апстрима через overrideAttrs.
    visual-fill-column = super.emacsPackages.visual-fill-column.overrideAttrs (_: {
      src = super.fetchFromGitHub {
        owner = "joostkremers";
        repo = "visual-fill-column";
        rev = "577fd2d285f4830fd85b17c2ded74a91dba9d522";
        hash = "sha256-HG06pGehmxUDhDex639bG7rGkGrXCdNyzeWxPTbX9Nw=";
      };
    });
    pro-tabs = super.callPackage ../emacs-recipes/pro-tabs.nix {
      all-the-icons = super.emacsPackages.all-the-icons or null;
    };
    carriage = super.callPackage ../emacs-recipes/carriage.nix {
      gptel = super.emacsPackages.gptel or null;
    };
    telega = super.callPackage ../emacs-recipes/telega.nix {};
    agent-shell = super.callPackage ../emacs-recipes/agent-shell.nix {};
    agent-shell-hud = super.callPackage ../emacs-recipes/agent-shell-hud.nix {};
    acp = super.callPackage ../emacs-recipes/acp.nix {};
    emcp = super.callPackage ../emacs-recipes/emcp.nix {};
    # http-server.el lives on Codeberg (not MELPA/ELPA), so we provide it
    # via our own recipe. emcp declares `(require 'http-server)' and
    # propagates the dependency, so users get it transparently.
    http-server = super.callPackage ../emacs-recipes/http-server.nix {
      trivialBuild = super.emacsPackages.trivialBuild;
    };
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
