# Overlay: replace opencode with a small stub to avoid building its plugins
{ self, super }: {
  opencode = super.stdenv.mkDerivation {
    pname = "opencode-stub";
    version = "1";
    dontBuild = true;
    installPhase = ''
      mkdir -p $out/bin
      cat > $out/bin/opencode <<'EOF'
#!/bin/sh
echo "opencode (stub)"
EOF
      chmod +x $out/bin/opencode
    '';
    meta = with super.lib; {
      description = "Stub opencode package used in pro-nix to skip building upstream plugins";
      license = licenses.mit;
      maintainers = [];
    };
  };
}
