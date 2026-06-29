+++
title = "Анти-паттерны"
template = "page.html"
weight = 5

[extra]
tldr = "То, что в коде есть, но не стоит добавлять самому. mkDefault для обязательных пакетов, hardcoded IP в ssh_config, глобальный zoom, tailscale.enable=true, nixos-rebuild switch в CI."

+++

# Анти-паттерны

То, что вы увидите в коде, но не должны добавлять сами. Каждый
пункт — реальный анти-паттерн, который был или мог быть допущен.

## NixOS

### `lib.mkDefault` для обязательных пакетов

```nix
# ❌ НЕ ДЕЛАЙТЕ ТАК
environment.systemPackages = lib.mkDefault (with pkgs; [ bashInteractive openssh ]);
```

`lib.mkDefault` — это приоритет-100-утверждение. Любое обычное
присвоение в другом модуле тихо его заменит, и пакеты пропадут.
Используйте plain для обязательных, `lib.mkDefault` для дефолтов.

### `services.tailscale.enable = true` глобально

```nix
# ❌ НЕ ДЕЛАЙТЕ ТАК
services.tailscale.enable = true;
```

Требует auth-key, ломает `nixos-rebuild` без секрета. Включайте
через будущий `pro.tailnet`-модуль, не глобально. Сейчас роль
headscale даёт Tailscale-эквивалентный mesh без auth-key.

### `services.resolved.llmnr = false` (без кавычек)

```nix
# ❌ НЕ ДЕЛАЙТЕ ТАК
services.resolved.llmnr = false;
```

NixOS-опция `services.resolved.llmnr` — это `enum [ "true"
"resolve" "false" ]`, а не `types.bool`. `false` без кавычек —
type error. Правильно: `llmnr = "false";` (в строке). Это
by-design, привыкайте.

### `nixos-rebuild switch` в CI

```yaml
# ❌ НЕ ДЕЛАЙТЕ ТАК
- name: Apply
  run: sudo nixos-rebuild switch --flake .
```

CI должен делать `nix flake check` / `nix build` / `nix run
nixosTest`. Применение (`switch`) опасно — он меняет реальную
систему. Используйте `validate-pr.yml` как пример: там `nix
build` для `nixos-rebuild`-производного.

### `nix-ld.enable = true` (по умолчанию)

Уже выключен в `configuration.nix:272`:

```nix
programs.nix-ld.enable = false;
```

`nix-ld` injects a compatibility library path which can cause
GTK/GLib library version mismatches for GUI applications (см.
`docs/research/analysis-results.txt`). Телеграм-desktop и другие
GTK-приложения падают, если `nix-ld` даёт несовместимые
библиотеки. **Не включайте** без необходимости.

### Hardcoded IP в ssh_config

```nix
# ❌ НЕ ДЕЛАЙТЕ ТАК
services.openssh = {
  extraConfig = ''
    Host desktop
      HostName 192.168.1.5
  '';
};
```

Сгенерированный `ssh_config.d/pro.conf` уже использует кандидат-FQDN'ы
из `pro.hosts`. Не обходите через `pro.hosts.<x>.addr` без
необходимости.

## Emacs

### `(define-key global-map ...)` в модуле

```elisp
;; ❌ НЕ ДЕЛАЙТЕ ТАК
(define-key global-map (kbd "C-c f x") #'pro-foo-do-thing)
```

Глобальные биндинги принадлежат только `emacs-keys.org`. Если
модуль хочет предложить биндинг — используйте
`pro/register-module-keys`. CI-линт
(`helper-lint-keys.sh`) поймает `global-set-key` в `.el`-файлах.

### `local-set-key` в top-level форме

```elisp
;; ❌ НЕ ДЕЛАЙТЕ ТАК
(local-set-key (kbd "C-c f") #'pro-foo-mode-map)
;; в top-level форме pro-foo.el
```

Это загрязняет все буферы, а не только `pro-foo-mode`. Используйте
`pro-foo-mode-hook` и `define-key` внутри.

### Глобальный zoom через `set-face-attribute`

```elisp
;; ❌ НЕ ДЕЛАЙТЕ ТАК
(set-face-attribute 'default nil :height 200)
```

Меняет шрифт во всех буферах. Используйте `text-scale-adjust` (уже
завязан на `pro-ui-zoom-*`, см. `C-=`, `C-+`, `C--`, `C-0` в
`emacs-keys.org`).

