+++
title = "Стек AI-агентов"
template = "page.html"
weight = 5

[extra]
tldr = "pi + opencode + EMCP + gptel + pi-acp. Пять частей: Nix-установленные бинари, деплоенные шаблоны, MCP-серверы, skills, permission-система. Связаны через ~/.authinfo + load-agent-env.sh."

[[extra.next]]
title = "Сетевые слои"
url = "/architecture/network/"

[[extra.next]]
title = "Слой AI-агентов"
url = "/stack/ai/"
+++

# Стек AI-агентов

Слой агентов — **самый молодой** в проекте и чаще всего меняется.
У него пять частей, которые композируются:

1. **Бинари** — установлены Nix'ом (pi, pi-acp, opencode).
2. **Шаблоны** — source of truth в `local-templates/`, деплоятся в
   `$HOME` через `pro-agent-configs.nix`.
3. **MCP-серверы** — `emcp` (Emacs) и `chrome-devtools` (браузер).
4. **Skills** — оператор-гайды, которые агент подгружает по
   запросу.
5. **Permission-система** — deny-by-pattern дефолты, гейтящие
   опасные операции.

## 1. Бинари

| Бинарь | Источник | Как собирается | Куда попадает |
|--------|----------|----------------|---------------|
| `pi` | `lukasl-dev/pi.nix` (через `pi.packages.x86_64-linux.coding-agent`) | Upstream Nix-пакет | `/run/current-system/sw/bin/pi` |
| `pi-acp` | `nix/node-packages/pi-acp.nix` (svkozak/pi-acp v0.0.27) | `buildNpmPackage` с Node 20, `npmDepsHash` запинен | `/run/current-system/sw/bin/pi-acp` |
| `opencode` | `nix/overlays/opencode-stub.nix` | `fetchurl` npm-tarball + `patchelf` под glibc | `/run/current-system/sw/bin/opencode` |
| `opencode-bwrap` | `opencodeBwrap.homeManagerModules.default` | HM-модуль оборачивает `opencode` в bwrap-sandbox | `~/.local/bin/opencode` (per user) |
| `gptel` (в Emacs) | `pkgs.emacsPackages.gptel` | MELPA-сборка | `share/emacs/site-lisp/.../gptel*.el` |
| `emcp` (в Emacs) | `nix/emacs-recipes/emcp.nix` | Тривиальный `cp` сабмодуля | `share/emacs/site-lisp/emcp/emcp.el` |
| `http-server` (в Emacs) | `nix/emacs-recipes/http-server.nix` | Тривиальный `cp` upstream-форка | `share/emacs/site-lisp/http-server/...` |

`pi` и `pi-acp` запускаются как `pi-acp` — npm-пакет оборачивает
бинарь в ACP-протокол. `opencode` запускается напрямую (или через
bwrap-обёртку, если `programs.opencode-bwrap.enable = true` для
пользователя).

## 2. Шаблоны

`local-templates/` — **единственный источник правды** для
агентских конфигов. Два поддерева:

```
local-templates/
├── opencode/
│   ├── opencode.json
│   └── skills/
│       └── emacs-emcp/
│           └── SKILL.md
└── pi/
    ├── extensions/
    │   └── pi-permission-system/
    │       └── config.json
    ├── mcp.json
    ├── models.json
    ├── settings.json
    └── skills/
        ├── emacs-emcp/
        │   └── SKILL.md
        └── safe-bash/
            └── SKILL.md
```

Деплой в `modules/pro-agent-configs.nix`:

```nix
templateFiles = [
  { src = "local-templates/opencode/opencode.json";     dst = ".config/opencode/opencode.json"; }
  { src = "local-templates/pi/models.json";             dst = ".pi/agent/models.json"; }
  { src = "local-templates/pi/mcp.json";                dst = ".pi/agent/mcp.json"; }
  { src = "local-templates/pi/settings.json";           dst = ".pi/agent/settings.json"; }
  { src = "local-templates/pi/skills/emacs-emcp/SKILL.md"; dst = ".pi/agent/skills/emacs-emcp/SKILL.md"; }
  { src = "local-templates/opencode/skills/emacs-emcp/SKILL.md"; dst = ".config/opencode/skills/emacs-emcp/SKILL.md"; }
];
```

Activation-скрипт использует
`install -m 0644 -o $(id -u) -g $(id -g)`, чтобы избежать
root-owned файлов после sudo-активации, и `copy_if_missing`,
чтобы никогда не перезаписывать user-правки.

