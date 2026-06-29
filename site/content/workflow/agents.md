+++
title = "Агенты"
template = "page.html"
weight = 4

[extra]
tldr = "just deploy-agents запускает deploy-agent-configs.sh + install-pi-packages.sh. Семантика copy_if_missing. Цепочка ~/.authinfo → ~/.profile экспортирует AITUNNEL_KEY, OPENROUTER_KEY, OPENAI_API_KEY, MISTRAL_API_KEY, MINIMAX_API_KEY, DEEPSEEK_API_KEY."

[[extra.next]]
title = "Клавиши"
url = "/workflow/keys/"

[[extra.next]]
title = "Soft-reload"
url = "/workflow/reload/"
+++

# Агенты

Слой агентов деплоится через `just deploy-agents`. Два скрипта за
ним — зеркальные отражения NixOS-активации
(`modules/pro-agent-configs.nix`): скрипт — ручной эквивалент для
non-NixOS хостов и форсированных re-deploy'ов.

## Поверхность деплоя

`modules/pro-agent-configs.nix` определяет 6 копий файлов:

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

Плюс `home.file.".local/share/pro-nix/load-agent-env.sh"`
executable, который sourced из `~/.profile` (тоже добавляется
активацией).

`scripts/deploy-agent-configs.sh` дублирует все 6 копий плюс
деревья skills (`emacs-emcp` и `safe-bash`) плюс проектно-локальный
`$PWD/.pi/{models,opencode}.json`, если `$PWD/.pi/` не существует.

## Семантика `copy_if_missing`

Активация и скрипт используют **copy-if-missing**:

* Если файл назначения не существует — установить его через
  `install -m 0644 -o $(id -u) -g $(id -g) <src> <dst>`.
* Если файл назначения существует — ничего не делать.
* Назначение **никогда** не перезаписывается.

Это поддерживается логикой скрипта:

```bash
copy_if_missing() {
  if [ ! -e "$dst" ]; then
    install -m 0644 -o "$(id -u)" -g "$(id -g)" "$src" "$dst" \
      || cp "$src" "$dst" \
      || echo "WARN: cannot install $dst"
  fi
}
```

Чтобы форсировать re-deploy:

```bash
rm ~/.config/opencode/opencode.json
just deploy-agents
```

Скрипт также имеет fallback на голый `cp` (без chown) для случаев,
когда `install` недоступен. chown — важная деталь — он
предотвращает проблему «файл под root после sudo-активации»,
которая ломает `pi` (который отказывается перезаписывать свой
собственный `models.json`, если он не user-owned).

## Инвариант `~/.pi/agent/auth.json`

`pi` создаёт `~/.pi/agent/auth.json` при первом запуске. Файл в
**deny**-листе permission-системы
(`local-templates/pi/extensions/pi-permission-system/config.json`):

```json
"path": {
  "deny": ["~/.pi/agent/auth.json", ...]
}
```

Скрипт деплоя **никогда** не пишет в `auth.json`. Это чисто файл
агента. Деплой оставляет его нетронутым.

## `just install-pi-packages`

После того как шаблоны на месте, `just install-pi-packages`
запускает `scripts/install-pi-packages.sh`:

1. Находит `pi` в `$PATH`. Если нет — быстрый fail.
2. Читает `~/.pi/agent/settings.json` (деплоированный, не шаблон
   — пользователь мог отредактировать). Откатывается на шаблон,
   если деплоированный отсутствует.
3. Парсит массив `packages` через `python3 -c "import json; ..."`.
4. Для каждого `npm:` пакета запускает `pi install npm:<pkg>`.
5. Агрегирует ошибки. `exit 0`, если все ок, `exit 1` иначе.

Флаг `--dry-run` печатает команды без выполнения.

`pi install` сам идемпотентен: повторный запуск после успешной
установки просто обновляет `settings.json` (no-op для уже
установленных пакетов).

## Auth-цепочка: `~/.authinfo` → `load-agent-env.sh`

`home.file.".local/share/pro-nix/load-agent-env.sh"`
executable — это **тот** скрипт, который грузит секреты. Он
читает `~/.authinfo` (или `~/.authinfo.gpg`, если он есть и `gpg`
доступен), парсит authinfo-формат и экспортирует env-переменные,
на которые ссылаются шаблоны.

### Карта

```bash
declare -A _pro_agent_targets=(
  ["api.aitunnel.ru:token"]="AITUNNEL_KEY AITUNNEL_API_KEY"
  ["openrouter.ai:token"]="OPENROUTER_KEY OPENROUTER_API_KEY"
  ["api.openai.com:openai"]="OPENAI_API_KEY"
  ["api.mistral.ai:token"]="MISTRAL_API_KEY MISTRAL_API_KEY"
  ["api.minimax.io:token"]="MINIMAX_API_KEY MINIMAX_KEY"
  ["api.deepseek.com:token"]="DEEPSEEK_API_KEY DEEPSEEK_KEY"
)
```

