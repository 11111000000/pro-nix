{ pkgs, ... }:

let
  maybe = pkg: if pkg == null then [ ] else [ pkg ];
in
{
  # Language servers are part of the developer experience, not the system
  # runtime. Keep them isolated so a host can choose development depth without
  # accidentally inheriting every backend.
  lspPackages =
    maybe (if builtins.hasAttr "nodePackages" pkgs && builtins.hasAttr "pyright" pkgs.nodePackages then pkgs.nodePackages.pyright else null)
    ++ maybe (if builtins.hasAttr "jdtls" pkgs then pkgs.jdtls else null)
    ++ maybe (if builtins.hasAttr "rust-analyzer" pkgs then pkgs.rust-analyzer else null)
    ++ maybe (if builtins.hasAttr "goPackages" pkgs && builtins.hasAttr "gopls" pkgs.goPackages then pkgs.goPackages.gopls else null)
    ++ maybe (if builtins.hasAttr "nodePackages" pkgs && builtins.hasAttr "bash-language-server" pkgs.nodePackages then pkgs.nodePackages."bash-language-server" else null);
}