Второй activation добавляет в `~/.profile`:

```
# pro-nix: load AI provider keys from authinfo
[ -f "$HOME/.local/share/pro-nix/load-agent-env.sh" ] && . "$HOME/.local/share/pro-nix/load-agent-env.sh"
```

Маркер идемпотентен — добавляется только если его нет.

Шаг деплоя дублируется в `scripts/deploy-agent-configs.sh` для
non-NixOS хостов и форсированных re-deploy'ов. `just deploy-agents`
запускает и скрипт, и `install-pi-packages.sh`.

## 3. MCP-серверы

Два MCP-сервера зарегистрированы и в `pi/mcp.json`, и в
`opencode/opencode.json`:

### `emcp`

HTTP MCP-сервер, который живёт внутри Emacs на
`http://127.0.0.1:38913/mcp`. Сервер стартует через `pro-emcp.el`
(по умолчанию `pro-emcp-server-auto-start = t`):

* На `after-init-hook` запускается `pro-emcp--auto-start-fn`.
* Проверяет наличие пакета `emcp`; если нет — тихо отступает.
* Иначе `(require 'emcp)` и `emcp-server-start`.
* Сервер биндится на `127.0.0.1:38913` (только loopback — никогда
  не выставляется наружу).
* Профиль по умолчанию — `'full-control` (inspect +
  get/set-variable + screenshot + eval + send-keys).

`emcp-tools-eval-default-policy` и
`emcp-tools-send-keys-default-policy` по умолчанию `'ask`. Когда
агент вызывает `emcp_eval` или `emcp_send_keys`, Emacs открывает
буфер `*EMCP confirm*` с запросом, и пользователь выбирает
`y` / `n` / `a` / `r` / `q`.

MCP-транспорт — это пакет `http-server` (тоже форк от того же
автора, что и `emcp` — `martenlienen`).

### `chrome-devtools`

```json
{
  "command": "npx",
  "args": ["-y", "chrome-devtools-mcp@latest", "--browser-url=http://127.0.0.1:9222"],
  "directTools": true,
  "lifecycle": "keep-alive"
}
```

Живёт только на хосте, где запущен Chrome / Chromium с
`--remote-debugging-port=9222`. pro-nix не стартует Chrome
автоматически; пользователь запускает его, когда нужно:

```bash
google-chrome-stable --remote-debugging-port=9222
```

Когда сервер достижим, агент может навигировать, кликать, делать
скриншоты и выполнять JS в браузере.

### Как `pi` достигает MCP-тулза

`pi` **не** выставляет MCP-тулзы напрямую. Используется
**прокси-тулз**:

```
pi> mcp({tool: "emcp_apropos", args: {pattern: "pro-"}})
```

Тулз `mcp` регистрируется через `pi-mcp-adapter`
(`local-templates/pi/settings.json#packages`). Агент вызывает его
с `{tool: ..., args: ...}`, адаптер маршрутизирует в правильный
сервер, и ответ возвращается агенту.

### Как `opencode` достигает MCP-тулза

`opencode` выставляет MCP-тулзы **напрямую**, как будто они часть
его собственного списка тулов:

```
opencode> emcp_apropos(pattern: "pro-")
```

MCP `tools/list` опрашивается при старте; тулы добавляются к
нативной surface function-calling агента.

> Асимметрия — известная шероховатость. Skill `emacs-emcp`
> отмечает обе конвенции вызова явно.

## 4. Skills

Skills — Markdown-файлы, которые агент подгружает по запросу.
Механизм одинаков в обоих агентах (файл `SKILL.md` в подкаталоге
`skills/`). pro-nix поставляет два:

### `emacs-emcp`

`local-templates/{pi,opencode}/skills/emacs-emcp/SKILL.md` (137/123
строк).

Покрывает:

* **Как проверить, что сервер жив** — `curl -fsS
  http://127.0.0.1:38913/mcp` с запросом `initialize`.
* **Профиль `full-control`** — таблица тулов: `apropos`, `describe`,
  `find-definition`, `find-references`, `info-search`,
  `get-variable`, `set-variable`, `screenshot`, `eval`,
  `send-keys`. Плюс resource `info://{manual}/{node}` и prompt
  `/screenshot`.
* **Типичные сценарии** — «проверить, что функция определена»,
  «понять, почему конфиг ведёт себя странно», «проверить визуальное
  состояние», «безопасно поправить конфиг».
