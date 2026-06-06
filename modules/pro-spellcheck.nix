# Название: modules/pro-spellcheck.nix — Русская проверка орфографии на лету
# Кратко: ставит hunspell + русский словарь и проксирует путь к словарю
#   через переменную DICPATH, чтобы Emacs (flyspell/ispell) находил ru_RU
#   без ручной настройки.
#
# Цель:
#   Дать системе готовый hunspell с русским словарём, развёрнутым
#   автоматически при `just switch`. Словарь вендорен в репозитории
#   (dictionaries/hunspell/ru_RU.{aff,dic}), что обеспечивает
#   воспроизводимость: словарь не зависит от того, есть ли пакет
#   hunspellDicts.ru_RU в используемой версии nixpkgs.
#
# Контракт:
#   Опции:
#     pro.spellcheck.enable         — bool, default false
#     pro.spellcheck.dictionary     — строка, default "ru_RU"
#     pro.spellcheck.secondaryDicts — список дополнительных словарей
#                                    (например ["en_US"]), default []
#   Побочные эффекты: при enable = true
#     - environment.systemPackages: pro-hunspell (hunspell с DICPATH).
#     - environment.etc."pro/spellcheck/hunspell": копия ru_RU.aff/dic.
#   Производные пакеты (для других модулей):
#     - pro.spellcheck.hunspellPackage — обёрнутый hunspell с DICPATH.
#     - pro.spellcheck.ruDictPackage   — derivation со словарями.
#
# Предпосылки:
#   - Импортируется из configuration.nix (или хоста), который хочет flyspell.
#   - Модуль emacs/base/modules/pro-spell.el считывает pro.spellcheck.dictionary
#     и активирует flyspell для соответствующих режимов.
#
# Как проверить (Proof):
#   - `nix eval .#nixosConfigurations.<host>.config.environment.systemPackages`
#     содержит `pro-hunspell`.
#   - `nix build .#nixosConfigurations.<host>.config.system.build.toplevel`
#     завершается без ошибок.
#   - После switch: `M-x flyspell-mode` в org-буфере подчёркивает
#     опечатки на русском.
#
# Last reviewed: 2026-06-06
{ config, lib, pkgs, ... }:

let
  cfg = config.pro.spellcheck;

  # Russian hunspell dictionary, vendored from
  # https://github.com/LibreOffice/dictionaries/tree/master/ru_RU
  # (MPL-2.0, см. dictionaries/hunspell/README.md). Вендоринг даёт
  # воспроизводимость вне зависимости от версии nixpkgs.
  proHunspellRu = pkgs.stdenv.mkDerivation {
    pname = "pro-hunspell-ru";
    version = "0.1.0";
    src = ../dictionaries/hunspell;
    dontConfigure = true;
    dontBuild = true;
    dontStrip = true;
    installPhase = ''
      runHook preInstall
      mkdir -p $out/share/hunspell
      cp $src/*.aff $src/*.dic $out/share/hunspell/
      runHook postInstall
    '';
    meta = with lib; {
      description = "Russian hunspell dictionary (vendored from LibreOffice/dictionaries)";
      longDescription = ''
        Russian hunspell dictionary (ru_RU.aff + ru_RU.dic) regenerated
        from LibreOffice/dictionaries. Vendored into the repository to
        guarantee reproducibility across nixpkgs revisions.
      '';
      license = licenses.mpl20;
      platforms = platforms.unix;
    };
  };

  # Optional secondary dictionaries (e.g. en_US) from nixpkgs.
  resolveDict = name:
    if pkgs ? hunspellDicts && pkgs.hunspellDicts ? ${name}
    then pkgs.hunspellDicts.${name}
    else throw "pro-spellcheck: pkgs.hunspellDicts.${name} not available in this nixpkgs";

  secondaryDerivationList = map resolveDict cfg.secondaryDicts;
  allDicts = [ proHunspellRu ] ++ secondaryDerivationList;
  dictPath = lib.concatMapStringsSep ":" (d: "${d}/share/hunspell") allDicts;

  # Hunspell wrapper that hard-codes DICPATH to our dictionary locations.
  # Naming the binary `pro-hunspell` avoids clashing with the upstream
  # `pkgs.hunspell` while still being discoverable on PATH.
  proHunspell = pkgs.runCommand "pro-hunspell" {
    nativeBuildInputs = [ pkgs.makeWrapper ];
    meta = with lib; {
      description = "Hunspell wrapper with DICPATH pointing at pro-managed dictionaries";
      license = pkgs.hunspell.meta.license or licenses.mit;
      platforms = platforms.unix;
      mainProgram = "pro-hunspell";
    };
  } ''
    runHook preBuild
    mkdir -p $out/bin
    makeWrapper ${pkgs.hunspell}/bin/hunspell $out/bin/pro-hunspell \
      --set-default DICPATH "${dictPath}"
    runHook postBuild
  '';
in
{
  options.pro.spellcheck = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Включает русскую проверку орфографии на лету (hunspell + ru_RU)
        во всех режимах Emacs, активируемых модулем pro-spell.el.
      '';
    };

    dictionary = lib.mkOption {
      type = lib.types.str;
      default = "ru_RU";
      description = ''
        Имя словаря, передаваемое в ispell-dictionary (например, "ru_RU"
        или "ru_RU,en_US" для мульти-словаря).
      '';
    };

    secondaryDicts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = [ "en_US" ];
      description = ''
        Дополнительные словари, подкладываемые в DICPATH. Например,
        ["en_US"] подтянет словарь из pkgs.hunspellDicts.en_US, чтобы
        в комментариях/строках кода англоязычные термины не считались
        опечатками. Используйте короткие имена словарей (en_US, de_DE…).
      '';
    };

    hunspellPackage = lib.mkOption {
      type = lib.types.package;
      default = proHunspell;
      internal = true;
      description = ''
        Обёрнутый hunspell с DICPATH, настроенным на pro-словари.
        Внутренняя опция: используется другими модулями, чтобы
        добавить пакет в пользовательские профили.
      '';
    };

    ruDictPackage = lib.mkOption {
      type = lib.types.package;
      default = proHunspellRu;
      internal = true;
      description = ''
        Derivation с русским hunspell-словарём (для отладки и
        интеграции с другими пакетами). Внутренняя опция.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Словарь в /etc/pro/spellcheck/hunspell — для отладки и предсказуемого
    # пути, если какой-то инструмент читает его без DICPATH.
    environment.etc."pro/spellcheck/hunspell".source = "${proHunspellRu}/share/hunspell";

    # Hunspell + наша обёртка. Используем простую конкатенацию (не
    # lib.mkDefault) согласно §2 AGENTS.md: обязательные пакеты.
    environment.systemPackages = [ proHunspell ];
  };
}
