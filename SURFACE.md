SURFACE — реестр публичных контрактов
=====================================

Запись описывает наблюдаемое поведение репозитория и команду(ы) — Proof, которые
это поведение проверяют.

- Имя: Healthcheck
  Стабильность: [FROZEN]
  Спецификация: репозиторий предоставляет воспроизводимую точку проверки работоспособности.
  Proof: `tests/contract/test_surface_health.spec`

- Имя: Soft Reload (Emacs)
  Стабильность: [FROZEN]
  Спецификация: опция `pro.emacs.softReload.enable` позволяет безопасно обновлять UI,
  настройки и модули без полного перезапуска Emacs; наличие headless ERT, проверяющего
  корректность перезагрузки.
  Proof: headless ERT runner (см. HOLO.md)

- Имя: Pro-peer Key Sync
  Стабильность: [FLUID]
  Спецификация: опция `pro-peer.enableKeySync` управляет systemd-сервисом
  `pro-peer-sync-keys` и скриптом `scripts/ops-pro-peer-sync-keys.sh` для синхронизации ключей.
  Proof: `scripts/ops-pro-peer-sync-keys.sh` (smoke) и соответствующие unit-файлы systemd.

- Имя: LLM Research Surface
  Стабильность: [FLUID]
  Спецификация: воспроизводимый entrypoint `llm-lab` для экспериментов и тестов с LLM.
  Proof: `tests/contract/unit/03-llm-tools.sh`

## Nix-опции (pro-emacs.*)

- Имя: Emacs Portable Profile
  Стабильность: [FROZEN]
  Спецификация: pro.emacs.enable активирует переносимый Emacs профиль через Home Manager;
    предоставляет providedPackages из Nix в home.packages; настраивает EMACSLOADPATH.
  Code: emacs/home-manager.nix:165-193 (options.pro.emacs)
  Proof: tests/contract/unit/02-emacs-options.sh

- Имя: Emacs GUI Layer
  Стабильность: [FLUID]
  Спецификация: pro.emacs.gui.enable активирует X resources, GTK, EXWM session launcher.
  Code: emacs/home-manager.nix:168, 41-162 (guiFiles)
  Proof: tests/contract/test-gui-smoke.el

- Имя: Emacs Provided Packages
  Стабильность: [FROZEN]
  Спецификация: pro.emacs.providedPackages определяет список из 23+ пакетов, предоставляемых Nix;
    включая magit, consult, vertico, corfu, eglot, org, projectile, treemacs.
  Code: emacs/home-manager.nix:184 (default providedPackages list)
  Proof: tests/contract/unit/07-runtime-packages.sh

- Имя: Emacs Default Modules
  Стабильность: [FLUID]
  Спецификация: pro.emacs.defaultModules определяет 18 модулей по умолчанию.
  Code: emacs/home-manager.nix:5 (defaultModules), 188-192
  Proof: emacs --batch -l emacs/base/init.el 2>&1 | grep "loaded module"

## Nix-опции (pro-peer.*)

- Имя: Peer Discovery
  Стабильность: [FROZEN]
  Спецификация: pro.peer.enable активирует Avahi (mDNS) для LAN discovery; включает SSH hardening.
  Code: modules/pro-peer.nix:28
  Proof: tests/contract/unit/01-pro-peer-basic.sh

- Имя: Peer Key Sync
  Стабильность: [FLUID]
  Спецификация: pro.peer.enableKeySync активирует systemd сервис pro-peer-sync-keys для
    синхронизации authorized_keys из GPG-шифрованного файла.
  Code: modules/pro-peer.nix:30
  Proof: bash scripts/ops-pro-peer-sync-keys.sh --help

- Имя: Tor Ensure Services
  Стабильность: [FLUID]
  Спецификация: systemd сервисы tor-ensure-bridges и tor-ensure-perms создают
    /etc/tor/bridges.conf и /var/lib/tor с правильными правами перед запуском Tor.
    Используют after=dbus-broker.service polkit.service для исключения race condition.
  Code: modules/pro-privacy.nix:87-123
  Proof: systemd-analyze verify tor-ensure-*.service; journalctl -u tor-ensure-bridges --no-pager | grep -E "Unbalanced quoting|parse failure"

