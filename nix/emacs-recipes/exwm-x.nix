{ lib
, trivialBuild
, fetchurl
, exwm
}:

trivialBuild {
  pname = "exwm-x";
  version = "20230119.624";

  src = fetchurl {
    url = "https://github.com/tumashu/exwm-x/archive/1e2bbfca872ad76eaa8f1c00d17762bed256881a.tar.gz";
    sha256 = "ac44a7d064f7b8ce3c223a32ea91c03a30eadb2b6328a32a11bb8aada2b2fbfb";
  };

  buildInputs = [ exwm ];

  meta = {
    description = "EXWM extensions and patches";
    longDescription = ''
      A collection of additional features and bug fixes for EXWM,
      maintained as a separate package by @tumashu.
    '';
    homepage = "https://github.com/tumashu/exwm-x";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.unix;
  };
}
