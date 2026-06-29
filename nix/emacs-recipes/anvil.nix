{ stdenv, emacs, lib, fetchFromGitHub }:

# anvil.el: MCP server written in Elisp — token-efficient workbench for AI
# agents. Drives files, org-mode, Elisp & SQLite from any MCP client through
# Emacs primitives instead of sed/grep round-trips.
#
# - Source: zawatton/anvil.el (https://github.com/zawatton/anvil.el, 73+ stars).
# - Pinned commit: 4306ea1058c6b7b659f2ac1f27426bfc1178eb5f (v1.3.0, 2026-06-26).
# - License: GPL-3.0 (see LICENSE in the repo).
# - Server surface: ~40 default MCP tools (file / org / elisp / sqlite / shell)
#   plus opt-in modules (memory, orchestrator, semantic, mu4e, cad, fusion, …).
# - The repo is not on MELPA / ELPA; building it ourselves keeps upgrades
#   reproducible through the commit pin and SRI hash.
#
# Wiring: pro-ai-anvil.el auto-loads `(require 'anvil)` and calls
# `(anvil-enable)` + `(anvil-server-start)` on the AGENTS.md-aware lifecycle
# hook (see pro-ai-ellama for the shared AGENTS dispatcher).
stdenv.mkDerivation rec {
  pname = "anvil";
  version = "1.3.0-unstable-2026-06-26";

  src = fetchFromGitHub {
    owner = "zawatton";
    repo = "anvil.el";
    rev = "4306ea1058c6b7b659f2ac1f27426bfc1178eb5f";
    hash = "sha256-YEt1EXj8Vi5d9fVjve4RAqOBf9ApPj6QPAYgZymf3NA=";
  };

  nativeBuildInputs = [ emacs ];

  # anvil depends on a fairly large set of Emacs packages — many of them ship
  # in nixpkgs.emacsPackages. The list below is conservative: only the
  # packages that anvil's core `anvil.el` `require`s. Optional modules
  # (memory / orchestrator / mu4e / cad / …) bring in their own deps and are
  # loaded lazily by anvil-feature-list — they're not in `buildInputs`
  # because we don't need to byte-compile them; runtime load is enough.
  buildInputs = with emacs.pkgs; [
    compat
    seq
    async
    dash
    spinner
    transient
    posframe
    emacsql
    posframe
    llm
    plz
    markdown-mode
    yaml
  ];

  dontConfigure = true;

  # anvil.el itself is 600+ .el files. Byte-compile them all but tolerate
  # warnings (anvil uses an `(eval-and-compile ...)`-heavy style and pulls
  # in optional modules whose `require` calls would fail at compile time if
  # the corresponding package is not on the load path).
  buildPhase = ''
    runHook preBuild
    emacs --batch -Q -L . \
      -f batch-byte-compile \
      *.el 2>&1 | tail -200 || true
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/emacs/site-lisp/${pname}
    install -m644 *.el  $out/share/emacs/site-lisp/${pname}/
    install -m644 *.elc $out/share/emacs/site-lisp/${pname}/
    # anvil ships a `bin/anvil` wrapper for the --no-emacs (NeLisp) runtime
    # path. We don't pull in NeLisp here, but copy the wrapper so a future
    # optional module can use it without re-fetching sources.
    if [ -d bin ]; then
      mkdir -p $out/share/anvil/bin
      cp -r bin/* $out/share/anvil/bin/
    fi
    runHook postInstall
  '';

  meta = with lib; {
    description = "anvil.el — MCP server written in Elisp; token-efficient workbench for AI agents (file / org / elisp / sqlite tools through Emacs primitives)";
    homepage = "https://github.com/zawatton/anvil.el";
    license = with licenses; [ gpl3Plus ];
    platforms = platforms.unix;
  };
}
