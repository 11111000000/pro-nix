{ lib
, trivialBuild
, fetchurl
, xelb
, compat
}:

trivialBuild {
  pname = "exwm";
  version = "0.35.0.20260704.2";

  src = fetchurl {
    url = "https://elpa.gnu.org/devel/exwm-0.35.0.20260704.2.tar";
    sha256 = "ae321aa5b0282ffcb102d0bbef4670fa6bc531b70652f097d76787d0c1217576";
  };

  buildInputs = [ xelb compat ];

  meta = {
    description = "Emacs X Window Manager";
    longDescription = ''
      EXWM (Emacs X Window Manager) is a full-featured tiling X window
      manager for Emacs built on top of XELB.
    '';
    homepage = "https://github.com/emacs-exwm/exwm";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.unix;
  };
}
