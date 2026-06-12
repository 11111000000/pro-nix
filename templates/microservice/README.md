# Микросервис (шаблон)

Локальная разработка микросервиса через Docker Compose.

## Быстрый старт

```bash
# 1. Скопировать шаблон
cp -r templates/microservice ~/work/my-svc
cd ~/work/my-svc

# 2. Подготовить секреты
cp .env.sops.yaml.example .env.sops.yaml
$EDITOR .env.sops.yaml   # заполнить CHANGE_ME
sops --encrypt --in-place .env.sops.yaml

# 3. Поднять
just build
just up
just logs
```

Документация: [`../../docs/microservices.md`](../../docs/microservices.md).
