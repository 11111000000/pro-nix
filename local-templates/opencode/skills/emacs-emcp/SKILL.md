# Skill: emacs-emcp

## Цель

Доступ к запущенному Emacs через EMCP (MCP-сервер) на `http://127.0.0.1:38913/mcp`.
Позволяет: искать символы, читать help, находить определения и ссылки,
читать буферы, делать скриншоты фреймов, читать/писать переменные.

Профиль по умолчанию — `develop`: `inspect` + `get-variable` + `set-variable` + `screenshot`.
`eval` и `send-keys` НЕ включены.

## 1. Проверить, что сервер жив

```bash
curl -fsS http://127.0.0.1:38913/mcp -X POST \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"curl","version":"0"}}}' \
  | head -c 400
```

Если `connection refused` — Emacs не запущен или модуль `pro-emcp` не поднял
сервер. Попросите пользователя:
- запустить Emacs,
- или внутри Emacs: `M-x pro-emcp-server-start` (URL появится в `*Messages*`).

## 2. Инструменты develop-профиля

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
| resource | `info://{manual}/{node}` | Прочитать Info-ноду |
| prompt | `/screenshot` | Запросить у пользователя скриншот (он сам решает, делиться ли) |

**Нет**: `eval`, `send-keys`. Доступны только в `full-control` (см. §5).

## 3. Типичные сценарии

### Проверить, что функция определена и что она делает
1. `find_definition` по символу — путь и форма.
2. `describe` — полный help-buffer (docstring, args, source).
3. `find_references` — где используется.
4. `info://elisp/Defun` через resource — контекст из мануала.

### Понять, почему конфиг ведёт себя странно
1. `get_variable` — текущее значение.
2. `find_definition` — где задано.
3. `find_references` — кто читает/меняет.
4. Если известен буфер — `apropos` по регулярке из сообщения об ошибке.

### Проверить визуальное состояние
1. `screenshot` → PNG-байты. Сохранить в `/tmp/emcp-shot.png` и показать пользователю.
2. Если нужен снимок конкретного фрейма — `/screenshot` (попросит пользователя).

### Безопасно поправить конфиг
1. `get_variable` до изменения (для отката).
2. `set_variable` с Lisp-literal значением: число, строка, `(1 2 3)`, `'sym`, `t`, `nil`.
3. `get_variable` после — подтвердить.

## 4. Безопасность

- `set-variable` меняет **глобальный** default, не buffer-local. Влияет на все буферы.
- Никогда не меняйте `emcp-http-port` или `emcp-default-profile` через MCP —
  разорвёте соединение.
- `value` для `set-variable` — **строка с Lisp-литералом**, EMCP парсит сам.
  Примеры: `"42"`, `"\"hi\""`, `"(1 2 3)"`, `"t"`, `"nil"`.

## 5. Эскалация: full-control (eval, send-keys)

`eval` и `send-keys` **НЕ** доступны по умолчанию. Каждый вызов идёт через
буфер подтверждения `*EMCP confirm*` — пользователь явно жмёт `y` / `n`.

Поднять full-control:
1. Попросите пользователя в Emacs:
   ```
   M-x emcp-start RET full-control RET
   ```
2. Сервер стартует на **другом** порту (у каждого профиля свой сервер).
   URL покажется в `*Messages*`.
3. Попросите пользователя зарегистрировать новый URL через
   `opencode mcp add --transport http emcp-full <url>` (или
   отредактировать `opencode.json`) и **предупредите**, что эта сессия
   может выполнять произвольный elisp.

Альтернативно — пользователь может глобально переключить default:
```elisp
;; в ~/.config/emacs/modules/<user>.el
(setq pro-emcp-server-profile 'full-control)
```
После `M-x pro/reload-config` (`C-x M-c`) — все будущие emcp-сессии стартуют
на full-control. **Только для dev-окружений**, не для production.

## 6. Troubleshooting

| Симптом | Причина | Решение |
|---------|---------|---------|
| `Connection refused` на 127.0.0.1:38913 | Emacs не запущен | Запустить Emacs; `M-x pro-emcp-server-status` |
| `Connection refused`, Emacs запущен | emcp-пакет не в runtime | `M-x pro/reload-config`; `M-x pro-emcp-server-start` |
| Server alive, `find_definition` → `Symbol not found` | Символ не загружен | Сначала `apropos`; затем `require` через пользователя |
| `screenshot` мусор в ответе | OK — base64 PNG | Декодировать и сохранить |
| `set-variable` отвергнут | Значение не Lisp-literal | Передать строку, которая `read`'ится в нужное значение |
| Соединение падает | Emacs перезапустили | Переподключиться; `pro-emcp-server-status` подтвердит |

## 7. Связка

- **agent-shell (в-Емакс-чат)**: использует тот же emcp через свой механизм.
  Не конфликтует с нашим `pro-emcp-server` (у каждого профиля свой URL).
- **chrome-devtools / genium**: orthogonal, не пересекается.

## 8. Чего НЕ делать

- Не вызывать `eval` через `set-variable` — это не код, а присваивание.
  Для произвольного кода нужен `full-control` + явное согласие пользователя.
- Не менять `emcp-http-port` через MCP — потеряете соединение.
- Не запускать `emcp-stop` агентом — это разрывает сессию **всех** MCP-клиентов.
- Не предполагать, что `find_definition` сработает для символа, который не
  `require`'нут. Сначала `apropos` с широкой регуляркой.
