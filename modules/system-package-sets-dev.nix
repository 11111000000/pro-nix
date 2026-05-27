{ pkgs, ... }:

with pkgs;

let
  # Reproducible Python environment for ML/LLM research
  llmResearchEnv = pkgs.python3.withPackages (ps: with ps; [
    jupyterlab
    ipykernel
    transformers
    datasets
    sentencepiece
    tokenizers
    numpy
    pandas
    matplotlib
    scipy
    plotly
    seaborn
  ]);

  llmLabCmd = pkgs.writeShellScriptBin "llm-lab" ''
    export JUPYTER_PATH="${llmResearchEnv}/share/jupyter"
    exec ${llmResearchEnv}/bin/jupyter-lab "$@"
  '';

  # Consistent Python wrappers pointing to the same interpreter
  myPython = pkgs.python3.withPackages (ps: [ ps.requests ps.pip ]);

  pythonCmd = writeShellScriptBin "python" ''
    exec ${myPython}/bin/python3 "$@"
  '';
  python3Cmd = writeShellScriptBin "python3" ''
    exec ${myPython}/bin/python3 "$@"
  '';
in
{
  devPackages = [
    git
    curl
    wget
    jq
    just
    shellcheck
    shfmt
    ripgrep
    fd
    findutils
    direnv
    diffutils
    bat
    tldr
    nodejs_20
    esbuild
    nodePackages.prettier
    nodePackages.typescript-language-server
    nodePackages.typescript
    pkgs.tree-sitter
    cmake
    gcc
    clang
    binutils
    gnumake
    pkg-config
    ncurses
    libtool
    automake
    autoconf
    fzf
    lnav
    gnugrep
    llmLabCmd
    pythonCmd
    python3Cmd
  ];
}
