# Минимальный Dockerfile для микросервиса.
#
# Замечания (hadolint-clean):
#   - pinned alpine:3.20 (не `latest`, не `alpine`)
#   - отдельный USER (не root) с явным UID
#   - HEALTHCHECK в compose.yaml, не здесь (Dockerfile healthcheck
#     переопределяет compose, что нежелательно для dev)
#   - нет ADD (только COPY); нет curl/wget в проде
#   - multi-stage не используется намеренно: для dev-режима проще один
#     слой; для prod-образа используйте Nix-derivation (см. roadmap).
#
# Замените бинарь /app/app на свой сервис.

FROM alpine:3.20

# Системные зависимости: tini для корректного PID 1, wget для healthcheck
RUN apk add --no-cache tini wget ca-certificates

# Непривилегированный пользователь с фиксированным UID (1000)
RUN addgroup -g 1000 app && adduser -u 1000 -G app -D app

WORKDIR /app

# Зависимости отдельно от кода — кэшируется лучше
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY --chown=app:app . .

USER app

EXPOSE 8000

# tini корректно подбирает зомби-процессы и шлёт сигналы
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["./app"]