- Имя: Yggdrasil Mesh
  Стабильность: [FLUID]
  Спецификация: pro.peer.enableYggdrasil активирует mesh VPN daemon.
  Code: modules/pro-peer.nix:46
  Proof: nix eval --json .#nixosConfigurations.cf19.config.pro.peer.enableYggdrasil

- Имя: Yggdrasil Config Path
  Стабильность: [FLUID]
  Спецификация: pro.peer.yggdrasilConfigPath указывает путь к конфигу yggdrasil.
  Code: modules/pro-peer.nix:47
  Proof: nix eval --json .#nixosConfigurations.cf19.config.pro.peer.yggdrasilConfigPath

- Имя: WireGuard Helper
  Стабильность: [FLUID]
  Спецификация: pro.peer.enableWireguardHelper активирует wg-quick helper service.
  Code: modules/pro-peer.nix:52
  Proof: nix eval --json .#nixosConfigurations.cf19.config.pro.peer.enableWireguardHelper

- Имя: WireGuard Config Path
  Стабильность: [FLUID]
  Спецификация: pro.peer.wireguardConfigPath указывает путь к wg0.conf.
  Code: modules/pro-peer.nix:53
  Proof: nix eval --json .#nixosConfigurations.cf19.config.pro.peer.wireguardConfigPath

- Имя: Tor Hidden Service for SSH
  Стабильность: [FLUID]
  Спецификация: pro.peer.allowTorHiddenService включает Tor hidden service для SSH.
  Code: modules/pro-peer.nix:29
  Proof: nix eval --json .#nixosConfigurations.cf19.config.pro.peer.allowTorHiddenService

## Nix-опции (headscale)

- Имя: Headscale Control Plane
  Стабильность: [FLUID]
  Спецификация: headscale.enable активирует WireGuard VPN control plane; слушает на :8080.
  Code: modules/headscale.nix:24
  Proof: nix eval --json .#nixosConfigurations.cf19.config.headscale.enable

- Имя: Headscale Listen Address
  Стабильность: [FLUID]
  Спецификация: headscale.listenAddress определяет адрес для headscale (default: 0.0.0.0:8080).
  Code: modules/headscale.nix:25
  Proof: nix eval --json .#nixosConfigurations.cf19.config.headscale.listenAddress

## Nix-опции (services.*)

- Имя: ZRAM Swap
  Стабильность: [FLUID]
  Спецификация: services.zramSlice.enable настраивает zram swap при загрузке (50% RAM).
  Code: nixos/modules/zram-slice.nix:12
  Proof: nix eval --json .#nixosConfigurations.cf19.config.services.zramSlice.enable

- Имя: OpenCode Resource Limits
  Стабильность: [FLUID]
  Спецификация: services.opencodeSlice.enable ограничивает ресурсы агентов (4G memory, 80% CPU).
  Code: nixos/modules/zram-slice.nix:21
  Proof: tests/contract/unit/04-opencode-options.sh

- Имя: Tor Client
  Стабильность: [FLUID]
  Спецификация: services.tor.client.enable активирует Tor клиент с ControlPort 9051.
  Code: modules/pro-privacy.nix:29
  Proof: tests/contract/tor-01.sh

- Имя: Samba File Sharing
  Стабильность: [FLUID]
  Спецификация: services.samba.enable активирует SMB server; открывает порты 445, 139.
  Code: modules/pro-storage.nix:28
  Proof: ss -tlnp | grep -E '445|139'

- Имя: Syncthing
  Стабильность: [FLUID]
  Спецификация: services.syncthing.enable активирует Syncthing daemon; порты 22000, 8384.
  Code: modules/pro-storage.nix:105
  Proof: ss -tlnp | grep -E '22000|8384'

- Имя: Network Services
  Стабильность: [FROZEN]
  Спецификация: NetworkManager + systemd-resolved + firewall для базовых сетевых служб.
  Code: modules/pro-services.nix:19-22, 47-52

- Имя: SSH Hardening
  Стабильность: [FROZEN]
  Спецификация: services.openssh с PermitRootLogin=no, PasswordAuthentication=no.
  Code: modules/pro-services.nix:23-28