Каждый ключ `host:user` в authinfo-файле мапится в **одну или две
env-переменных**. Скрипт:

1. Читает authinfo построчно.
2. Для каждой тройки `machine X login Y password Z` ищет
   `_pro_agent_targets[X:Y]`.
3. Если нашёл — экспортирует env-переменные (пропускает, если
   первая уже установлена — «first wins»).
4. Убирает temp GPG-выход, если использовался.

### GGP-режим

Если `~/.authinfo.gpg` существует и `gpg` доступен, скрипт:

```bash
_authinfo_path="$(mktemp)"
trap "rm -f '$_authinfo_path'" EXIT
gpg --quiet --batch --decrypt "$HOME/.authinfo.gpg" > "$_authinfo_path" 2>/dev/null
```

Temp-файл `0600`, принадлежит текущему пользователю, удаляется на
EXIT. GPG-prompt для парольной фразы приходит от агента
(`gpg-agent`).

### Идемпотентность

Скрипт защищает себя через `PRO_AGENT_ENV_LOADED`:

```bash
[ -n "${PRO_AGENT_ENV_LOADED:-}" ] && return 0 2>/dev/null || true
[ -n "${PRO_AGENT_ENV_LOADED:-}" ] && exit 0
...
export PRO_AGENT_ENV_LOADED=1
```

Source-ить файл дважды в той же shell-сессии — no-op.

## Строка в `~/.profile`

Активация добавляет это в `~/.profile`:

```bash
# pro-nix: load AI provider keys from authinfo
[ -f "$HOME/.local/share/pro-nix/load-agent-env.sh" ] && . "$HOME/.local/share/pro-nix/load-agent-env.sh"
```

Маркер (`# pro-nix: load AI provider keys from authinfo`) делает
append идемпотентным — активация добавляет строку, только если
маркер ещё не присутствует. Гард `[ -f ... ]` означает, что source-строка
тихо пропускается, если скрипт отсутствует (это было бы только
на non-NixOS хосте, который не запускал `just deploy-agents`).

## MCP-серверы — что регистрируется

`local-templates/pi/mcp.json` и
`local-templates/opencode/opencode.json` оба имеют:

```json
{
  "mcpServers": {
    "chrome-devtools": {
      "command": "npx",
      "args": ["-y", "chrome-devtools-mcp@latest", "--browser-url=http://127.0.0.1:9222"],
      "directTools": true,
      "lifecycle": "keep-alive"
    },
    "emcp": {
      "url": "http://127.0.0.1:38913/mcp"
    }
  }
}
```

Деплой — прямое копирование. Пользователь может редактировать
деплоированную копию, чтобы добавить больше MCP-серверов, и
деплой не перезапишет (copy_if_missing).

## Поток `deploy-agents`

```
just deploy-agents
  └── scripts/deploy-agent-configs.sh
       ├── copy_if_missing opencode/opencode.json → ~/.config/opencode/
       ├── copy_tree_if_missing opencode/skills/ → ~/.config/opencode/skills/
       ├── copy_if_missing pi/models.json → ~/.pi/agent/
       ├── copy_if_missing pi/mcp.json → ~/.pi/agent/
       ├── copy_if_missing pi/settings.json → ~/.pi/agent/
       ├── copy_tree_if_missing pi/skills/ → ~/.pi/agent/skills/
       ├── (проектно-локально) copy_if_missing $PWD/.pi/models.json
       └── (проектно-локально) copy_if_missing $PWD/.pi/opencode.json
  └── scripts/install-pi-packages.sh
       └── pi install npm:<pkg> для каждого пакета в settings.json
```

Первый деплой на свежем хосте **медленный** (npm install для
каждого пакета). Последующие деплои **быстрые** (no-op).

## Полная цепочка для нового хоста

```bash
# На новом хосте
git clone https://github.com/11111000000/pro-nix
cd pro-nix
git submodule update --init --recursive
sudo just switch <host>             # загружает NixOS-конфиг
just deploy-agents                  # шаблоны + npm
emacsclient -e '(pro-emcp-server-start)'   # стартует emcp-сервер
pi -p 'mcp({})'                       # должно показать 2/2 сервера
```

Если `pi -p 'mcp({})'` показывает `0/2`, EMCP не стартовал. См.
[Troubleshooting](workflow/troubleshoot.md).
