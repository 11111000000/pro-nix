self: super:
let
  haveRepoFunc = builtins.hasAttr "emacsPackageFromRepository" super;
  extras = if haveRepoFunc then {
    # Provide missing packages via fetchFromGitHub or melpa-style recipes.
    # Each entry uses a minimal recipe; adjust versions/hashes if needed.
    embark = super.emacsPackageFromRepository {
      pname = "embark";
      repository = "oantolin/embark";
      revision = "v0.20";
    };

    embark-consult = super.emacsPackageFromRepository {
      pname = "embark-consult";
      repository = "oantolin/embark-consult";
      revision = "v0.9";
    };

    telega = super.emacsPackageFromRepository {
      pname = "telega";
      repository = "zevlg/telega.el";
      revision = "v1.6";
    };

    "treemacs-icons-dired" = super.emacsPackageFromRepository {
      pname = "treemacs-icons-dired";
      repository = "Alexander-Miller/treemacs-icons-dired";
      revision = "v3.0";
    };

    eldoc-box = super.emacsPackageFromRepository {
      pname = "eldoc-box";
      repository = "vitalie/eldoc-box";
      revision = "v0.3.0";
    };

    agent-shell = super.emacsPackageFromRepository {
      pname = "agent-shell";
      repository = "anomalyco/agent-shell";
      revision = "v0.1.0";
    };

    golden-ratio = super.emacsPackageFromRepository {
      pname = "golden-ratio";
      repository = "roman/golden-ratio.el";
      revision = "v0.8";
    };
  } else {};
in {
  emacsPackages = super.emacsPackages // extras;
}
