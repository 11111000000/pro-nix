+++
title = "Слой AI-агентов"
template = "page.html"
weight = 3

[extra]
tldr = "pi + opencode + EMCP + gptel. MCP-серверы: emcp (Emacs) и chrome-devtools. Skills: emacs-emcp, safe-bash. Permission system: deny-by-pattern."

[[extra.next]]
title = "Оконные менеджеры"
url = "/stack/wm/"

[[extra.next]]
title = "Стек AI-агентов"
url = "/architecture/agents/"
+++

# Слой AI-агентов

Слой агентов — **Nix-installed для бинарей, template-deployed
для конфигов, runtime-configured для ключей**. Ни один из трёх
агентов не хранит секреты на диске; они читают `~/.authinfo`
(или `~/.authinfo.gpg`) через
`~/.local/share/pro-nix/load-agent-env.sh`, который sourced из
`~/.profile`.

## Три агента

### `pi` (lukasl-dev/pi.nix)

Основной CLI. NixOS-модуль (`pi.nixosModules.default`) подключён
глобально в `configuration.nix`:

```nix
programs.pi.coding-agent = lib.mkIf (piPkg != null) {
  enable = lib.mkDefault true;
  package = lib.mkDefault piPkg;
  rules = lib.mkDefault "";
};
```

`pi` запускается через `pi-acp` (`svkozak/pi-acp` v0.0.27, собирается
через `nix/node-packages/pi-acp.nix`) для ACP-коммуникации. Полные
настройки — в `local-templates/pi/settings.json`:

```json
{
  "defaultProvider": "minimax",
  "defaultModel": "MiniMax-M3",
  "packages": [
    "npm:pi-mcp-adapter", "npm:pi-smart-fetch", "npm:pi-web-access",
    "npm:@spences10/pi-redact", "npm:@spences10/pi-recall",
    "npm:@gotgenes/pi-permission-system", "npm:pi-compass", "npm:pi-blueprint"
  ]
}
```

`pi-crew` и `pi-subagents` **намеренно исключены** — см.
`local-templates/pi/settings.json` для списка неподдерживаемых
multi-agent пакетов.

### `opencode`

Второй агент. npm-бинарь (`v1.15.10`), скачивается через
`nix/overlays/opencode-stub.nix` и `patchelf`'ится под NixOS-glibc.
Sandbox-вариант через `opencodeBwrap.homeManagerModules.default`
(Home Manager module от `michalrus/opencode-bwrap-nix`).

Конфиг в `local-templates/opencode/opencode.json` — те же 3
провайдера, что и в `pi`, те же MCP-серверы.

### `gptel` (Emacs-сторона LLM-клиента)

`emacs/base/modules/pro-ai.el` — это policy-слой поверх gptel:

