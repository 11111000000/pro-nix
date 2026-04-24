Цель
------
Наша цель — иметь систему для локальной оркестрации разных агентов разработки. Приоритет: агенты и сопутствующие сервисы должны быть корректно настроены и управляемы в NixOS, при этом окружение разработки и инфраструктура должны оставаться воспроизводимыми и управляемыми через Nix (flakes/devshell/модули).

Диалектический анализ
---------------------
Тезис — что хотим сделать
1. Полностью воспроизводимая среда для запуска агентов (LLM-бэкенды, orchestration, UI/CLI).
2. Интеграция управления на уровне NixOS (systemd-сервисы / modules) для долговременного запуска агентов.
3. Удобные per-project devshell'ы для разработки и тестирования агентов.
4. Опциональная контейнеризация / кластеризация (podman/docker / k3s) для изоляции и масштабирования.

Антитезис — проблемы и ограничения
1. Сложность стека: Nix-пакеты для bleeding-edge LLM-инструментов часто отстают, бинарные релизы и драйверы GPU подставляют таймлайны.
2. Аппаратные зависимости: GPU/CUDA/ROCm требуют ядровых модулей и проприетарных библиотек — это ломает чистую воспроизводимость.
3. Контейнеризация vs systemd: контейнеры дают изоляцию, но добавляют уровень управления и сетевых сложностей; systemd — проще, но менее переносим (тяжело мигрировать между хостами).
4. Безопасность и секреты: агенты часто нуждаются в API-ключах; хранить их в flake/nixos конфиге недопустимо.

Синтез — рекомендованная архитектура для NixOS (итог)
1. Базовая идея: сочетание NixOS modules (systemd) + контейнеров для отдельных агентов + devshell/flakes для локальной разработки.
2. Минимально необходимый стек:
   - Nix flakes как репозиторный контракт (flake.lock + outputs.devShells)
   - devshell (или flakes devShells) для per-project reproducible shells
   - services.podman.enable = true (rootless контейнеры) для запуска контейнеризованных агенто-компонентов
   - systemd-сервисы, управляемые через NixOS, для долгоживущих агентов/шлюзов (фронтэнд, agent-manager)
   - опция: k3s (services.k3s.enable = true) если нужна оркестрация Kubernetes для сложных сценариев
   - отдельный secrets-provider (pass, gpg, vault) — не хранить ключи в репозитории

Практические рекомендации и примеры конфигурации
1) Включить Podman в NixOS (rootless контейнеры, простая интеграция):

```nix
{ config, pkgs, ... }:

{
  services.podman = {
    enable = true;
    # optional: provide storage or registry settings here
  };
}
```

2) Простой systemd-сервис через NixOS для локального агента (Python script / binary):

```nix
systemd.services.agent-example = {
  description = "Local developer agent";
  wantedBy = [ "multi-user.target" ];
  serviceConfig = {
    ExecStart = "/run/current-system/sw/bin/python3 /opt/agents/agent_example/main.py";
    Restart = "on-failure";
    Environment = "ENV=production"; # но секреты хранить не здесь
  };
  install.wantedBy = [ "multi-user.target" ];
};
```

3) devShell / flake: дать reproducible shell для разработки и тестов

Простой фрагмент flake.outputs:

```nix
outputs = { self, nixpkgs, devshell }: {
  devShells.x86_64-linux.default = devshell.mkShell {
    packages = with nixpkgs.legacyPackages.x86_64-linux; [ python3 python3Packages.pip poetry podman ];
    shellHook = ''
      echo "Dev shell ready"
    '';
  };
};
```

4) k3s как опция для локального кластера (использовать когда):
- нужно распределённое discovery, service mesh, масштабирование агентов; подходит для тестирования production-like topologies.
- минусы: большая поверхность для ошибок, время старта, инициализация persistent volumes.

5) GPU и нативные библиотеки
- пакеты вроде text-generation-webui, llama.cpp, vllm, gpt4all часто имеют готовые nix derivations, но драйверы GPU/ CUDA лучше устанавливать системно и держать вне публичного flake. Тестировать fallback на CPU.

Безопасность и секреты
- НЕ помещать секреты в repo/flake. Использовать:
  - systemd-creds + environment file с root-only правами, или
  - HashiCorp Vault / pass / gpg-agent, или
  - podman secrets / tempfiles, интегрируя через systemd unit secrets files.

Верификация и тесты
- Smoke test: systemd unit стартует и проходит healthcheck (HTTP / Unix socket).
- Contract tests: for a [FROZEN] surface item — добавить простой HTTP health endpoint и e2e test, запускаемый в devShell (make test).

Операционная логистика (рабочий процесс)
1. Реализовать flake + devShells в корне проекта.
2. Упаковать agent'ы в derivation'ы (или контейнерные образы через nix-build && podman load).
3. Для long-running служб — добавить systemd.services.* в NixOS конфиг.
4. Для экспериментов — поднимать агента внутри podman контейнера из devShell (podman run --rm ...).

Риски и ограничения
- Воспроизводимость может быть нарушена проприетарными драйверами GPU и бинарными релизами.
- Kubernetes даёт мощь, но добавляет сложность: рекомендую вводить его только при реальной необходимости мульти-нодовой оркестрации.

Следующие шаги (practical)
1. Создать flake skeleton и devShell в репозитории: outputs.devShells.default.
2. Прописать systemd-сервис для одного reference-agent'а и smoke test.
3. Добавить docs/SURFACE.md (описать public promises: health/version/agent-protocol).
4. Решить, где храним секреты (Vault vs gpg/pass) и оформить инструкции в docs/ops.md.

