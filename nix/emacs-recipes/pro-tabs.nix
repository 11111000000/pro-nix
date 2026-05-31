{ stdenv, emacs, lib, all-the-icons ? null }:

stdenv.mkDerivation rec {
  pname = "pro-tabs";
  version = "2.0";
  src = builtins.fetchTree { type = "github"; owner = "gnu-emacs-ru"; repo = "pro-tabs"; rev = "d065069b28ff0a89feb7cd856122d454aa219591"; narHash = "sha256-xpYPrIa5IZtQZJ+5jQs/4nq9RinXrRZuCu0GsDRKAzI="; };

  nativeBuildInputs = [ emacs ];
  buildInputs = if all-the-icons != null then [ all-the-icons ] else [ ];

  dontConfigure = true;

  buildPhase = ''
    runHook preBuild
    FLAGS="-L ."
    if ls ${if all-the-icons != null then all-the-icons else "\"\""}/share/emacs/site-lisp/elpa/all-the-icons-*/all-the-icons.el 2>/dev/null; then
      FLAGS="$FLAGS -L $(ls -d ${if all-the-icons != null then all-the-icons else "\"\""}/share/emacs/site-lisp/elpa/all-the-icons-* | head -1)"
    fi
    emacs --batch -Q $FLAGS -f batch-byte-compile pro-tabs.el pro-tabs-autoloads.el pro-tabs-pkg.el 2>/dev/null || true
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/emacs/site-lisp/${pname}
    cp *.el $out/share/emacs/site-lisp/${pname}/
    cp *.elc $out/share/emacs/site-lisp/${pname}/ 2>/dev/null || true
    runHook postInstall
  '';

  meta = with lib; {
    description = "Simple & reusable tabs for Emacs (gnu-emacs-ru/pro-tabs)";
    homepage = "https://github.com/gnu-emacs-ru/pro-tabs";
    license = licenses.mit;
  };
}