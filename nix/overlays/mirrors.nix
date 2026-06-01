final: prev: let
  lib = final.lib;
  # Simple URL rewrites for domains that are blocked/unreliable.
  # Note: modern nixpkgs fetchurl doesn't accept a `mirrors` argument; the
  # supported extension point is `rewriteURL`.
  rewrites = [
    {
      from = "https://curl.haxx.se/";
      to = "https://curl.se/";
    }
    {
      from = "https://astron.com/";
      to = "https://ftp.astron.com/";
    }
    {
      from = "https://git.kernel.org/";
      to = "https://mirrors.edge.kernel.org/";
    }
    {
      from = "https://www.kernel.org/";
      to = "https://mirrors.edge.kernel.org/";
    }
  ];

  applyRewrites = url:
    lib.foldl'
      (u: r: if lib.strings.hasPrefix r.from u then lib.strings.replaceStrings [ r.from ] [ r.to ] u else u)
      url
      rewrites;
in {
  fetchurl = prev.fetchurl.override (old: {
    rewriteURL = url: applyRewrites ((old.rewriteURL or (x: x)) url);
  });

  # `file` source — swap URL order so the working macports mirror is tried first
  file = prev.file.overrideAttrs (old: {
    src = prev.fetchurl {
      urls = [
        "https://distfiles.macports.org/file/file-${old.version}.tar.gz"
        "https://ftp.astron.com/pub/file/file-${old.version}.tar.gz"
      ];
      hash = "sha256-/Jf1ECm7DiyfTjv/79r2ePDgOe6HK53lwAKm0Jx4TYI=";
    };
  });
}
