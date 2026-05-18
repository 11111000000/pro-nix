{ pkgs, ... }:

let
  maybe = pkg: if pkg == null then [ ] else [ pkg ];
in
{
  # Every entry here is optional: the set composes only the servers that are
  # actually present in the chosen nixpkgs closure.
  lspPackages =
    maybe (if builtins.hasAttr "nodePackages" pkgs && builtins.hasAttr "pyright" pkgs.nodePackages then pkgs.nodePackages.pyright else null)
    ++ maybe (if builtins.hasAttr "jdtls" pkgs then pkgs.jdtls else null)
    ++ maybe (if builtins.hasAttr "rust-analyzer" pkgs then pkgs.rust-analyzer else null)
    ++ maybe (if builtins.hasAttr "goPackages" pkgs && builtins.hasAttr "gopls" pkgs.goPackages then pkgs.goPackages.gopls else null)
    ++ maybe (if builtins.hasAttr "nodePackages" pkgs && builtins.hasAttr "bash-language-server" pkgs.nodePackages then pkgs.nodePackages."bash-language-server" else null);
}
