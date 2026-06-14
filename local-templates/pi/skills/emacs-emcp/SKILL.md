---
name: emacs-emcp
description: Доступ к запущенному Emacs через EMCP (MCP-сервер). Использовать, когда задача требует взаимодействия с текущей Emacs-сессией: посмотреть определение функции/переменной в Emacs, прочитать буфер, сделать скриншот фрейма, выполнить elisp-выражение, отправить клавиши в Emacs. Профиль по умолчанию `full-control` (eval/send-keys включены, но гейтнуты политикой 'ask' — каждый вызов подтверждается в `*EMCP confirm*`).
---

# Emacs EMCP — подключение к живой Emacs-сессии

EMCP поднимает внутри Emacs HTTP MCP-сервер на `127.0.0.1:38913/mcp`.
Профиль по умолчанию — `full-control`: `inspect` + `get-variable` + `set-variable` + `screenshot` + `eval` + `send-keys`.
`eval` и `send-keys` гейтнуты политикой `'ask'` — каждый вызов требует подтверждения в буфере `*EMCP confirm*` (`y` / `n` / `a` — always accept / `r` — always reject для сессии).

## 1. Проверить, что сервер жив

```bash
curl -fsS http://127.0.0.1:38913/mcp -X POST \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"curl","version":"0"}}}' \
  | head -c 400
```

Если `connection refused` — Emacs не запущен или `pro-emcp` ещё не поднял сервер
(см. `~/.config/emacs/provided-packages.el` — должно быть `emcp` в
`pro-packages-provided-by-nix`). Внутри Emacs перезапустите:

```
M-x pro-emcp-server-start
```

URL появится в `*Messages*` и попадёт в kill-ring.

## 2. Что есть в full-control (дефолт)

| Тип | Имя | Что делает |
|-----|-----|------------|
| tool | `apropos` | Поиск символов по регулярке (`pattern`, опц. `kind`) |
| tool | `describe` | Полное описание символа (`symbol`, опц. `kind`) |
| tool | `find-definition` | Путь к определению символа |
| tool | `find-references` | Все ссылки на символ в загруженных .el-файлах |
| tool | `info-search` | Поиск в Info-индексах (`pattern`, опц. `manual`) |
| tool | `get-variable` | Глобальное значение переменной (`name`) |
| tool | `set-variable` | Установить глобальное значение (`name`, `value` как Lisp literal) |
| tool | `screenshot` | PNG всех видимых фреймов |
| tool | `eval` | Выполнить произвольный elisp (`code`). Гейтнут политикой `emcp-tools-eval-default-policy` (по умолчанию `ask`). |
| tool | `send-keys` | Отправить клавиатурную последовательность (`keys` в `kbd`-нотации). Гейтнут политикой `emcp-tools-send-keys-default-policy` (по умолчанию `ask`). |
| resource | `info://{manual}/{node}` | Прочитать Info-ноду |
| prompt | `/screenshot` | Запросить у пользователя скриншот (он сам решает, делиться ли) |

## 3. Типичные сценарии

### Проверить, что функция определена и что она делает
1. `find_definition` по символу — путь и форма.
2. `describe` — полный help-buffer (docstring, args, source).
3. `find_references` — где используется.
4. `info://elisp/Defun` (через resource) — контекст из мануала.

### Понять, почему конфиг ведёт себя странно
1. `get_variable` — текущее значение (например, `pro-agent-shell-refresh-interval`).
2. `find_definition` — где задано.
3. `find_references` — кто читает/меняет.
4. Если известен буфер — `apropos` по регулярке из сообщения об ошибке.

### Проверить визуальное состояние
1. `screenshot` → PNG-байты в ответе. Сохранить в `/tmp/emcp-shot.png` и
   показать пользователю (или приложить к ответу).
2. Если нужен снимок конкретного фрейма — `/screenshot` (попросит пользователя).

### Безопасно поправить конфиг
1. `get_variable` до изменения (для отката).
2. `set_variable` с Lisp-literal значением: число, строка, `(1 2 3)`, `'sym`, `t`, `nil`.
3. `get_variable` после — подтвердить.

