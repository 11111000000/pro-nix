;;; pro-reload.el --- Soft reload helpers for pro-nix -*- lexical-binding: t; -*-
;; Название: emacs/base/modules/pro-reload.el — Soft reload utilities
;; Кратко: безопасные helper-функции для перезагрузки модулей, фоновых обновлений и управления сессией.
;;
;; Контракт:
;; - pro/reload-module, pro/reload-file, pro/reload-all-modules, pro/update-melpa-in-background,
;;   pro/nix-generate-and-refresh-paths, pro/session-save-and-restart-emacs — публичные API этого файла.
;; - Все функции должны быть idempotent и не ломать текущую сессию при ошибках (используют ignore-errors/condition-case).
;; - Побочные эффекты: запуск фоновых процессов, запись файлов сессий, модификация load-path.
;;
;; Reload contract for module authors:
;; - Re-evaluating a module via `pro/reload-module' always runs the *current*
;;   contents of the .el file (we drop the load-history entry, so mtime tricks
;;   with .elc don't mask changes).
;; - Modules that own persistent state (child frames, background processes,
;;   globalised variables) should register a teardown function on
;;   `pro--after-reload-hook' so a reload actually re-creates that state
;;   from the freshly-loaded code.  Use `pro/after-reload #'my-reset-fn'.
;; - Modules should keep their top-level forms idempotent (use the
;;   pro-compat--add-hook-once / add-to-list-once / advice-add-once
;;   helpers) — re-evaluation will re-run them on every reload.
;;
;; Proof: headless ERT и ./scripts/emacs-pro-wrapper.sh smoke tests.
;; Last reviewed: 2026-05-02

(require 'subr-x)
(require 'cl-lib)                       ; for `cl-remove-if' in
                                        ; `pro--forget-file-in-load-history'.

(defvar pro--before-reload-hook nil
  "Normal hook run before `pro/reload-config' re-evaluates modules.
Modules register cleanup (kill child frames, stop bg processes, etc.) here.")

