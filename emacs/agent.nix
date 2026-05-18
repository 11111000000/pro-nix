{ config, lib, pkgs, emacsPkg ? pkgs.emacs, ... }:

{
  # Agent defaults belong to their own boundary: they are convenient for power
  # users, but they should not define the editor baseline for everyone.
  # The current repo already exposes the modules; here we only keep the default
  # module list in one place so the HM aggregator can stay thin.
}
