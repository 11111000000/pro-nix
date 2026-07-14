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
  #
  # IMPORTANT: alphabetic-order evaluation в attrset literal означает, что
  # атрибут `ellama` (имя начинается с 'e') оценивается раньше `llm` ('l').
  # Это проблема: если ellama recipe берёт `super.emacsPackages.llm`,
  # получит upstream `emacs-llm-0.27.2` (у которого архив удалён с ELPA).
  # Решение: патчим upstream llm до того, как ellama recipe оцéнивается,
  # через `let binding` — patched llm фиксируется до `localRecipes`.
  patchedLlm = super.callPackage ../emacs-recipes/llm.nix {};
  # transient: nixpkgs 25.11-рецепт `emacsPackages.transient` собирает
  # коммит `053d56e4` (2025-10-06), в котором `transient-version` всё ещё
  # `"0.10.1"` — между v0.11.0 и v0.13.5 Magit поднял требование до
  # `>= 0.13`, и эта сборка уже несовместима. Берём официальный тег v0.13.5
  # через собственный recipe (см. nix/emacs-recipes/transient.nix).
  # Alphabetic-order gotcha (см. ниже про ellama): если transient
  # переопределяется только внутри `localRecipes` (имя 't' после 's'),
  # то recipe ellama успеет подхватить наш patched — но ради симметрии
  # с `patchedLlm` фиксируем через let binding.
  patchedTransient = super.callPackage ../emacs-recipes/transient.nix {
    # `trivialBuild` живёт в `super.emacsPackages.*`, не в `pkgs.*`.
    # emacsPackages (`compat`, `cond-let`, `llama`, `seq`) тоже не в `pkgs.*`.
    # `callPackage` не находит их по имени автоматически — пробрасываем явно.
    trivialBuild = super.emacsPackages.trivialBuild;
    compat = super.emacsPackages.compat;
    cond-let = super.emacsPackages.cond-let;
    llama = super.emacsPackages.llama;
    seq = super.emacsPackages.seq;
  };
  # compat: nixpkgs 25.11-рецепт `emacsPackages.compat` запинен на
  # tag 30.1.0.1 (Jun 2025), а `transient-0.13.5` требует `compat >= 31.0`.
  # Делаем собственный recipe поверх официального 31.0.0.2
  # (emacs-compat/compat@df03e91, 2026-07-09) — прямой `mkDerivation`
  # + `fetchFromGitHub`, без elpa2nix.
  patchedCompat = super.callPackage ../emacs-recipes/compat.nix {
    trivialBuild = super.emacsPackages.trivialBuild;
  };
  # transient требует на вход именно наш patchedCompat (а не upstream
  # `super.emacsPackages.compat`). Передаём его явно через callPackage
  # override — не полагаемся на alphabetic-order в `localRecipes`.
  patchedTransientPatchedCompat = super.callPackage ../emacs-recipes/transient.nix {
    trivialBuild = super.emacsPackages.trivialBuild;
    compat = patchedCompat;
    cond-let = super.emacsPackages.cond-let;
    llama = super.emacsPackages.llama;
    seq = super.emacsPackages.seq;
  };
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
    # llm: см. nix/emacs-recipes/llm.nix. Upstream nixpkgs-рецепт
    # запинен на ELPA tarball `llm-0.27.2.tar`, который удалён с зеркал.
    # Используем собственный recipe: `fetchFromGitHub` + `mkDerivation`,
    # минуя elpa2nix (для которого нужен standard ELPA-style tar).
    # Привязка через `let patchedLlm` (выше) гарантирует, что alphabetic-order
    # eval этого attrset не подменит наш patched llm на upstream broken.
llm = patchedLlm;
    # transient: см. nix/emacs-recipes/transient.nix. Перебиваем
    # `super.emacsPackages.transient` (0.10.1) нашим tagged v0.13.5.
    # Magit читает `transient-version` и при `>= 0.10.1 < 0.13` падает
    # с emergency "Magit requires 'transient' >= 0.13".
    transient = patchedTransientPatchedCompat;
    # compat: см. nix/emacs-recipes/compat.nix. Подменяем
    # `super.emacsPackages.compat` (30.1.0.1) на 31.0.0.2 — это нужно
    # для байт-компиляции `transient-0.13.5` (требует compat >= 31.0),
    # и для всех прочих пакетов, которые зависят от свежего compat.
    compat = patchedCompat;
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
    http-server = super.callPackage ../emacs-recipes/http-server.nix {};
    acapella = super.callPackage ../emacs-recipes/acapella.nix {};
    atlas = super.callPackage ../emacs-recipes/atlas.nix {};
    tao-theme = super.callPackage ../emacs-recipes/tao-theme.nix {};
    shaoline = super.callPackage ../emacs-recipes/shaoline.nix {};
    shaoline-package = super.emacsPackages.shaoline;
    shell-maker = super.callPackage ../emacs-recipes/shell-maker.nix {};
    # Ellama — Emacs client for local + cloud LLMs. AGENTS.md-aware, has
    # sessions, DLP, skills, blueprints, plan-and-act. Pinned to a commit
    # upstream of GNU ELPA so we get the agentic-coding profile faster.
    #
    # `emacsPackages` передаётся явно: alphabetic-order evaluation в
    # `localRecipes` означает, что `ellama` оценивается до `llm`, и если
    # recipe использует `emacs.pkgs.llm` (т.е. `super.emacsPackages.llm`),
    # получит upstream broken `emacs-llm-0.27.2`, не наш patched.
    ellama = super.callPackage ../emacs-recipes/ellama.nix {
      emacsPackages = super.emacsPackages // { inherit (super.emacsPackages) plz yaml; } // { llm = patchedLlm; transient = patchedTransientPatchedCompat; compat = patchedCompat; };
      emacsPackages_llm = patchedLlm;
      emacsPackages_plz = super.emacsPackages.plz;
      emacsPackages_transient = patchedTransientPatchedCompat;
      emacsPackages_compat = patchedCompat;
      emacsPackages_yaml = super.emacsPackages.yaml;
      # plz-event-source и plz-media-type — отдельные emacsPackage
      # (транзитивные deps `plz`). ellama-transient.el требует
      # `plz-event-source`, ellama-eval.el требует `plz-media-type`.
      emacsPackages_plz_event_source = super.emacsPackages.plz-event-source or null;
      emacsPackages_plz_media_type = super.emacsPackages.plz-media-type or null;
      # cond-let и llama — транзитивные deps `transient` (через
      # `(require 'cond-let)` / `(require 'llama)` в transient.el).
      # ellama recipe использует простой `mkDerivation` без
      # `addEmacsNativeLoadPath`, поэтому propagated через transient
      # не доходят — пробрасываем явно.
      emacsPackages_cond_let = super.emacsPackages.cond-let;
      emacsPackages_llama = super.emacsPackages.llama;
    };
  };
in {
  emacsPackages = super.emacsPackages // repoExtras // localRecipes;
  # telega-server: a CLI binary used by telega.el as a TDLib JSON bridge.
  # Exposed as a regular package (not under emacsPackages) so that
  # `home.packages` can include it. The elisp side references it via PATH.
  telega-server = super.callPackage ../emacs-recipes/telega-server.nix {};
}
