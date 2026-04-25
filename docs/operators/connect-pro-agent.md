# Как подключить pro-agent к pro-nix (опционально)

Этот документ показывает, как локально подключить `pro-agent` к `pro-nix` в качестве дополнительного флейка. Pro-nix остаётся самодостаточным: шаги ниже — опциональны.

1) Локальная разработка (path)

- Предположим, вы клонировали `pro-agent` рядом с `pro-nix`:

```text
/home/az/pro-nix
/home/az/pro-agent
```

- В `pro-nix/flake.nix` добавьте в секцию `inputs`:

```nix
pro-agent = { url = "path:../pro-agent"; };
```

- После этого в `outputs` можно ссылаться на `inputs.pro-agent` и импортировать `nixosModules` или `apps`.

2) Подключение через git URL (remote)

- Пуш pro-agent в приватный/публичный репозиторий и в `pro-nix/flake.nix`:

```nix
pro-agent = { url = "github:yourorg/pro-agent"; };
```

- Зафиксируйте `flake.lock` и документируйте версию.

3) Как использовать импорты (пример)

В `configuration.nix` или другом месте, где вы собираете NixOS конфигурацию:

```nix
{ config, pkgs, inputs, ... }:

let
  proAgentModules = (inputs.pro-agent.nixosModules or {});
in

{
  imports = [
    # ... другие модули
    proAgentModules.agentsModelClient
    proAgentModules.agentsControl
  ];
}
```

4) Замечания по безопасности и reproducibility

- Pro-agent может содержать runtime‑сервисы и потенциально чувствительные опции — не добавляйте в pro-nix жестких ключей.
- Всегда pin‑ьте `pro-agent` в `flake.lock` перед развёртыванием на целевой машине.
