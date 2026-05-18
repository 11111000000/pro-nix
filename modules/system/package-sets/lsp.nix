{ pkgs, ... }:

with pkgs;

{
  lspPackages = [
    (if builtins.hasAttr "nodePackages" pkgs && builtins.hasAttr "pyright" pkgs.nodePackages then pkgs.nodePackages.pyright else null)
    (if builtins.hasAttr "jdtls" pkgs then pkgs.jdtls else null)
    (if builtins.hasAttr "rust-analyzer" pkgs then pkgs.rust-analyzer else null)
    (if builtins.hasAttr "goPackages" pkgs && builtins.hasAttr "gopls" pkgs.goPackages then pkgs.goPackages.gopls else null)
    (if builtins.hasAttr "nodePackages" pkgs && builtins.hasAttr "bash-language-server" pkgs.nodePackages then pkgs.nodePackages."bash-language-server" else null)
  ];
}