Заключение
-----------
Оптимальный путь для локальной оркестрации агентов на NixOS — это сочетание flakes + devshell для воспроизводимости, podman для контейнерной изоляции и systemd/NixOS-modules для устойчивого запуска. k3s/ Kubernetes вводить только при реальной потребности в распределении; GPU-слой держать отдельно от публичного flake и документировать процесс установки драйверов и проверок.

Что мы упускали ранее
---------------------
1. Оркестрация агентов и запуск окружения - не одно и то же.
   - Среда разработки должна быть воспроизводимой.
   - Но сама оркестрация требует отдельного слоя: очередь задач, ретраи, таймауты, отмена, маршрутизация, наблюдение за состоянием.
   - Иначе система сводится к "набору shell'ов", а не к оркестратору.

2. Модельный слой и агентный слой надо разводить.
   - Агенты - это не только код, но и доступ к model-serving: локальные LLM, embeddings, rerankers, tool-use, memory.
   - Если всё тащить в один сервис, получится хрупкий комбайн.
   - Практически нужен отдельный контракт для model backend, отдельный для agent runtime.

3. Нужны наблюдаемость и диагностика.
   - Без метрик, логов, трассировки, health/readiness невозможно понять, где ломается цепочка.
   - Для локальной системы это особенно важно: сбой часто маскируется под "модель тупит".
   - Минимум: structured logs, per-agent health endpoint, process supervision, event journal.

4. Нужна модель доверия и идентичности.
   - Каждый агент должен иметь явный identity, scopes и policy boundaries.
   - Иначе инструментальный доступ превращается в неуправляемый риск.
   - Это особенно важно, если агенты могут читать репозиторий, запускать shell, менять конфиги или дергать сеть.

5. Секреты нельзя сводить только к "файлу с переменной".
   - Нужен lifecycle секретов: выдача, ротация, отзыв, audit.
   - Для NixOS это обычно означает внешний secrets manager или системную схему типа sops-nix / age / operator-managed secret store.

6. Нужен выбор между shell-first и service-first UX.
   - Shell-first: direnv / devshell / devenv / nix develop, удобно для интерактивной работы.
   - Service-first: NixOS units, podman, deploy-rs, удобнее для устойчивых долгоживущих процессов.
   - На практике нужен гибрид.

7. Нужен явный слой deployment.
   - Для NixOS локально достаточно `nixos-rebuild`.
   - Но если будут несколько машин, нужен deploy tooling: `deploy-rs` сейчас выглядит как частый выбор для flake-based deploy.

8. GUI и operator tooling тоже часть системы.
   - Podman Desktop полезен как визуальный слой для контейнеров и Kubernetes.
   - Но он не заменяет декларативную конфигурацию: это операторский инструмент, не источник истины.

Диалектическое уточнение
------------------------
Тезис: "Достаточно NixOS + podman + systemd".
Антитезис: "Это даст только запуск процессов, но не оркестрацию агентов".
Синтез: нужен многослойный стек.

Слои:
1. Environment layer - `nix develop`, `devenv`, `devshell`, `direnv`.
2. Runtime layer - `systemd`, `podman`, `oci-containers`.
3. Control plane - очередь задач, policy, retries, health, logs.
4. Deployment layer - `nixos-rebuild`, `deploy-rs`.
5. Operator UX - TUI / web UI / Podman Desktop / dashboards.

Практическая критика рекомендованного стека
------------------------------------------
1. `devshell` полезен, но проект сам помечает себя как unstable. Для долгоживущей платформы это слабая опора, если нужен более зрелый слой.
2. `devenv` выглядит сильнее как полноформатная среда: есть процессы, тесты, контейнеры, secrets integration, MCP, TUI. Это уже ближе к "локальной платформе", а не только shell.
3. `direnv` хорош как glue-слой, но сам по себе не решает структуру агентной оркестрации.
4. `deploy-rs` полезен, если конфигурация должна жить на нескольких узлах и обновляться флейк-способом.
5. Podman Desktop нужен только если оператору важна визуализация. Для pure infra workflow он не обязателен.

Что бы я добавил в целевую архитектуру
-------------------------------------
1. Пул рантаймов.
   - Отдельные unit'ы под coordinator, worker, model server, UI.
   - Не один монолит.

2. Контракты на состояние.
   - Какие данные ephemeral.
   - Какие persistent.
   - Где хранится память агента, артефакты, кэш, логи.

3. Политику ресурсов.
   - CPU, RAM, GPU, IO limits.
   - В локальной среде это критично, иначе агенты начнут мешать друг другу.

4. Политику сетей.
   - Что может ходить наружу.
   - Какие порты открыты.
   - Нужен ли proxy, DNS, loopback-only режим.

5. Политику человека в контуре.
   - Какие действия требуют approval.
   - Где stop-the-line.
   - Как агент сообщает о сомнениях.

Итоговая поправка
-----------------
Ранее я слишком быстро свёл систему к "flakes + devshell + podman + systemd". Это база, но не полноценная оркестрация. Полноценная система в NixOS для локальной разработки агентов должна включать control plane, наблюдаемость, identity, deployment tooling и режимы оператора. Иначе мы автоматизируем запуск, но не управление.

Источники и далее
- NixOS manual (Flakes, modules, systemd services)
- Nix community tools: devshell, nixpkgs derivations for agent tools
- Podman / k3s практика для локальных development clusters
- `devenv` как более зрелая альтернатива чистому devshell
- `direnv` как окруженческий glue-слой
- `deploy-rs` как flake-based deploy layer
- Podman Desktop как визуальный operator tool

(Этот документ — обзор/рекомендация; при желании могу: 1) создать flake skeleton + devShell, 2) добавить reference systemd unit + smoke test, 3) подготовить SURFACE.md и Proof для HDS-цикла.)
