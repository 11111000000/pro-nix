# Название: modules/pro-home-perms.nix — авто-восстановление прав на $HOME
# Кратко: для каждого home-manager-пользователя добавляет activation,
# который при активации чинит владельца критичных dotdirs в $HOME.
# Это страховка от ситуации, когда каталог был создан другим
# Unix-аккаунтом на этой же машине (например, несколькими
# пользователями с одним /home через миграцию или общий git-репо).
#
# Цель:
#   Избежать regression-цикла "Permission denied" в деплое шаблонов
#   из `pro-agent-configs.nix` и любых будущих home-manager-активаций.
#
# Контракт:
#   Опции:
#     pro.homePerms.enable — bool (default true).
#     pro.homePerms.users — атрисет пользователей, для которых
#       добавляется per-user activation. Значения игнорируются.
#     pro.homePerms.protectedDirs — список путей относительно $HOME,
#       для которых гарантируется владение текущему пользователю.
#   Побочные эффекты: на каждой home-manager-активации вызывает
#     `chown -R $(id -u):$(id -g)` для защищённых каталогов, если они
#     существуют. Ошибки chown (нет доступа) глушатся — это страховка,
#     а не основной путь доставки файлов.
#
# Как проверить (Proof):
#   nix eval .#nixosConfigurations.desktop.config.pro.homePerms.protectedDirs
{ config, lib, ... }:

let
  cfg = config.pro.homePerms;
  userList = builtins.attrNames cfg.users;
in

{
  options.pro.homePerms = {
    enable = lib.mkEnableOption "Auto-fix ownership of $HOME dotdirs on home-manager activation" // { default = true; };
    users = lib.mkOption {
      type = lib.types.attrsOf lib.types.unspecified;
      default = {
        az = null;
        za = null;
        la = null;
        bo = null;
      };
      description = ''
        Set of users for whom `home-manager.users.<name>.home.activation` will
        be added. Values are ignored; only the keys matter. Override per-host if
        your HM user set differs from the pro-nix default.
      '';
    };
    protectedDirs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        ".pi"
        ".pi/agent"
        ".config/opencode"
        ".local/share/pro-nix"
      ];
      description = ''
        Dotdirs (relative to $HOME) whose ownership must match the current
        user. On home-manager activation, any protected dir owned by a
        different uid/gid is chowned recursively.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Per-user activation, in `home.activation.<name>` (home-manager
    # convention). HM substitutes the right $HOME at activation time and
    # runs the script as the user.
    home-manager.users = builtins.listToAttrs (map (u: {
      name = u;
      value.home.activation.pro-home-perms = ''
        uid="$(id -u)"
        gid="$(id -g)"
        for d in ${lib.concatStringsSep " " cfg.protectedDirs}; do
          path="$HOME/$d"
          [ -e "$path" ] || continue
          cur_uid="$(stat -c %u "$path" 2>/dev/null || stat -f %u "$path")"
          cur_gid="$(stat -c %g "$path" 2>/dev/null || stat -f %g "$path")"
          if [ "$cur_uid" != "$uid" ] || [ "$cur_gid" != "$gid" ]; then
            chown -R "$uid:$gid" "$path" 2>/dev/null \
              || echo "[pro-home-perms] WARN: cannot chown $path (was $cur_uid:$cur_gid, current is $uid:$gid)"
          fi
        done
      '';
    }) userList);
  };
}
