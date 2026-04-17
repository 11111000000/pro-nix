{ lib, ... }:

{
  nixpkgs.overlays = [
    (final: prev: {
      replaceVars = prev.replaceVars or (src: vars: prev.substituteAll (vars // { inherit src; }));
      formats = prev.formats // {
        ini = args:
          let
            fmt = prev.formats.ini args;
            baseLib = if fmt ? lib then fmt.lib else prev.lib;
            patchedLib =
              let
                t = baseLib.types;
                atomType = t.oneOf [ t.bool t.int t.float t.str t.path t.package ];
              in
              baseLib // { types = t // { atom = (t.atom or atomType); }; };
          in
          fmt // { lib = patchedLib; };

        iniWithGlobalSection = args:
          let
            iniFmt = prev.formats.ini args;
            baseLib = if iniFmt ? lib then iniFmt.lib else prev.lib;
            patchedLib =
              let
                t = baseLib.types;
                atomType = t.oneOf [ t.bool t.int t.float t.str t.path t.package ];
              in
              baseLib // { types = t // { atom = (t.atom or atomType); }; };
            atomToString = v:
              let ty = builtins.typeOf v;
              in
              if ty == "bool" then (if v then "true" else "false")
              else if ty == "int" || ty == "float" then builtins.toString v
              else builtins.toString v;
            renderKV = k: v: "${k}=${atomToString v}";
            renderGlobal = attrs: prev.lib.concatStringsSep "\n" (prev.lib.mapAttrsToList renderKV attrs);
            renderSection = name: attrs:
              let body = prev.lib.concatStringsSep "\n" (prev.lib.mapAttrsToList renderKV attrs);
              in "[${name}]\n${body}";
            generate = _name: value:
              let
                global = value.globalSection or {};
                sections = builtins.removeAttrs value [ "globalSection" ];
                parts = (if global == {} then [] else [ (renderGlobal global) ]) ++ (prev.lib.mapAttrsToList renderSection sections);
              in prev.lib.concatStringsSep "\n\n" parts + "\n";
          in { inherit (iniFmt) type; inherit generate; lib = patchedLib; };

        xml = _args:
          let
            baseLib = prev.lib;
            generate = _name: value: if baseLib.generators ? toXML then baseLib.generators.toXML { } value else builtins.toXML value;
          in { type = baseLib.types.attrs; inherit generate; lib = baseLib; };
      };
    })
    (final: prev: {
      cudaPackages = let cp = prev.cudaPackages; in cp // { cudaFlags = cp.flags; cudaVersion = cp.cudaMajorMinorVersion; };
    })
  ];
}
