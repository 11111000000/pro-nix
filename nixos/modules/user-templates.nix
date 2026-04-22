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

  config = lib.mkIf (lib.length config.pro.userTemplates > 0) (let
    entries = config.pro.userTemplates;
  in lib.foldl' (acc: t: acc // {
    environment.etc = acc.environment.etc or {} // (let
      key = "skel/pro-templates/${t.targetRel}";
    in {
      "${key}" = {
        source = t.source;
        mode = "0644";
      };
    });
  ) { } entries);
}