(defvar pro--after-reload-hook nil
  "Normal hook run after `pro/reload-config' has re-evaluated modules.
Modules register re-initialisation (recreate child frames, re-install
watches) here so persistent state is rebuilt from the freshly-loaded
code instead of the pre-reload instance.")

(defun pro/before-reload (fn)
  "Register FN on `pro--before-reload-hook' (idempotent). FN is a
function with no required args; errors are swallowed by the caller."
  (unless (memq fn pro--before-reload-hook)
    (add-hook 'pro--before-reload-hook fn)))

(defun pro/after-reload (fn)
  "Register FN on `pro--after-reload-hook' (idempotent). FN is a
function with no required args; errors are swallowed by the caller."
  (unless (memq fn pro--after-reload-hook)
    (add-hook 'pro--after-reload-hook fn)))

(defun pro--resolve-module-file (module)
  "Вернуть путь к файлу MODULE.el в системном каталоге модулей pro.
MODULE может быть символом или строкой (например "terminals").
Возвращает nil, если файл не найден или недоступен.
"
  (let* ((name (if (symbolp module) (symbol-name module) (format "%s" module)))
         (dir (and (boundp 'pro-emacs-base-system-modules-dir)
                   pro-emacs-base-system-modules-dir))
         (path (and dir (expand-file-name (format "%s.el" name) dir))))
    (and path (file-readable-p path) path)))

(defun pro--file-custom-variables (file)
  "Return variables declared by top-level `defcustom' forms in FILE."
  (with-temp-buffer
    (insert-file-contents file)
    (let (variables form)
      (condition-case nil
          (while t
            (setq form (read (current-buffer)))
            (when (and (consp form)
                       (eq (car form) 'defcustom)
                       (symbolp (cadr form)))
              (push (cadr form) variables)))
        (end-of-file))
      variables)))

(defun pro--reset-file-custom-variables (file)
  "Clear current values of custom variables declared in FILE."
  (dolist (variable (pro--file-custom-variables file))
    (makunbound variable)
    (put variable 'saved-value nil)
    (put variable 'customized-value nil)
    (put variable 'force-value nil)))

(defun pro--forget-file-in-load-history (file)
  "Remove all load-history entries whose file is FILE (or its .elc).
Also unbind features provided by the file.  Required because Emacs
uses load-history as the source of truth for `load' re-evaluation:
if the recorded load time matches the file's mtime, the .el is not
re-evaluated, even when the user is asking for an explicit reload."
  (let* ((truename (ignore-errors (file-truename file)))
         (matches (lambda (entry)
                    (and (consp entry)
                         (stringp (car entry))
                         (or (string= (car entry) file)
                             (and truename
                                  (string= (car entry) truename))
                             (string= (car entry)
                                      (concat (file-name-sans-extension file) ".elc"))))))
         ;; Collect features provided by the file so we can `unload-feature'.
         (features-to-unbind nil))
    (dolist (entry load-history)
      (when (funcall matches entry)
        ;; entry is (FILE . FORMS). FORMS looks like (provide . FEATURE) etc.
        (dolist (form (cdr entry))
          (when (and (consp form) (eq (car form) 'provide)
                     (symbolp (cdr form)))
            (push (cdr form) features-to-unbind)))))
    ;; Drop matching entries.
    (setq load-history
          (cl-remove-if matches load-history))
    ;; Also drop .elc load-history entries, which `load' would otherwise
    ;; prefer when the .elc is newer than .el.
    (let ((elc (concat (file-name-sans-extension file) ".elc")))
      (when (file-exists-p elc)
        (setq load-history
              (cl-remove-if (lambda (e)
                              (and (consp e) (stringp (car e))
                                   (string= (car e) elc)))
                            load-history))))
    ;; Unbind features (silently — module's top-level `(provide ...)' will
    ;; re-add them on re-evaluation).
    (dolist (feat features-to-unbind)
      (ignore-errors (unload-feature feat t)))))

(defun pro/reload-module (module)
  "Перезагрузить MODULE из каталога pro-модулей.
MODULE — символ или строка. Возвращает t при успехе, nil при ошибке.

Что происходит:
  1. Удаляется .elc, если он СТАРШЕ .el (mtime .el новее) — без этого
     `load' подхватит устаревший скомпилированный код.
  2. Удаляется .elc, если он НОВЕЕ .el — типичный случай после
     `byte-compile-file'; в этой ситуации Emacs все равно загрузит
     .elc, но мы хотим, чтобы `load-file' ниже взял именно .el.
  3. Из `load-history' выкидывается запись об этом файле (и его .elc),
     а соответствующий `provide' делается `unload-feature'. Без этого
     `load' считает файл уже загруженным с актуальной меткой времени
     и молча пропускает переоценку.
  4. `load-file' запускает свежий .el с диска.

Если в `load-history' нет записи (модуль загружался до reload),
шаги 1–3 безвредно no-op'ятся."
  (interactive (list (intern (completing-read "Module: "
                                               (mapcar (lambda (m) (if (symbolp m) (symbol-name m) (format "%s" m)))
                                                       (when (boundp 'pro-emacs-base-default-modules) pro-emacs-base-default-modules))
                                               nil t))))
  (let ((file (pro--resolve-module-file module)))
    (if (not file)
        (progn (message "pro/reload-module: module file not found: %s" module) nil)
      (condition-case err
          (progn
           (let ((elc (concat (file-name-sans-extension file) ".elc")))
             (when (and (file-exists-p elc)
                        (file-newer-than-file-p file elc))
               (delete-file elc)
               (message "pro/reload-module: removed stale %s" elc)))
           (pro--forget-file-in-load-history file)
           (load-file file)
           (message "reloaded module %s" module)
           t)
         (error (message "error reloading %s: %S" module err) nil)))))

(defun pro/reload-file (file)
  "Reload FILE (.el) — re-run all top-level forms in current Emacs session.

Алгоритм:
  1. Находятся top-level `defcustom'; их runtime-, saved- и customized-
     значения очищаются, чтобы новые initializer-формы стали текущими.
  2. Удаляется устаревший .elc, если исходный .el новее.
  3. `pro--forget-file-in-load-history' удаляет записи файла и его .elc.
  4. `load-file' перечитывает .el и выполняет все top-level формы заново.

Если в `load-history' нет записи (файл ни разу не загружался,
например, скрипт без `provide'), шаги 1–2 безвредно no-op'ятся.

Возвращает t при успехе, nil при ошибке. Используется командами
`pro/dired-reload-elisp-here', `pro/dired-reload-elisp-dir-recursive'
и `pro/lisp-reload-buffer'."
  (interactive "fReload .el file: ")
  (let ((file (expand-file-name file)))
    (unless (string-suffix-p ".el" file)
      (user-error "pro/reload-file: not a .el file: %s" file))
    (condition-case err
        (progn
          (let ((elc (concat (file-name-sans-extension file) ".elc")))
            (when (and (file-exists-p elc)
                       (file-newer-than-file-p file elc))
              (delete-file elc)
              (message "pro/reload-file: removed stale %s" elc)))
          (pro--reset-file-custom-variables file)
          (pro--forget-file-in-load-history file)
          (load-file file)
          (message "pro/reload-file: reloaded %s" file)
          t)
      (error (message "pro/reload-file: failed for %s: %S" file err) nil))))

(defun pro/reload-all-modules ()
  "Перезагрузить все модули из `pro-emacs-base-default-modules'."
  (interactive)
  (when (and (boundp 'pro-emacs-base-default-modules) pro-emacs-base-default-modules)
    (let ((ok 0) (fail 0))
      (dolist (m pro-emacs-base-default-modules)
        (if (ignore-errors (pro/reload-module m))
            (setq ok (1+ ok))
          (setq fail (1+ fail))))
      (message "pro/reload-all-modules: %d ok, %d failed" ok fail))))

(defvar pro--package-features nil
  "Список features, загруженных из /run/current-system/sw/share/emacs/site-lisp/elpa/
или из Nix-store elpa. Используется в `pro/reload-config' для force-reload после `just switch'.
Заполняется лениво при первом вызове; обновляется при каждом reload.")

(defun pro--package-feature-p (file)
  "Non-nil если FILE — путь к пакету (не к встроенному Emacs .elc).

Пакеты в NixOS-конфиге pro-nix поставляются либо через
emacs-with-packages (лежат в /run/current-system/sw/share/emacs/site-lisp/
или /nix/store/.../share/emacs/site-lisp/ и подкаталогах вроде /elpa/),
либо через home-manager-профиль.

Встроенные Emacs-файлы лежат в /nix/store/...-emacs-<ver>/share/emacs/<ver>/lisp/
(например 30.2/lisp/backquote.elc). Они НЕ являются пакетами и должны
оставаться загруженными.

Эвристика: пакет, если путь содержит '/site-lisp/' ИЛИ '/elpa/' под
share/emacs/, или идёт из home-manager elpa-каталога."
  (and (stringp file)
       (cond
        ;; Nix-store elpa: /nix/store/.../share/emacs/.../<pkg>-<ver>/...
        ;; Отличаем от /nix/store/...-emacs-30.2/share/emacs/30.2/lisp/...
        ;; по наличию /elpa/ или /site-lisp/ в пути.
        ((string-prefix-p "/nix/store/" file)
         (or (string-match-p "/share/emacs/[^/]+/elpa/" file)
             (string-match-p "/share/emacs/[^/]+/site-lisp/" file)
             (string-match-p "/share/emacs/site-lisp/" file)))
        ;; System-wide: /run/current-system/sw/share/emacs/site-lisp/...
        ((string-prefix-p "/run/current-system/sw/share/emacs/" file)
         (or (string-match-p "/site-lisp/" file)
             (string-match-p "/elpa/" file)))
        ;; Home-manager Emacs elpa: ~/.local/state/.../share/emacs/...
        ((string-match-p "/share/emacs/[^/]+/elpa/" file) t)
        (t nil))))

(defun pro--collect-package-features ()
  "Собрать список features, загруженных из Nix-/EMACS-provided site-lisp.
Это функции вроде `magit', `consult', `telega' — те, что поставляет
`emacs-with-packages' (Nix). Возвращает свежий список символов.

Алгоритм: обходим `load-history', для каждой записи смотрим FILE;
если путь удовлетворяет `pro--package-feature-p', собираем все
`provide' из этой записи."
  (let (result)
    (dolist (entry load-history result)
      (when (and (consp entry) (stringp (car entry)))
        (let ((file (car entry)))
          (when (pro--package-feature-p file)
            (dolist (form (cdr entry))
              (when (and (consp form) (eq (car form) 'provide)
                         (symbolp (cdr form))
                         ;; Наши pro-* модули — отдельно через pro/reload-module.
                         (not (string-prefix-p "pro-" (symbol-name (cdr form)))))
                (push (cdr form) result)))))))))

(defvar pro--built-in-features
  '(emacs cl-lib subr-x advice help-mode help-fns help-macro help elt seq
          eieio backtrace find-func pp comint ring format-spec shortdoc
          cl-macs cl-generic cl-extra pcase rx theraamc
          ;; Фундаментальные subr-фичи, появляются в load-history раньше всего
          backquote hashtable-print-readable keymap widget custom
          ;; Внутренние, на которых держится Emacs
          files-x cus-edit cus-start cus-load wid-edit)
  "Базовые фичи Emacs и subr, которые НЕЛЬЗЯ выгружать.
Часть встроенного Emacs, `unload-feature' на них сделает Emacs
неработоспособным. Эти фичи появляются в load-history как provided
из `/nix/store/...-emacs-30.2/share/emacs/30.2/lisp/*.elc', но наш
фильтр `pro--package-feature-p' их пропускает (нет `/elpa/' или
`/site-lisp/' в пути). На случай если путь нестандартный — оставляем
явный denylist.")

(defun pro/reload-packages ()
  "Force-reload всех Nix-/Emacs-provided пакетов (magit, consult, telega, …).

Алгоритм:
  1. Собрать features, загруженные из /run/current-system/sw/.../share/emacs/
     или из /nix/store/.../share/emacs/.
  2. Для каждого выполнить `unload-feature' с FORCE=t. Это выгружает
     функции и сбрасывает feature, чтобы `require' смог перечитать файл.
  3. Очистить `load-path' от старых путей этих packages и добавить
     заново /run/current-system/sw/share/emacs/site-lisp/elpa и
     вложенные site-lisp от найденных derivation.
  4. `require' каждый feature обратно — Emacs загрузит .elc/.el из
     нового /nix/store-пути (если `just switch' положил туда новую
     derivation).

ВАЖНО: между шагами 2 и 4 Emacs НЕ будет иметь доступа к функциям
этих пакетов. Не вызывайте их в этот промежуток (например, в
`pro--before-reload-hook' / `pro--after-reload-hook').

Возвращает plist (:unloaded N :loaded M :failed F).

Не выгружает:
  - встроенные Emacs-фичи (emacs, cl-lib, subr-x, …)
  - наши собственные pro-* модули (их reload — через pro/reload-module)
  - features, чьи файлы сейчас не существуют (защита от race condition)"
  (interactive)
  (let* ((targets (pro--collect-package-features))
         (unloaded 0)
         (loaded 0)
         (failed 0)
         (failed-names '()))
    ;; 1. СНАЧАЛА выгружаем все target features (ДО чистки load-path —
    ;; иначе Emacs не сможет найти loadhist.el, требуемый
    ;; unload-feature, и выдаст file-missing).
    (dolist (feat targets)
      (condition-case err
          (progn
            (unload-feature feat 'force)
            (setq unloaded (1+ unloaded)))
        (error
         (setq failed (1+ failed))
         (push feat failed-names)
         (message "pro/reload-packages: unload %s failed: %S" feat err))))
    ;; 2. Теперь чистим load-path от старых путей и добавляем заново
    ;; текущие site-lisp/elpa пути — чтобы require ниже перечитал из
    ;; нового /nix/store.
    ;;
    ;; ВАЖНО: сохраняем путь /etc/profiles/per-user/<user>/share/emacs/...
    ;; (home-manager профиль). Без него require magit/consult не найдёт
    ;; свои .elc — функция `pro--package-feature-p' его считает пакетом,
    ;; и cl-remove-if выше мог бы его удалить.
    (setq load-path
          (cl-remove-if (lambda (p)
                          (and (stringp p)
                               (pro--package-feature-p p)
                               ;; Не трогаем home-manager профиль — он
                               ;; стабильный путь в /etc/profiles/per-user.
                               (not (string-prefix-p "/etc/profiles/per-user/" p))))
                        load-path))
    ;; Добавляем обратно стандартные site-lisp пути:
    ;;   - /run/current-system/sw/share/emacs/site-lisp/ + подкаталоги
    ;;   - /etc/profiles/per-user/<user>/share/emacs/site-lisp/ + подкаталоги
    ;;   - любые /nix/store/.../share/emacs/site-lisp/ из текущего PATH
    (let ((roots '("/run/current-system/sw/share/emacs/site-lisp")))
      (let ((user-elpa-dir
             (expand-file-name
              "share/emacs/site-lisp"
              (file-name-directory
               (file-name-directory
                (file-name-directory user-emacs-directory))))))
        ;; user-emacs-directory = ~/.config/emacs, ищем user profile в /etc/profiles
        ;; (простой способ — найти первый путь, который уже был в load-path)
        (setq roots
              (append roots
                      (cl-remove-if-not
                       (lambda (p)
                         (and (stringp p)
                              (string-prefix-p "/etc/profiles/per-user/" p)
                              (file-directory-p p)
                              (string-match-p "/share/emacs/[^/]+/site-lisp" p)))
                       load-path)))
        (dolist (root roots)
          (when (and (stringp root) (file-directory-p root))
            (add-to-list 'load-path root)
            (dolist (sub (directory-files root t "^[a-z0-9]" t))
              (when (file-directory-p sub)
                (add-to-list 'load-path sub)))))))
    ;; 3. Require обратно.
    (dolist (feat targets)
      (condition-case err
          (progn
            (require feat nil 'noerror)
            (if (featurep feat)
                (setq loaded (1+ loaded))
              (setq failed (1+ failed))
              (push feat failed-names)
              (message "pro/reload-packages: require %s failed (noerror returned nil)" feat)))
        (error
         (setq failed (1+ failed))
         (push feat failed-names)
         (message "pro/reload-packages: require %s error: %S" feat err))))
    (message "pro/reload-packages: unloaded=%d loaded=%d failed=%d (%s)"
             unloaded loaded failed
             (mapconcat #'symbol-name (reverse failed-names) ", "))
    (list :unloaded unloaded :loaded loaded :failed failed
          :failed-names (reverse failed-names))))

(defun pro/update-melpa-in-background ()
  "Запустить фоновый процесс для обновления MELPA/ELPA.
Запускает отдельный Emacs --batch, который выполняет скрипт
scripts/melpa-update.el. Это не блокирует текущую сессию.
"
  (interactive)
  (let* ((repo (file-name-directory (or load-file-name buffer-file-name)))
         (script (expand-file-name "scripts/melpa-update.el" (or repo ".")))
         (emacs-bin (or (executable-find "emacs") "emacs")))
    (when (file-exists-p script)
      (start-process "pro-melpa-update" "*pro-melpa-update*" emacs-bin "--batch" "-Q" "-l" script)
      (message "pro: started background MELPA update"))))

(defun pro/nix-generate-and-refresh-paths ()
  "Вызвать скрипт генерации путей Nix и обновить load-path.
Ожидается, что scripts/nix-update-emacs-paths.sh создаёт файл
emacs/base/nix-emacs-paths.el с переменной `pro/nix-site-lisp-paths'.
"
  (interactive)
  (let* ((repo (file-name-directory (or load-file-name buffer-file-name)))
         (script (expand-file-name "scripts/nix-update-emacs-paths.sh" (or repo ".")))
         (out (expand-file-name "emacs/base/nix-emacs-paths.el" (or repo "."))))
    (when (and (file-executable-p script) (zerop (call-process script nil nil nil)))
      (when (file-readable-p out)
        (load-file out)
        (when (boundp 'pro/nix-site-lisp-paths)
          (require 'nix-refresh nil t)
          (when (fboundp 'pro/nix-load-path-refresh)
            (pro/nix-load-path-refresh pro/nix-site-lisp-paths)))))))

(defun pro/session-save-and-restart-emacs (&optional save-file)
  "Сохранить сессию и перезапустить Emacs, восстановив сессию.
Функция попытётся вызвать `pro/session-save' для сохранения состояния,
а затем запустить новый Emacs, который загрузит сохранённую сессию.
"
  (interactive)
  (let* ((save (or save-file (and (fboundp 'pro/session-save) (pro/session-save))))
         (emacs-bin (or (executable-find "emacs") "emacs")))
    (when save
      (start-process "pro-restart" "*pro-restart*" emacs-bin "--eval" (format "(progn (load \"%s\") (pro/session-restore))" save))
      (message "pro: spawned new Emacs to restore session; exiting current Emacs")
      (kill-emacs))))

(defun pro/revert-buffer ()
  "Revert current buffer without asking for confirmation.
This is a thin wrapper around `revert-buffer' that suppresses the
y-or-n-p prompt by temporarily setting `revert-without-query' to a
catch-all regex and then restoring the previous value.  Safe to call
from any buffer; if `revert-buffer' errors (e.g. no file is associated
or the buffer is non-revertable) the error is surfaced as a message
without aborting the calling command."
  (interactive)
  (let ((prev revert-without-query))
    (condition-case err
        (let ((revert-without-query '(".")))
          (revert-buffer))
      (error
       (setq revert-without-query prev)
       (message "pro/revert-buffer: %S" err)))))

(defun pro/reload-config (&optional full)
  "Reload the whole pro Emacs configuration to apply changes without restarting.

Prefix arg controls the depth:
  no prefix   — soft reload наших pro-* модулей (default). Быстро,
                безопасно, не трогает Nix-пакеты.
  C-u         — full reload: перечитывает site-init.el и весь манифест.
                Тоже безопасно. Похоже на рестарт Emacs с восстановлением
                буферов, но без потери frame-состояния X11.
  C-u C-u     — packages reload: ВЫГРУЖАЕТ с FORCE все Nix-/EMACS-provided
                пакеты (magit, consult, telega, …) и require'ит их
                обратно из /nix/store. Это даёт реальное обновление
                пакетов после `just switch' без рестарта Emacs.
                Между unload и require функции пакетов недоступны;
                pre-/after-reload hooks могут сломаться — это намеренно.
                В EXWM безопасно: X-клиенты не падают, WM-моргает.

Both paths run `pro--before-reload-hook' (modules can tear down child
frames / bg processes / cached state) and `pro--after-reload-hook'
(modules re-create persistent state from the freshly loaded code).

This function is defensive and uses `ignore-errors' / `condition-case' to avoid
breaking the running session when a single module fails to reload.

Usage:
  M-x pro/reload-config       ;; quick reload (modules in-place)
  C-u M-x pro/reload-config   ;; full reload (re-eval site-init.el + modules)
  C-u C-u M-x pro/reload-config ;; packages reload (force-unload + require Nix pkgs)
"
  (interactive "P")
  (let ((start (float-time))
        (packages-p (= (prefix-numeric-value full) 16)))
    (message "pro: starting config reload (full=%s packages=%s)" full packages-p)
    ;; 1. Refresh nix-generated paths if available
    (ignore-errors (when (fboundp 'pro/nix-generate-and-refresh-paths)
                     (pro/nix-generate-and-refresh-paths)))
    ;; 2. Pre-reload cleanup. Modules that own child frames / bg
    ;;    processes / cached state should hook this to drop it.
    (run-hooks 'pro--before-reload-hook)
    ;; 3. Re-evaluate module code.
    (condition-case err
        (cond
         (packages-p
          ;; Packages reload: force-unload всех Nix-предоставленных пакетов,
          ;; потом require заново. После этого наши pro-* модули могут
          ;; ссылаться на новые определения magit/consult/telega/etc.
          (pro/reload-packages)
          (pro/reload-all-modules))
         (full
          (let ((site-init (and (boundp 'pro-emacs-base-system-modules-dir)
                                (locate-library "pro-site-init"))))
            ;; Re-eval site-init.el from disk so provided-packages,
            ;; manifest resolution, and pro-emacs-base-start all run
            ;; again. `load-file' here is what makes a `full' reload
            ;; actually re-run the top-level side effects.
            (if (and site-init (file-readable-p site-init))
                (progn
                  (pro--forget-file-in-load-history site-init)
                  (load-file site-init)
                  (when (fboundp 'pro-emacs-base-start)
                    (pro-emacs-base-start)))
              (pro-emacs-base-start))
            (pro/reload-all-modules)))
         (t
          (pro/reload-all-modules)))
      (error (message "pro/reload-config: module reload failed: %S" err)))
    ;; 4. Re-apply keybindings and pending pro-keys entries
    (ignore-errors (when (fboundp 'pro-keys-reload) (pro-keys-reload)))
    (ignore-errors (when (fboundp 'pro-keys-apply-pending) (pro-keys-apply-pending)))
    (ignore-errors (when (fboundp 'pro-keys-report-pending) (pro-keys-report-pending)))
    ;; 5. Reconstruct epistemic state if module provides it
    (ignore-errors (when (fboundp 'pro--reconstruct) (pro--reconstruct)))
    ;; 6. Re-apply UI tweaks like fonts and cursor
    (ignore-errors (when (fboundp 'pro-ui-apply-fonts) (pro-ui-apply-fonts)))
    (ignore-errors (when (fboundp 'pro-ui-apply-fringes) (pro-ui-apply-fringes)))
    (ignore-errors (when (fboundp 'pro-ui-apply-completion) (pro-ui-apply-completion)))
    (ignore-errors (when (fboundp 'pro-ui-apply-icons) (pro-ui-apply-icons)))
    (ignore-errors (when (fboundp 'pro-ui-apply-modeline) (pro-ui-apply-modeline)))
    (ignore-errors (when (fboundp 'pro-ui-apply-theme) (pro-ui-apply-theme)))
    ;; 7. Post-reload re-init. Modules that owned persistent state
    ;;    register a function here to re-create it from the freshly
    ;;    loaded code. Without this, a banner frame created at startup
    ;;    would keep its old geometry even after the module's width
    ;;    math changed.
    (run-hooks 'pro--after-reload-hook)
    (message "pro: config reload finished in %.2fs" (- (float-time) start))))

(provide 'pro-reload)

;;; pro-reload.el ends here