## 4. Безопасность

- `eval` и `send-keys` гейтнуты политикой `ask` по умолчанию: каждый вызов
  открывает `*EMCP confirm*` буфер, где пользователь жмёт `y` (принять) /
  `n` (отклонить) / `a` (принять для всей сессии) / `r` (отклонить для всей
  сессии) / `q` (отменить). Политику можно отключить в Emacs:
  ```elisp
  ;; в ~/.config/emacs/modules/<user>.el
  (setq emcp-tools-eval-default-policy t            ; 't' — accept, nil — reject, 'ask' — спрашивать
        emcp-tools-send-keys-default-policy t)
  ```
  Не делайте так, пока не доверяете MCP-клиенту полностью.
- `set-variable` меняет **глобальный** default, не buffer-local значение. Это
  влияет на все буферы. Для buffer-local используйте `eval`:
  ```
  eval: "(set (make-local-variable 'some-var) 42)"
  ```
- Никогда не вызывайте `set-variable` для `emcp-http-port` или
  `emcp-default-profile` — это приведёт к разрыву соединения.
- Если вы не уверены в значении `value` для `set-variable` — используйте
  `eval`: `(setq some-var 42)` или подобное.

## 5. Откат к develop-профилю (только inspect/develop/screenshot)

Если нужен профиль без eval/send-keys (например, чтобы исключить
возможность произвольного elisp в недоверенной сессии), запустите в Emacs:
```elisp
;; в ~/.config/emacs/modules/<user>.el
(setq pro-emcp-server-profile 'develop)
```
Затем `M-x pro/reload-config` (`C-x M-c`). Сервер пересоздастся с
профилем `develop` (без eval/send-keys), тот же URL `127.0.0.1:38913/mcp`
останется в `mcp.json`.

## 6. Troubleshooting

| Симптом | Причина | Решение |
|---------|---------|---------|
| `Connection refused` на 127.0.0.1:38913 | Emacs не запущен | Запустить Emacs; `M-x pro-emcp-server-status` |
| `Connection refused`, Emacs запущен | emcp-пакет не в runtime | `M-x pro/reload-config` после проверки `provided-packages.el`; `M-x pro-emcp-server-start` |
| Server alive, но `find_definition` возвращает `Symbol not found` | Символ в другом namespace или не загружен | Сначала `apropos`; затем явно `require` модуль через пользователя |
| `screenshot` возвращает мусор | OK — это base64 PNG | Декодировать и сохранить |
| `set-variable` отвергнут | Значение не Lisp-literal | Передать строку, которая `read`'ится в нужное значение: `"42"`, `"\"hi\""`, `"(1 2 3)"`, `"t"`, `"nil"` |
| Соединение падает в середине сессии | Emacs перезапустили или `emcp-stop` | Переподключиться; `pro-emcp-server-status` подтвердит |

## 7. Связка с другими инструментами

- **agent-shell (в-Емакс-чат)**: использует тот же emcp через свой механизм
  запуска per-session. Если вы видите, что `emcp-start` уже вызван в
  `*Messages*` agent-shell — наш `pro-emcp-server` стартовал с тем же URL.
- **eval/send-keys в agent-shell**: agent-shell поднимает свой профиль через
  `agent-shell-mcp-servers` (см. `pro-agent-shell.el`). Это **другой** сервер
  с **другим** профилем — не конфликтует с нашим `pro-emcp-server`.
- **chrome-devtools / genium**: orthogonal — не пересекается.

## 8. Чего НЕ делать

- Не менять `emcp-http-port` через MCP — потеряете соединение.
- Не запускать `emcp-stop` агентом — это разрывает сессию **всех**
  MCP-клиентов сразу.
- Не вызывать `send-keys` с произвольными последовательностями, не подумав
  о текущем буфере/режиме/минibuffer-стейте — эффект может быть любым.
  Политика `'ask'` это гейтит, но всё равно читайте что отправляете.
- Не предполагать, что `find_definition` сработает для символа, который не
  `require`'нут в текущей Emacs-сессии. Сначала `apropos` с широкой регуляркой.
