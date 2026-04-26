with import <nixpkgs> {};

{
  agent-shell = import ./emacs-recipes/agent-shell.nix { inherit stdenv fetchFromGitHub; };
  eldoc-box = import ./emacs-recipes/eldoc-box.nix { inherit stdenv fetchFromGitHub emacsPackages; };
}
