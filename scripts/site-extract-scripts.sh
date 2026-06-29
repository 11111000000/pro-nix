#!/usr/bin/env bash
# Extract scripts/ and bin/ into a Zola-compatible reference table.
# Generates both en/ and ru/. Idempotent. Run via `just site-regen`.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SITE="$REPO/site/content"
TODAY="$(date -u +%Y-%m-%d)"

mkdir -p "$SITE/en/reference" "$SITE/ru/reference"

collect() {
  local dir="$1"
  local prefix="$2"
  local lang="$3"
  for f in "$dir"/*; do
    [ -f "$f" ] || continue
    name="$(basename "$f")"
    size="$(wc -c < "$f" | tr -d ' ')"
    lines="$(wc -l < "$f" | tr -d ' ')"
    shebang="$(head -1 "$f" | sed -n 's|^#!\(.*\)|\1|p')"
    desc="$(awk 'NR > 1 && !/^[[:space:]]*#/ && !/^[[:space:]]*$/ { sub(/^[[:space:]]+/, ""); print; exit }' "$f")"
    desc="$(echo "$desc" | head -c 120)"
    if [ "$lang" = "ru" ]; then
      # First-line translation map (very small; if a script's first line is
      # already English/Russian we leave it as-is).
      case "$desc" in
        "quick helper-switch"*) desc="быстрый helper-switch для активации перед switch" ;;
        "Apply nix"*)         desc="применить nix-конфиг" ;;
        "Build a host"*)      desc="собрать хост" ;;
        "deploy local"*)      desc="задеплоить локальные скрипты в ~/bin" ;;
        "Run"*)               desc="запустить (см. скрипт)" ;;
      esac
    fi
    echo "| \`${prefix}${name}\` | ${size} B / ${lines} LOC | \`${shebang:-}\` | ${desc} |"
  done
}

emit() {
  local lang="$1"
  local out="$SITE/$lang/reference/scripts.md"

  local TABLE_SCRIPTS TABLE_BIN
  TABLE_SCRIPTS="$(collect "$REPO/scripts" 'scripts/' "$lang")"
  TABLE_BIN="$(collect "$REPO/bin" 'bin/' "$lang")"
  local COUNT_SCRIPTS COUNT_BIN TOTAL
  COUNT_SCRIPTS="$(printf '%s\n' "$TABLE_SCRIPTS" | grep -c '| \`scripts/' 2>/dev/null)"
  COUNT_BIN="$(printf '%s\n' "$TABLE_BIN" | grep -c '| \`bin/' 2>/dev/null)"
  COUNT_SCRIPTS="${COUNT_SCRIPTS:-0}"
  COUNT_BIN="${COUNT_BIN:-0}"
  TOTAL=$((COUNT_SCRIPTS + COUNT_BIN))

  if [ "$lang" = "ru" ]; then
    cat > "$out" <<EOF
+++
title = "Скрипты"
sort_by = "weight"
template = "page.html"

[extra]
tldr = "Все ${TOTAL} shell-скриптов под scripts/ и bin/. Первая непустая строка каждого показана как one-line purpose."
+++

# Скрипты

<span class="gen-badge">auto-gen</span> Сгенерировано ${TODAY} из \`scripts/*\` и \`bin/*\`.

> pro-nix поставляет толстый слой операционного shell. Страница ниже — плоский каталог;
> чтобы понять *что* делает скрипт и *когда* его использовать, прочтите
> [Рабочий процесс → troubleshooting](@/workflow/troubleshoot.md) и
> отдельные workflow-страницы.

**Всего:** ${TOTAL} скриптов (${COUNT_SCRIPTS} в \`scripts/\`, ${COUNT_BIN} в \`bin/\`).

## bin/ (деплоится в \$HOME/bin через helper-switch.sh)

| Path | Size | Shebang | First-line purpose |
|------|------|---------|---------------------|
${TABLE_BIN}

## scripts/ (операционные хелперы)

| Path | Size | Shebang | First-line purpose |
|------|------|---------|---------------------|
${TABLE_SCRIPTS}

## Как использовать

- **Прямой вызов:** \`./scripts/helper-switch.sh huawei\`
- **Через \`just\`:** \`just <recipe>\` (см. [Рабочий процесс → just-рецепты](@/workflow/just.md))
- **Bootstrap integration:** \`just switch\` запускает \`helper-switch.sh\`,
  который деплоит всё в \`bin/\` в \`\$HOME/bin\` и добавляет эту
  директорию в \`PATH\` через \`~/.profile\`.

## Категории (по префиксу имени)

| Префикс | Группа | Примеры |
|---------|--------|---------|
| \`helper-*\` | Диагностика и одноразовые хелперы | \`helper-audio-diag.sh\`, \`helper-sysctl.sh\` |
| \`dev-*\` | Developer workflow | \`dev-emacs-sync.sh\`, \`dev-analyse.sh\`, \`dev-rename-modules-pro.sh\` |
| \`ops-*\` | Операции (production-y) | \`ops-ensure-tor.sh\`, \`ops-mount-smb.sh\`, \`ops-pro-samba-setup-users.sh\` |
| \`test-*\` | Test runners | \`test-emacs-headless.sh\`, \`test-minimal-e2e.sh\` |
| \`run-*\` | Прямые вызовы | \`run-basic-test.sh\`, \`run_via_torsocks.sh\` |
| \`pro-*\` | Top-level user-facing CLI | \`pro-tor\`, \`pro-load-agent-env.sh\` (source) |
| \`update-*\` | Updaters | \`update-pi-version.sh\` |
| \`safe-*\` | Безопасные обёртки | \`safe-switch.sh\`, \`safe-mktemp\` |
| \`verify-*\` | CI / smoke-проверки | \`verify-units.sh\` |
| \`collect-*\` | Сборщики логов / инфо | \`collect-switch-logs.sh\` |
| \`sync-*\` | Синхронизаторы state | \`sync-submodules.sh\` |
| \`install-*\` | Одноразовые установщики | \`install-pi-packages.sh\` |
| \`deploy-*\` | Деплоеры конфигов | \`deploy-agent-configs.sh\` |
| \`emacs-*\` | Emacs test harnesses | \`emacs-headless-test.sh\`, \`emacs-verify.sh\` |
| \`vm-*\` | VM-specific runners | \`vm-switch-loop.sh\` |
| \`agent-*\` | Agent conventions | \`agent-conventions-check.sh\` |
EOF
  else
    cat > "$out" <<EOF
+++
title = "Scripts"
sort_by = "weight"
template = "page.html"

[extra]
tldr = "All ${TOTAL} shell scripts under scripts/ and bin/. The first non-comment line of each is shown as the one-line purpose."
+++

# Scripts

<span class="gen-badge">auto-gen</span> Generated ${TODAY} from \`scripts/*\` and \`bin/*\`.

> pro-nix ships a thick layer of operational shell. The page below is a flat catalogue —
> to understand *what* a script does and *when* to use it, read the
> [Workflow → troubleshooting](@/workflow/troubleshoot.md) and the
> individual workflow pages.

**Total:** ${TOTAL} scripts (${COUNT_SCRIPTS} in \`scripts/\`, ${COUNT_BIN} in \`bin/\`).

## bin/ (deployed to \$HOME/bin by helper-switch.sh)

| Path | Size | Shebang | First-line purpose |
|------|------|---------|---------------------|
${TABLE_BIN}

## scripts/ (operational helpers)

| Path | Size | Shebang | First-line purpose |
|------|------|---------|---------------------|
${TABLE_SCRIPTS}

## How to use

- **Direct invocation:** \`./scripts/helper-switch.sh huawei\`
- **Through \`just\`:** \`just <recipe>\` (see [Workflow → just recipes](@/workflow/just.md))
- **Bootstrap integration:** \`just switch\` runs \`helper-switch.sh\` which
  deploys everything in \`bin/\` to \`\$HOME/bin\` and adds that directory to
  \`PATH\` in \`~/.profile\`.

## Categories (by name prefix)

| Prefix | Group | Examples |
|--------|-------|----------|
| \`helper-*\` | Diagnostic and one-shot helpers | \`helper-audio-diag.sh\`, \`helper-sysctl.sh\` |
| \`dev-*\` | Developer workflow | \`dev-emacs-sync.sh\`, \`dev-analyse.sh\`, \`dev-rename-modules-pro.sh\` |
| \`ops-*\` | Operations (production-y) | \`ops-ensure-tor.sh\`, \`ops-mount-smb.sh\`, \`ops-pro-samba-setup-users.sh\` |
| \`test-*\` | Test runners | \`test-emacs-headless.sh\`, \`test-minimal-e2e.sh\` |
| \`run-*\` | Direct invocations | \`run-basic-test.sh\`, \`run_via_torsocks.sh\` |
| \`pro-*\` | Top-level user-facing CLIs | \`pro-tor\`, \`pro-load-agent-env.sh\` (sourced) |
| \`update-*\` | Updaters | \`update-pi-version.sh\` |
| \`safe-*\` | Safer wrappers | \`safe-switch.sh\`, \`safe-mktemp\` |
| \`verify-*\` | CI / smoke verifications | \`verify-units.sh\` |
| \`collect-*\` | Log / info collectors | \`collect-switch-logs.sh\` |
| \`sync-*\` | State synchronizers | \`sync-submodules.sh\` |
| \`install-*\` | One-shot installers | \`install-pi-packages.sh\` |
| \`deploy-*\` | Config deployers | \`deploy-agent-configs.sh\` |
| \`emacs-*\` | Emacs test harnesses | \`emacs-headless-test.sh\`, \`emacs-verify.sh\` |
| \`vm-*\` | VM-specific runners | \`vm-switch-loop.sh\` |
| \`agent-*\` | Agent conventions | \`agent-conventions-check.sh\` |
EOF
  fi

  echo "wrote $out (${TOTAL} scripts, $lang)"
}

emit en
emit ru
