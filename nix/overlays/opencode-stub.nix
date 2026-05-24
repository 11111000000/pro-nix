# Overlay: provide real opencode binary from npm
final: prev: {
  opencode = prev.stdenv.mkDerivation {
    pname = "opencode";
    version = "1.15.10";

    src = prev.fetchurl {
      url = "https://registry.npmjs.org/opencode-linux-x64/-/opencode-linux-x64-1.15.10.tgz";
      sha256 = "0f7n2avwjc54b4lbd9fwqgx9nbjs1v4xa8bnhq4qfk17jf5njcc3";
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