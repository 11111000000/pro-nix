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
  opencode-plugins = super.stdenv.mkDerivation {
    pname = "opencode-plugins-stub";
    version = "1";
    dontBuild = true;
    installPhase = ''
      mkdir -p $out
      echo "opencode-plugins (stub)" > $out/README
    '';
    meta = with super.lib; { description = "Stub for opencode-plugins"; license = licenses.mit; };
  };
  opencode-notifier = super.stdenv.mkDerivation {
    pname = "opencode-notifier-stub";
    version = "1";
    dontBuild = true;
    installPhase = ''
      mkdir -p $out/bin
      cat > $out/bin/opencode-notifier <<'EOF'
#!/bin/sh
echo "opencode-notifier (stub)"
EOF
      chmod +x $out/bin/opencode-notifier
    '';
    meta = with super.lib; { description = "Stub for opencode-notifier"; license = licenses.mit; };
  };
  opencode-anthropic-auth = super.stdenv.mkDerivation {
    pname = "opencode-anthropic-auth-stub";
    version = "1";
    dontBuild = true;
    installPhase = ''
      mkdir -p $out
      echo "opencode-anthropic-auth (stub)" > $out/README
    '';
    meta = with super.lib; { description = "Stub for opencode-anthropic-auth"; license = licenses.mit; };
  };
  opencode-node_modules = super.stdenv.mkDerivation {
    pname = "opencode-node-modules-stub";
    version = "1";
    dontBuild = true;
    installPhase = ''
      mkdir -p $out
      echo "opencode-node-modules (stub)" > $out/README
    '';
    meta = with super.lib; { description = "Stub for opencode node modules"; license = licenses.mit; };
  };
}
