История изменений после безопасной точки
======================================

Базовая точка
- Safe commit: `b8a4e46`.
- Базовый разворот истории: `7661922`.
- Просмотрены все доступные refs: `main`, `origin/main`, `feature/development-20260429`, `restore/huawei-182`, `saved/after-huawei-319bcc5`, `opencode/session-20260430T095920Z`, `origin/feature/development-20260429`.

Удалённые ветки и что в них было
1. `feature/development-20260429`
   - `a4e2862` `chore(opencode): add helper script and doc section for worktree workflow`
   - `0d6b5d3` `docs: improve README and CONTRIBUTING text, clarify contracts and workflow`
   - `bbb639f` `docs: rewrite README and Change Gate template in CONTRIBUTING`
   - `6a309ef` `docs: clarify project and contribution docs`
   - Содержание: переписывание пользовательской и агентской документации, оформление Change Gate, worktree helper для opencode, фиксация контрактного слоя.

2. `restore/huawei-182`
   - `468c034` `boot-lab: prune duplicate tests, simplify firewall/package self-references, fix shell->writeShellScriptBin usage for opencode and tor helpers, tighten CI checks`
   - Содержание: чистка повторных тестов, упрощение ссылок на firewall/package self-references, приведение shell helper'ов к `writeShellScriptBin`, ужесточение CI.

3. `saved/after-huawei-319bcc5`
   - `319bcc5` `fix(huawei): сузить расследование и зафиксировать текущие правки ...`
   - Содержание: минимальная defensive-правка `Xresources -> store path`, обновление boot-smoke теста и безопасного wrapper'а для switch, убран ручной видимый VM-branch.

4. `opencode/session-20260430T095920Z`
   - `0d6b5d3` `docs: improve README and CONTRIBUTING text, clarify contracts and workflow`
   - Содержание: тот же слой документации и контрактов, но в отдельной рабочей сессии opencode; в linked worktree оставался untracked helper `scripts/create-opencode-branch.sh`.

Что происходило
1. Слой пакетов и runtime.
   - Серия коммитов вокруг `system-packages.nix`, `environment.systemPackages`, `lib.mkDefault` и `lib.mkForce`.
   - Ветки добавляли `agent-shell`, `acp`, `shell-maker`, `eldoc-box`, `treemacs-icons-dired`, а затем нормализовали зависимые обёртки и eval-поведение.
   - Итоговый риск: рекурсия/потеря runtime-пакетов при live switch.

   Подробный хвост по этому направлению:
   - `770a1ca` добавление `agent-shell` recipe.
   - `0ef6c31`, `021cff1`, `5e4e045`, `6039b20` связали `agent-shell` с `acp` и `shell-maker`.
   - `9b14d3c`, `a4711d0`, `05ada40`, `ecf6ca1`, `3b8c13f` закрепили пакетную и eval-политику для agent-shell/opencode.
   - `b77aa1c`, `6c3112d`, `79e0218`, `4fd6425`, `948f342`, `c08b0d2`, `b83a492`, `fe5d5ea`, `9712e10`, `1013865` собирали runtime list и устраняли рекурсию/потери базовых пакетов.

2. Скрипты и инфраструктура запуска.
   - Массовое переименование `scripts/*` в `dev-*`, `helper-*`, `ops-*`, `test-*`.
   - Появились compatibility wrappers для `switch`, `emacs-pro-wrapper`, headless ERT helpers и helper scripts для pro-peer/opencode.
   - Риск: разрыв между новыми именами и местами, где старые entrypoints ещё ожидались.

   Подробный хвост по скриптам:
   - `03d5197` запустил массовое semantic-renaming.
   - `12fc0bc`, `e27d3c8`, `ac11581`, `d75a46e`, `0699943` закрывали compatibility layer для `switch`, headless tests и renamed wrappers.
   - `a4bbae1`, `50314d5`, `db2142f`, `68e2a65` синхронизировали pro-peer и opencode script names с новыми путями.