* 3 провайдера из `emacs/base/modules/ai-models.json` (openrouter,
  siliconflow, aitunnel, плюс пользовательские override'ы).
* `pro-ai-backend` (по умолчанию `'aitunnel`) выбирает активный.
* `pro-ai-open-entry` (C-c a) открывает gptel-transient; пользователь
  выбирает модель.
* Carriage integration (`gnu-emacs-ru/carriage`): Org-mode
  «code knitting» workflow с dry-run/apply и воспроизводимостью.

## MCP — мост к Emacs

EMCP (Emacs MCP) — главная интеграция. Он выставляет работающую
Emacs-сессию как MCP-сервер, так что любой MCP-capable агент может
читать буферы, выполнять elisp, делать скриншоты, отправлять
клавиши.

| Сервер | Где работает | Что делает |
|--------|--------------|------------|
| `emcp` | Внутри Emacs, порт 38913 | Read/eval/send-keys/screenshot на живой сессии |
| `chrome-devtools` | `npx chrome-devtools-mcp@latest` (когда запущен) | Автоматизация браузера через Chrome DevTools Protocol |

Оба зарегистрированы и в `local-templates/pi/mcp.json`, и в
`local-templates/opencode/opencode.json`.

### Как `pi` вызывает emcp

`pi` маршрутизирует MCP через **прокси-тулзу**:

```
pi> mcp({tool: "emcp_apropos", args: {pattern: "pro-"}})
```

Это **единственный** способ, которым `pi` достигает MCP-тулзов —
прямого `emcp_apropos` в `pi` нет.

### Как `opencode` вызывает emcp

`opencode` выставляет MCP-тулзы **напрямую**:

```
opencode> emcp_apropos(pattern: "pro-")
```

MCP `tools/list` возвращает полный набор emcp.

### Policy-gate для `eval` / `send-keys`

Два emcp-тулза **опасны по умолчанию** и гейтнуты Emacs-side
политикой:

* `emcp_eval` — выполняет произвольный elisp в пользовательской
  сессии.
* `emcp_send_keys` — отправляет клавиатурную последовательность в
  пользовательскую сессию.

`emcp-tools-eval-default-policy` и
`emcp-tools-send-keys-default-policy` по умолчанию равны `'ask`.
Когда агент вызывает любой из них, Emacs открывает буфер
`*EMCP confirm*` с `y` / `n` / `a` (всегда принимать для сессии)
/ `r` (всегда отклонять для сессии) / `q` (отменить).

Гейт описан в деталях в
`local-templates/pi/skills/emacs-emcp/SKILL.md` и
`local-templates/opencode/skills/emacs-emcp/SKILL.md`.

## Permission-система

`local-templates/pi/extensions/pi-permission-system/config.json`
настраивает `@gotgenes/pi-permission-system`. Дефолты:

* `path`:
  * **deny** `.env*`, `secrets.*`, `*.pem`, `*.key`, `id_rsa*`,
    `id_ed25519*`, `~/.ssh/**`, `~/.aws/**`, `~/.gnupg/**`,
    `~/.pi/agent/auth.json`
  * **ask** `~/.pi/agent/models.json`
* `bash`:
  * **deny** `rm -rf *`, `rm -rf /*`, `dd *`, `mkfs*`, fork bomb,
    `chmod 777`, `curl|sh`, `wget|sh`, `git push --force`,
    `nix-collect-garbage -d`, `kill -9 1`, `reboot`, `shutdown`
  * **ask** `sudo *`, `chown *`, `git push *`, `nix-env *`, `systemctl *`
* `mcp`: `*` = allow
* `skill`: `*` = ask
* `external_directory`: ask

`yoloMode = false`, `debugLog = false`, `permissionReviewLog = true`.

## Skills

Два skill'а деплоятся и в `~/.pi/agent/skills/`, и в
`~/.config/opencode/skills/`:

| Skill | Файл | Назначение |
|-------|------|-----------|
| `emacs-emcp` | `local-templates/{pi,opencode}/skills/emacs-emcp/SKILL.md` | Operator guide для emcp MCP-сервера. Список тулов, policy gate, профиль `full-control`, troubleshooting. |
| `safe-bash` | `local-templates/pi/skills/safe-bash/SKILL.md` | Cross-platform shell safety. Read-only vs mutating классификация, destructive confirmation паттерны, Windows/Unix path conventions, signal handling, анти-паттерны. |

## Деплой `local-templates` → `$HOME`

`modules/pro-agent-configs.nix` определяет 6 копий файлов:

```
local-templates/opencode/opencode.json        → ~/.config/opencode/opencode.json
local-templates/opencode/skills/...          → ~/.config/opencode/skills/...
local-templates/pi/models.json               → ~/.pi/agent/models.json
local-templates/pi/mcp.json                  → ~/.pi/agent/mcp.json
local-templates/pi/settings.json             → ~/.pi/agent/settings.json
local-templates/pi/skills/...                → ~/.pi/agent/skills/...
```

Activation-скрипт использует
`install -m 0644 -o $(id -u) -g $(id -g)`, чтобы избежать
проблемы «файлы под root после sudo-активации». Семантика —
**copy-if-missing** — никогда не перезаписывает правки пользователя.

В `~/.profile` добавляется маркер-комментарий:

```
# pro-nix: load AI provider keys from authinfo
[ -f "$HOME/.local/share/pro-nix/load-agent-env.sh" ] && . "$HOME/.local/share/pro-nix/load-agent-env.sh"
```

Маркер идемпотентен — добавляется только если его ещё нет.

## Поверхность `just`

```bash
just deploy-agents            # скопировать local-templates в $HOME
just install-pi-packages      # pi install npm:<pkg> для каждого пакета в settings.json
just switch-with-agents <host>    # цепочка: deploy + install + switch
just update-pi-version       # bump pi в flake.lock (dry-run по умолчанию)
```

`deploy-agents.sh` — ручной эквивалент Nix-активации. Используйте
его на non-NixOS хосте или чтобы форсировать деплой.