### `(setq enable-local-variables t)` или `safe-local-variable-values` в модуле

```elisp
;; ❌ НЕ ДЕЛАЙТЕ ТАК
(setq enable-local-variables t)
```

Подрывает безопасность без явной причины. Если модулю нужно
local-variable, объявите его через
`file-local-variables-alist` или `hack-local-variables`.

## URL и submodules

### `path:` URL для flake с submodules

```bash
# ❌ НЕ ДЕЛАЙТЕ ТАК
nix build "path:.#nixosConfigurations.cf19.config.system.build.toplevel"
```

`path:` не включает submodules в captured source. Рецепты
`nix/emacs-recipes/*.nix` читают `../../submodules/<name>`, что
упадёт с "path does not exist". Всегда:

```bash
nix build "git+file://$(pwd)?submodules=1#nixosConfigurations.cf19.config.system.build.toplevel"
```

`just build`, `just switch`, `just test`, `just flake-check` уже
используют правильный URL.

### `git+file://...` без `?submodules=1`

```bash
# ❌ НЕ ДЕЛАЙТЕ ТАК
nix build "git+file://$(pwd)#nixosConfigurations.cf19.config.system.build.toplevel"
```

Без `?submodules=1` Nix не захватывает submodules. Та же ошибка,
что и с `path:`.

## Git и workflow

### Force-push в `main`

```bash
# ❌ НЕ ДЕЛАЙТЕ ТАК (без крайней необходимости)
git push --force origin main
```

`main` — единственная долгоживущая ветка. Force-push ломает всех,
кто склонировал. Если нужен amend — `git commit --amend`
до push.

### Skip pre-commit hooks

```bash
# ❌ НЕ ДЕЛАЙТЕ ТАК
git commit --no-verify
```

Если хук падает — исправьте причину. Skip'ить хуки — обход
governance.

### Merge `--no-ff` отключён

Проект не использует merge commits для feature-веток; использует
`rebase + fast-forward`. См. `.github/PULL_REQUEST_TEMPLATE.md`
для соглашений.

## CI

### `actions/checkout` без `submodules: recursive`

```yaml
# ❌ НЕ ДЕЛАЙТЕ ТАК
- uses: actions/checkout@v4
```

Без `submodules: recursive` git-сабмодули не подтягиваются, и
`nix flake check` упадёт на missing path. Все CI-workflow должны
иметь:

```yaml
- uses: actions/checkout@v4
  with:
    submodules: recursive
```

## Privacy и секреты

### Коммитить `~/.authinfo`

Уже в `.gitignore` (`*.env`, `*.secret`, `secret`). Не
коммитить `local.nix`, `~/.authinfo`, `~/.authinfo.gpg`, `*.env`,
`*.secret`, `secret`. Это правило, не исключение.

### `pro-load-agent-env.sh` с hardcoded API-ключом

Скрипт читает `~/.authinfo` или `~/.authinfo.gpg` и экспортит
переменные. Никогда не hardcode API-ключи в самом скрипте.

## Обнаружение в коде

* `rg "global-set-key" --glob "**/*.el" | rg -v '/keys\.el:'` —
  поймает `define-key global-map` в `.el` вне `pro-keys.el`.
* `rg "lib.mkDefault" modules/` — manual review для package
  list'ов.
* `rg "services.tailscale.enable" --type nix` — поймает
  глобальное `tailscale.enable`.
* `rg "nixos-rebuild switch" .github/` — поймает switch в CI.
* `rg "path:\|\\.\\." flake.nix` — manual review для URL.

## Где это уже соблюдается

* `pro-emacs.el`, `pro-keys.el` — единственные файлы, которые
  вызывают `global-set-key`. Линт `helper-lint-keys.sh` это
  поддерживает.
* `configuration.nix` устанавливает `programs.nix-ld.enable =
  false` явно с комментарием.
* `flake.nix` использует `git+file://...?submodules=1` в
  `programs/check-all.program`.

## Связанные

* [mkForce](conventions/mkforce.md) — правильный паттерн
  приоритетов.
* [Commit format](conventions/commit.md) — заголовки
  `nix:`/`emacs:`/`site:`.
* [Dead code](conventions/dead-code.md) — `mkIf false {}` —
  индикатор, что модуль уже мёртвый.
