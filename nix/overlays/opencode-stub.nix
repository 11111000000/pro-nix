# Overlay: provide real opencode binary from npm
final: prev: {
  opencode = prev.stdenv.mkDerivation {
    pname = "opencode";
    version = "1.17.13";

    src = prev.fetchurl {
      url = "https://registry.npmjs.org/opencode-linux-x64/-/opencode-linux-x64-1.17.13.tgz";
      sha256 = "0ca3x2s12x3iq74h9fjsih3nl5liqg4lsjvg3wjy2j9l9ks75884";
    };

    nativeBuildInputs = [ prev.patchelf ];
    sourceRoot = "package";

    dontStrip = true;
    dontPatchELF = true;
    dontPatchShebangs = true;

    installPhase = ''
      runHook preInstall
      install -Dm755 bin/opencode $out/bin/opencode
      patchelf --set-interpreter ${prev.glibc}/lib/ld-linux-x86-64.so.2 $out/bin/opencode
      runHook postInstall
    '';

    meta = with prev.lib; {
      description = "AI coding agent built for the terminal";
      homepage = "https://opencode.ai";
      license = licenses.mit;
      platforms = [ "x86_64-linux" ];
      mainProgram = "opencode";
    };
  };
}