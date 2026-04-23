# POLICY — Emacs в pro-nix

Цель
- Зафиксировать проверяемую политику: кто за что отвечает (Nix vs Emacs),
  как загружаются модули, как ставятся пакеты, и как избегаем split‑brain.

Контракты (коротко)
1) Загрузка модулей
   - user-first → system fallback.
   - Отключение базового слоя: `~/.config/emacs/.disable-nixos-base`.
   - Манифест пользователя: `~/.config/emacs/modules.el` (переменная `pro-emacs-modules` или совместимые алиасы).

2) Ответственность слоёв
   - Nix (system layer): Emacs бинарь, runtime deps, минимальные системные пакеты (см. provided‑by‑Nix), EXWM‑вход.
   - Emacs (user layer): конфигурация Lisp, выбор модулей, установка/апдейты ELPA/MELPA/VC‑пакетов.

3) Список пакетов, поставляемых Nix
   - Источник истины: `nix/provided-packages.nix` → генерирует `emacs/base/provided-packages.el`.
   - В рантайме список доступен как `pro-packages-provided-by-nix`.

4) Политика пакетного менеджмента (Emacs 30+)
   - Архивы: GNU ELPA, NonGNU ELPA, MELPA (приоритеты заданы в `modules/packages.el`).
   - Git‑пакеты: `package-vc` (install/upgrade).
   - Встроенные апгрейды: по умолчанию off; опция вручную через helper.

5) Избежание split‑brain (Nix vs ELPA/MELPA)
   - Если пакет в `pro-packages-provided-by-nix`, он считается системным. Не дублировать его в user ELPA без причины.
   - Если нужна более свежая версия — устанавливать в user layer осознанно и зафиксировать решение (см. Decisions ниже).

6) Auto‑install политика
   - По умолчанию допускается авто‑установка недостающих пакетов (см. `PRO_PACKAGES_AUTO_INSTALL`).
   - Для CI/образов: устанавливать `PRO_PACKAGES_AUTO_INSTALL=0` для строгой воспроизводимости.

7) Decisions (user override registry)
   - Файл: `~/.config/emacs/decisions.el` (алист `pro-packages-decisions`).
   - Значения: `always` (всегда ставить), `never` (никогда), пусто (спросить/следовать авто‑политике).

Пруфы/реализация
- Loader: `emacs/base/site-init.el` (user‑first, disable‑marker, provided‑packages fallback).
- Early init: `emacs/base/early-init.el` (package‑enable‑at‑startup=nil).
- Packages/VC: `emacs/base/modules/packages.el` (архивы, package‑vc helpers).
- Prompt‑install: `emacs/base/modules/pro-packages.el` (decisions, auto‑install env).
- Nix‑list: `nix/provided-packages.nix` → `emacs/base/provided-packages.el`.
- Тесты: `emacs/base/modules/tests.el`, `scripts/test-emacs-headless.sh`.

Правила совместимости
- Нельзя одновременно принудительно держать один и тот же пакет в Nix и в user ELPA без причины.
- Если пользователь ставит «свежее» в ELPA/MELPA, ответственность за возможные конфликты на стороне user layer; откаты делаем там же.

Режимы эксплуатации
- Dev (по умолчанию): `PRO_PACKAGES_AUTO_INSTALL=1` — удобство разработки, быстрая подтяжка недостающих пакетов.
- CI/Prod: `PRO_PACKAGES_AUTO_INSTALL=0` — строгая воспроизводимость; провалы — сигнализируют о несовместимости или пропущенных зависимостях.

Контрольная проверка (checklist)
1) `M-x list-packages` открывается, архивы заданы.
2) `M-x package-vc-install` работает.
3) `(boundp 'pro-packages-provided-by-nix)` → t, список непустой.
4) `site-init.el` загружает модули из user tree при наличии, иначе — из base.
5) Headless‑тесты проходят (`scripts/test-emacs-headless.sh`).

Эволюция политики
- Для пакетов, требующих строгой фиксации, добавляется вспомогательный механизм пинов (пер‑пакетные ревизии) в user layer с документированным форматом.
- Точки принятия решений (какой пакет жить в Nix vs ELPA) фиксируются в PR‑описаниях и/или в этом файле (раздел Decisions Log).