* **Безопасность** — `eval` и `send-keys` гейтнуты политикой;
  агент должен ждать выбора пользователя `y` / `n` / `a` / `r` /
  `q`.
* **Troubleshooting** — когда `emcp` не виден в `pi`, запустите
  `emacsclient -e '(pro-emcp-server-start)'`.

Версия для `pi` имеет YAML-frontmatter (`name`, `description`);
версия для `opencode` — нет (opencode находит skills по структуре
каталога, а не по frontmatter).

### `safe-bash`

`local-templates/pi/skills/safe-bash/SKILL.md` (307 строк, только
в `pi` — opencode имеет свой собственный shell-тулз).

Покрывает:

* **Классификация** — каждая shell-команда либо *read-only*, либо
  *mutating*. Всегда сообщайте какая.
* **Кросс-платформенные нюансы** — Windows vs Unix-пути, `argv` vs
  `cmd /c`, детекция пакетного менеджера (npm/pnpm/yarn).
* **Heredoc и кавычки**.
* **Sudo и `expect`** — правила использования `sudo` в скриптах и
  тула `expect`.
* **Подтверждение деструктивных действий** — паттерны запроса
  перед `rm -rf`, `git push --force` и т.п.

Skill подгружается `pi` автоматически, когда агент начинает
работу над задачей, затрагивающей shell-команды.

## 5. Permission-система

`local-templates/pi/extensions/pi-permission-system/config.json`
настраивает `@gotgenes/pi-permission-system`. Дефолты —
**deny-by-pattern** для самых деструктивных операций:

### `path`

* **deny**: `.env*`, `secrets.*`, `*.pem`, `*.key`, `id_rsa*`,
  `id_ed25519*`, `~/.ssh/**`, `~/.aws/**`, `~/.gnupg/**`,
  `~/.pi/agent/auth.json`
* **ask**: `~/.pi/agent/models.json`

### `bash`

* **deny**: `rm -rf *`, `rm -rf /*`, `dd *`, `mkfs*`, fork bomb,
  `chmod 777`, `curl|sh`, `wget|sh`, `git push --force`,
  `nix-collect-garbage -d`, `kill -9 1`, `reboot`, `shutdown`
* **ask**: `sudo *`, `chown *`, `git push *`, `nix-env *`,
  `systemctl *`

### `mcp` / `skill` / `external_directory`

* `mcp *` — allow
* `skill *` — ask
* `external_directory` — ask

`yoloMode = false`, `debugLog = false`,
`permissionReviewLog = true`.

У `opencode` — своя permission-система, настраиваемая через
`opencode.json`. Шаблон pro-nix оставляет её permissive по
умолчанию — пользователь настраивает свои правила.

## End-to-end flow

Когда пользователь запускает
`pi -p "fix the typo on line 42 of main.py"`:

1. `pi` резолвит сообщение в ACP-запрос.
2. Запускается `pi-acp`; он говорит на ACP с бэкендом агента.
3. Бэкенд — gptel-style (удалённый LLM с тулами).
4. Список тулов включает `mcp({tool, args})` (проксируемый) плюс
   собственные тулы агента (read-file, write-file, run-shell).
5. LLM решает вызвать
   `mcp({tool: "emcp_apropos", args: {pattern: "pro-"}})`.
6. `pi-mcp-adapter` маршрутизирует вызов в `emcp` (HTTP на 38913).
7. `emcp` (внутри Emacs) выполняет `apropos "pro-"` в живой
   Emacs-сессии.
8. Результат возвращается LLM.
9. LLM продолжает, в итоге вызывает `shell.run` для исправления
   опечатки.
10. Shell-команда проходит через `bash`-правила permission'а
    (deny-by-pattern), и skill `safe-bash` подгружается по запросу.
11. Результат форматируется и возвращается пользователю.

Тот же flow работает для `opencode`, за исключением того, что
MCP-тулзы вызываются напрямую (не через прокси `mcp`).

## Матрица деплоя

| Где | Что |
|-----|-----|
| NixOS-активация | `home.activation.pro-agent-configs-deploy` (HM-owned) |
| `just deploy-agents` | `scripts/deploy-agent-configs.sh` + `scripts/install-pi-packages.sh` |
| `just switch-with-agents <host>` | switch + deploy + install в одной команде |
| Вручную | `cp local-templates/{pi,opencode}/* ~/.config/...` |

`deploy-agents.sh` — `copy_if_missing` — безопасно запускать
многократно. `install-pi-packages.sh` идемпотентен (re-run
обновляет `settings.json` только если список пакетов изменился).