- Имя: Fail2Ban
  Стабильность: [FLUID]
  Спецификация: services.fail2ban.enable активирует intrusion prevention.
  Code: modules/pro-services.nix:39
  Proof: systemctl status fail2ban

## Nix Hosts

- Имя: Lenovo ThinkPad cf19
  Стабильность: [FLUID]
  Спецификация: NixOS конфигурация для Lenovo ThinkPad cf19.
  Code: hosts/cf19/configuration.nix
  Proof: nix build .#nixosConfigurations.cf19.config.system.build.toplevel

- Имя: Huawei Host
  Стабильность: [FLUID]
  Спецификация: NixOS конфигурация для Huawei хоста.
  Code: hosts/huawei/configuration.nix
  Proof: nix build .#nixosConfigurations.huawei.config.system.build.toplevel

## Emacs-модули

- Имя: Session Serialization
  Стабильность: [FLUID]
  Спецификация: pro-session.el сохраняет и восстанавливает buffer/point/window state.
  Code: emacs/base/modules/pro-session.el
  Proof: emacs --batch --eval "(require 'pro-session)"

- Имя: Soft Reload
  Стабильность: [FROZEN]
  Спецификация: pro-reload.el позволяет перезагружать модули без полного перезапуска;
    pro/session-save-and-restart-emacs для контролируемого перезапуска.
  Code: emacs/base/modules/pro-reload.el, pro-session.el
  Proof: emacs --batch --eval "(require 'pro-reload)"

- Имя: Package Knowledge Graph
  Стабильность: [FLUID]
  Спецификация: pro-epistemology.el отслеживает источники знания о пакетах;
    pro--knowing-agent возвращает nix/runtime/melpa/vcs/unknown.
  Code: emacs/base/modules/pro-epistemology.el (создать)
  Proof: emacs --batch --eval "(require 'pro-epistemology)"

- Имя: Nix Rebuild Integration
  Стабильность: [FLUID]
  Спецификация: pro-nix.el предоставляет pro-nix-rebuild-system для nixos-rebuild.
  Code: emacs/base/modules/pro-nix.el:15
  Proof: emacs --batch --eval "(require 'pro-nix)"

- Имя: Completion Stack
  Стабильность: [FLUID]
  Спецификация: pro-completion.el объединяет corfu, cape, kind-icon в единый completion workflow.
  Code: emacs/base/modules/pro-completion.el
  Proof: emacs --batch --eval "(require 'pro-completion)"

- Имя: Module Loading Trace
  Стабильность: [FLUID]
  Спецификация: site-init.el логирует загрузку модулей в *Messages*.
  Code: emacs/base/site-init.el:178
  Proof: emacs --batch -Q -l emacs/base/init.el 2>&1 | grep "loaded module"

## Contract Proofs

| Тест | Назначение | Команда |
|------|-----------|---------|
| unit/01-pro-peer-basic.sh | pro-peer enable | bash tests/contract/unit/01-pro-peer-basic.sh |
| unit/02-emacs-options.sh | pro.emacs.* | bash tests/contract/unit/02-emacs-options.sh |
| unit/03-llm-tools.sh | llm-lab | bash tests/contract/unit/03-llm-tools.sh |
| unit/04-opencode-options.sh | opencodeSlice | bash tests/contract/unit/04-opencode-options.sh |
| unit/05-mkforce-lint-test.sh | lib.mkForce | bash tests/contract/unit/05-mkforce-lint-test.sh |
| unit/06-pro-peer-dryrun.sh | pro-peer dry-run | bash tests/contract/unit/06-pro-peer-dryrun.sh |
| unit/07-runtime-packages.sh | runtime packages | bash tests/contract/unit/07-runtime-packages.sh |
| unit/09-system-packages-eval.sh | system packages | bash tests/contract/unit/09-system-packages-eval.sh |
| test-theme-contrast.el | UI contrast | emacs --batch -l tests/contract/test-theme-contrast.el |
| test-gui-smoke.el | GUI smoke | emacs --batch -l tests/contract/test-gui-smoke.el |
