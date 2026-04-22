{ config, pkgs, lib, ... }:

let
  mkPath = path: lib.replaceStrings ["/" ] ["-"] path; # helper to create etc keys
in {
  options.pro = {
    userTemplates = lib.mkOption {
      type = lib.types.listOf (lib.types.attrsOf lib.types.path);
      default = [];
      description = ''
        List of templates to install into /etc/skel/pro-templates. Each element
        should be an attrset with { source = ./templates/xxx.json; targetRel = ".opencode/config.json"; }
      '';
    };
  };

  config = let
    entries = config.pro.userTemplates or [];
    addEntry = acc: t: acc // {
      environment.etc = (acc.environment.etc or {}) // (let
        key = "skel/pro-templates/${t.targetRel}";
      in {
        "${key}" = {
          source = t.source;
          mode = "0644";
        };
      });
    };
  in lib.foldl' addEntry { } entries;
}