3. Live activation и systemd.
   - Длинная серия исправлений для `helper-switch`, `dbus`, `polkit`, `tor`, `samba`, `avahi` и unit ordering.
   - Было несколько попыток убрать race conditions, корректировать `ExecStart`, использовать `writeShellScriptBin`, и тестировать поведение в VM/container.
   - Риск: switch/activation зависели от временного порядка перезапуска system bus и policy services.

   Подробный хвост по activation:
   - `f7ee2bb`, `ade4f8b`, `6b1e11c`, `d4f9c83`, `5d53306`, `96453c0` закрывали bus/polkit race и helper-switch retries.
   - `d137fd1`, `ecea0dd`, `ea65be6`, `7c6cb37` доводили `tor-ensure-*` и `ExecStart` paths до корректного состояния.
   - `c45bc40`, `e358854`, `eda3c83`, `9c755e7`, `b569da7`, `ef4d220`, `21b1ef5`, `31bb3f0`, `d050eb2` строили VM/container test ladder для воспроизведения и проверки switch.

4. Тесты и сценарии.
   - Добавлены и дорабатывались VM activation tests, container smoke, boot-smoke, shell wrappers и CI checks.
   - Часть правок была защитной и сопровождала уже найденные поломки, а не новые функциональные требования.

5. Документация и контрактный слой.
   - Переписывались README, CONTRIBUTING, Change Gate шаблоны, пояснения по toolchain и анализу.
   - Это фиксировало правила работы, но не снимало системные риски активации.

Финальная стабилизация
- Последний безопасный фикс: `b8a4e46`.
- Суть фикса: `environment.etc."X11/Xresources"` переведён на `builtins.readFile`, чтобы live activation не зависел от отсутствующего store path `...-Xresources`.
- Это закрыло конкретный сбой `nixos-rebuild switch` на `huawei`.

Сводка по удалённым/срезанным направлениям
- `feature/development-20260429` = документация, Change Gate, worktree tooling.
- `restore/huawei-182` = boot-lab cleanup и CI tightening.
- `saved/after-huawei-319bcc5` = huawei-specific live-activation fix, safe wrapper, boot-smoke update.
- `opencode/session-20260430T095920Z` = docs/workflow polish в отдельной сессии opencode.
- Всё это было исследовательской историей; в main оставлен только безопасный `b8a4e46`.

Паттерны неудач
- Смешивание сборочной логики и runtime-контрактов в одном месте.
- Избыточные цепочки `mkDefault`/`mkForce` без ясного владельца финального списка.
- Смена имен скриптов без полного выравнивания всех вызывающих мест.
- Исправление гонок systemd без unit-level проверки порядка зависимостей.

Что сохранять как знание
- Не полагаться на существование store path при activation, если он выводится из repository file; лучше materialize content deterministically.
- Для `environment.systemPackages` нужен один владелец финального списка.
- Любой switch-related fix должен иметь отдельный smoke path, а не только декларативный diff.

Вывод
- История после `7661922` представляет собой последовательную отладку одного кластера проблем.
- Безопасная точка для `main` — `b8a4e46`.
- Всё более позднее следует считать попытками исследования и не держать на основной ветке.

Приложение: неполный, но операционный список крупных коммитов
- Документы: `6a309ef`, `bbb639f`, `0d6b5d3`, `a4e2862`, `02cb84e`, `1d1cad6`, `386fcae`.
- Activation/systemd: `96453c0`, `5d53306`, `ade4f8b`, `6b1e11c`, `d4f9c83`, `d137fd1`, `ecea0dd`, `ea65be6`, `c45bc40`, `31bb3f0`, `d050eb2`, `7c6cb37`.
- Packages/runtime: `b83a492`, `fe5d5ea`, `9712e10`, `c08b0d2`, `948f342`, `4fd6425`, `79e0218`, `b77aa1c`, `6c3112d`, `3b8c13f`, `ecf6ca1`, `05ada40`, `9b14d3c`, `a4711d0`, `0f5a287`, `9339ed5`, `770a1ca`, `021cff1`, `5e4e045`, `6039b20`.
- Emacs/pro-packages: `9d2e8f5`, `62be63f`, `b08bf2f`, `f03bf04`, `d4497a5`, `cc68001`, `474d078`, `89fec08`, `131c929`, `27db972`, `5a0da41`, `4fc90a2`, `b332910`, `e4f8fb6`, `828ce32`, `90d9315`, `8b44113`, `685f1da`.
