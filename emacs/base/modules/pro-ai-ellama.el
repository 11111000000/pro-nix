;;; pro-ai-ellama.el --- Ellama integration: AGENTS.md, skills, sessions -*- lexical-binding: t; -*-
;;
;; # PRO-MODULE: pro-ai-ellama
;;
;; Регистрация предложений в pro-keys (см. `pro-keys-load-org-file'):
;;   C-c e e   pro-ai-ellama-open
;;   C-c e s   pro-ai-ellama-summarize
;;   C-c e r   pro-ai-ellama-code-review
;;   C-c e p   pro-ai-ellama-plan-and-act
;;   C-c e l   pro-ai-ellama-list-sessions
;;   C-c e a   pro-ai-ellama-load-agents-md
;;
;; Назначение: тонкая обвязка над ellama (https://github.com/s-kostyaev/ellama),
;; которая:
;;   - регистрирует ellama как часть pro-ai-стека;
;;   - применяет project-aware конфигурацию (поиск AGENTS.md вверх по
;;     дереву от `default-directory', автоматическое подключение скиллов из
;;     `local-templates/{pi,opencode}/skills/');
;;   - предоставляет тонкий набор команд (chat, summarize, code-review,
;;     plan-and-act, list-sessions) поверх Ellama;
;;   - ленивая загрузка: пока пользователь не вызвал `pro-ai-ellama-open' (или
;;     не нажал соответствующую клавишу), `ellama' не подгружается.
;;
;; Правила:
;;   - Модуль остаётся синтаксически корректным и не падает в окружении без
;;     `ellama' (CI, headless, минимальный Emacs). Все публичные функции
;;     проверяют `pro-ai-ellama--available-p' перед обращением.
;;   - Без явной директивы пользователя модуль НЕ включает
;;     `ellama-tools-allow-all' (даже после `ellama-setup-agentic-coding'):
;;     это политика pro-nix — DLP и irreversible-actions выставляются в
;;     `enforce' / `block', но ask-режим сохраняется (см. defcustom
;;     `pro-ai-ellama-confirmations').
;;   - Регистрация AGENTS.md-контекста идемпотентна: повторный `require'
;;     добавляет только новые пути.
;;
;; Публичная поверхность:
;;   - `pro-ai-ellama-open'              ; запустить Ellama (lazy-load)
;;   - `pro-ai-ellama-summarize'         ; summarize buffer / region
;;   - `pro-ai-ellama-code-review'       ; code-review buffer / region
;;   - `pro-ai-ellama-plan-and-act'      ; запустить plan-and-act loop
;;   - `pro-ai-ellama-list-sessions'     ; открыть transient с сессиями
;;   - `pro-ai-ellama-load-agents-md'    ; пересканировать AGENTS.md вверх
;;   - `pro-ai-ellama-register-skill-dir'; подключить каталог skills
;;
;; Зависимости (все есть в `pro-packages-provided-by-nix'):
;;   - ellama   ; основной пакет
;;   - llm      ; backend provider
;;   - plz, transient, compat, yaml ; ellama runtime deps
;;
;; См. также:
;;   - pro-ai.el          ; entry point через gptel (pro-ai-open-entry)
;;   - pro-ai-anvil.el    ; MCP-сервер для внешних агентов
;;   - docs/agent-configs.md ; локальные шаблоны скиллов

(require 'cl-lib)
(require 'subr-x)
(require 'pro-compat)

;; --- Forward declarations (external packages loaded lazily) ---------------
;; Эти функции определены в подключаемых lazy/elpa пакетах; мы ссылаемся
;; на них по имени в lazy контексте, поэтому byte-compiler не видит их
;; definitions. `declare-function' подавляет warning и помогает
;; `M-x checkdoc' / `elint'.

;; ellama
(declare-function ellama "ellama" (&optional prompt))
(declare-function ellama-summarize "ellama" (&optional beg end))
(declare-function ellama-code-review "ellama" (&optional beg end))
(declare-function ellama-plan-and-act "ellama" ())
(declare-function ellama-transient-session-menu "ellama-transient" ())
(declare-function ellama-session-switch "ellama" ())
(declare-function ellama-skills-global-path "ellama-skills" ())
;; ellama-context
(declare-function ellama-context-add-file "ellama-context" (file))
(declare-function ellama-context-add-directory "ellama-context" (dir))
(declare-function ellama-context-add-image "ellama-context" (image))
;; ellama defcustoms, которые мы устанавливаем напрямую.
(defvar ellama-tools-allow-all)
(defvar ellama-tools-srt-args)
(defvar ellama-context)
(defvar ellama-provider)
;; llm
(declare-function make-llm-openai-compatible "llm-openai" (&rest args))
(declare-function make-llm-ollama "llm-ollama" (&rest args))
;; pro-ai.el (gptel-based shared registry)
(declare-function pro-ai-provider-name "pro-ai" ())
(declare-function pro-ai--provider-config "pro-ai" (provider))
(declare-function pro-ai--provider-models "pro-ai" (provider))
(declare-function pro-ai--load-key-from-authinfo "pro-ai" (host user))

(defgroup pro-ai-ellama nil
  "Ellama — Emacs client for local + cloud LLMs."
  :group 'pro-ai
  :prefix "pro-ai-ellama-")

;; --- Опции ----------------------------------------------------------------

(defcustom pro-ai-ellama-confirmations t
  "Если non-nil, оставлять ask-режим для tool confirmations после setup.
При `nil' — выставить `ellama-tools-allow-all' (опасно; только для
доверенной среды). По умолчанию t — это политика pro-nix."
  :type 'boolean
  :group 'pro-ai-ellama)

(defcustom pro-ai-ellama-load-agents-md t
  "Если non-nil, при первом запуске Ellama пытается найти файлы
инструкций вверх по дереву от `default-directory' и подключить их как
project context. Какие файлы и в каком порядке — см. `pro-ai-ellama-agents-md-filenames'."
  :type 'boolean
  :group 'pro-ai-ellama)

(defcustom pro-ai-ellama-agents-md-filenames
  '("AGENTS.md" "CLAUDE.md" "INSTRUCTIONS.md" ".agentrc")
  "Список имён файлов, которые Ellama загружает как project context
(по убыванию приоритета).

Стандарт `agents.md` предписывает `AGENTS.md`. `CLAUDE.md` — Claude Code
аналог, `INSTRUCTIONS.md` — generic variant для любых tool-агентов,
`.agentrc` — точечный config-style.
Все найденные файлы подцепляются в указанном порядке (поздние
дополняют/перекрывают предыдущие).
"
  :type '(repeat string)
  :group 'pro-ai-ellama)

(defcustom pro-ai-ellama-agents-md-max-depth 8
  "Максимальная глубина поиска AGENTS.md вверх по дереву.
8 = достаточно для прохождения через `home/<user>/Code/<project>/'."
  :type 'integer
  :group 'pro-ai-ellama)

(defcustom pro-ai-ellama-skill-dirs
  (let* ((this-dir (file-name-directory (or load-file-name buffer-file-name)))
         (repo-root (and this-dir
                         (locate-dominating-file this-dir "flake.nix"))))
    (delq nil
          (list
           (and (boundp 'user-emacs-directory)
                (expand-file-name "ellama/skills" user-emacs-directory))
           (and repo-root
                (expand-file-name "local-templates/pi/skills" repo-root))
           (and repo-root
                (expand-file-name "local-templates/opencode/skills" repo-root)))))
  "Список каталогов, в которых Ellama ищет reusable skills.

По умолчанию — пользовательский `~/.config/emacs/ellama/skills/' и
репозиторийные `local-templates/{pi,opencode}/skills/' из pro-nix.
Пути, которых нет на диске, молча игнорируются."
  :type '(repeat directory)
  :group 'pro-ai-ellama)

(defcustom pro-ai-ellama-agentic-profile 'default
  "Какой профиль безопасности применять через `ellama-setup-agentic-coding'.

Возможные значения:
  - `default'   — стандартные настройки: DLP enforce, irreversible block,
                  agent loop 100, ask-режим (если `pro-ai-ellama-confirmations').
  - `autonomous' — то же + `ellama-tools-allow-all'. Требует SRT и
                  доверенной среды; используется редко.
  - nil        — НЕ вызывать `ellama-setup-agentic-coding'; пользователь
                  настроит руками через `customize'."
  :type '(choice (const :tag "Default (DLP enforce, ask)" default)
                 (const :tag "Autonomous (allow-all, requires SRT)" autonomous)
                 (const :tag "Do not auto-apply" nil))
  :group 'pro-ai-ellama)

(defcustom pro-ai-ellama-srt-policy-file
  (let* ((this-dir (file-name-directory (or load-file-name buffer-file-name)))
         (repo-root (and this-dir
                         (locate-dominating-file this-dir "flake.nix"))))
    (when repo-root
      (expand-file-name "local-templates/ellama/srt-autonomous.json" repo-root)))
  "Путь к SRT policy JSON для `ellama-tools-use-srt'. Используется,
когда `pro-ai-ellama-agentic-profile = autonomous'. По умолчанию —
репозиторийный шаблон `local-templates/ellama/srt-autonomous.json'
(скопируйте в `~/.config/ellama/srt-autonomous.json' при необходимости).

Файл описывает allow/deny для filesystem и network — defense-in-depth
поверх `ellama-tools-irreversible-default-action = block'."
  :type '(choice (const :tag "Disabled (nil)" nil)
                 (file :tag "SRT policy file"))
  :group 'pro-ai-ellama)

;; --- Доступность ----------------------------------------------------------

(defun pro-ai-ellama--available-p ()
  "Не-p если пакет `ellama' доступен в runtime."
  (or (featurep 'ellama) (require 'ellama nil t)))

(defun pro-ai-ellama--llm-available-p ()
  "Не-p если `llm' (provider) доступен."
  (or (featurep 'llm) (require 'llm nil t)))

;; --- AGENTS.md project context -------------------------------------------

(defun pro-ai-ellama--find-agents-md (start-dir)
  "Подняться от START-DIR вверх, собирая все файлы из `pro-ai-ellama-agents-md-filenames'.
Возвращает список абсолютных путей в порядке приоритета (AGENTS.md →
CLAUDE.md → INSTRUCTIONS.md → .agentrc). Ограничено `pro-ai-ellama-agents-md-max-depth'.

Возвращает `nil` если ни одного файла не найдено.

Пример: для проекта `/home/user/Code/foo` возвращает список путей
от корня проекта (ближайшие варианты) до корня `$HOME' (последний
вариант — глобальный)."
  (let ((dir (file-name-as-directory (expand-file-name start-dir)))
        (depth 0)
        (collected '()))
    (while (and dir (< depth pro-ai-ellama-agents-md-max-depth))
      (dolist (name pro-ai-ellama-agents-md-filenames)
        (let ((candidate (expand-file-name name dir)))
          (when (file-readable-p candidate)
            (cl-pushnew candidate collected :test #'string=))))
      (setq dir (file-name-directory (directory-file-name dir))
            depth (1+ depth)))
    (nreverse collected)))

(defun pro-ai-ellama--current-agents-md ()
  "Вернуть список путей к AGENTS.md/CLAUDE.md/... для текущего `default-directory'."
  (when pro-ai-ellama-load-agents-md
    (pro-ai-ellama--find-agents-md default-directory)))

;; --- Skills ---------------------------------------------------------------

(defun pro-ai-ellama--skill-paths ()
  "Вернуть список существующих skill-каталогов из `pro-ai-ellama-skill-dirs'."
  (cl-remove-if-not #'file-directory-p pro-ai-ellama-skill-dirs))

(defun pro-ai-ellama-register-skill-dir (dir)
  "Зарегистрировать DIR как дополнительный каталог skills.
Добавляется в `pro-ai-ellama-skill-dirs' и в `ellama-skills-global-path',
если ellama уже загружен."
  (interactive "DDirectory: ")
  (let ((abs (expand-file-name dir)))
    (pro-compat--add-to-list-once 'pro-ai-ellama-skill-dirs abs)
    (when (and (pro-ai-ellama--available-p)
               (fboundp 'ellama-skills-global-path))
      (pro-compat--add-to-list-once 'ellama-skills-global-path abs)
      (message "[pro-ai-ellama] skill dir registered: %s" abs))))

;; --- Setup (идемпотентный) -----------------------------------------------

(defvar pro-ai-ellama--setup-done nil
  "Non-nil если `pro-ai-ellama--apply-setup' уже отработал.")

(defun pro-ai-ellama--apply-setup ()
  "Применить policy + project context к Ellama. Идемпотентно."
  (when (and (pro-ai-ellama--available-p)
             (not pro-ai-ellama--setup-done))
    ;; 1. Skill paths — добавляем только каталоги, которые существуют.
    (dolist (path (pro-ai-ellama--skill-paths))
      (when (fboundp 'ellama-skills-global-path)
        (pro-compat--add-to-list-once 'ellama-skills-global-path path)))
    ;; 2. Agentic-coding profile (если выбран).
    (pcase pro-ai-ellama-agentic-profile
      ('default
       (progn
         (when (fboundp 'ellama-setup-agentic-coding)
           (condition-case err
               (ellama-setup-agentic-coding)
             (error (message "[pro-ai-ellama] setup-agentic-coding failed: %S" err))))
         (when pro-ai-ellama-confirmations
           (setq ellama-tools-allow-all nil))))
      ('autonomous
       (progn
         (when (fboundp 'ellama-setup-agentic-coding)
           (condition-case err
               (ellama-setup-agentic-coding)
             (error (message "[pro-ai-ellama] setup-agentic-coding failed: %S" err))))
         ;; Включаем SRT для filesystem-sandboxing. Если пользователь
         ;; скопировал шаблон local-templates/ellama/srt-autonomous.json
         ;; в ~/.config/ellama/srt-autonomous.json — оно подхватится
         ;; через переменную `pro-ai-ellama-srt-policy-file'.
         (when (and pro-ai-ellama-srt-policy-file
                    (file-readable-p pro-ai-ellama-srt-policy-file)
                    (boundp 'ellama-tools-use-srt))
           (setq ellama-tools-use-srt t
                 ellama-tools-srt-args
                 (list "--settings"
                       (expand-file-name pro-ai-ellama-srt-policy-file))))
         (setq ellama-tools-allow-all t)
         (message "[pro-ai-ellama] WARNING: autonomous mode ON — ellama-tools-allow-all is t, SRT=%s"
                  (and (boundp 'ellama-tools-use-srt) ellama-tools-use-srt))))
      (_ nil))
    ;; 3. Header-line indicators (косметика — состояние сессии в модлайне).
    (when (fboundp 'ellama-context-header-line-global-mode)
      (ellama-context-header-line-global-mode +1))
    (when (fboundp 'ellama-session-header-line-global-mode)
      (ellama-session-header-line-global-mode +1))
    (setq pro-ai-ellama--setup-done t)
    (message "[pro-ai-ellama] setup applied (profile=%s)"
             pro-ai-ellama-agentic-profile)))

;; --- AGENTS.md: добавление в context -------------------------------------

(defun pro-ai-ellama-load-agents-md ()
  "Найти все instruction files (AGENTS.md/CLAUDE.md/INSTRUCTIONS.md/.agentrc)
вверх от `default-directory' и добавить их в Ellama context.

Приоритет загрузки — обратный обходу дерева: сначала **глобальный**
(`~/.agentrc'), затем **выше-уровневый** (`~/CLAUDE.md`), и только потом
**локальный** (`<project>/AGENTS.md'). Это позволяет:
  - локальному файлу иметь приоритет (попадает в context последним);
  - глобальному отрабатывать default.

Если ни одного файла не найдено — сообщение и выход."
  (interactive)
  (let ((paths (pro-ai-ellama--current-agents-md)))
    (cond
     ((null paths)
      (message "[pro-ai-ellama] instruction files (%s) не найдены вверх от %s"
               (mapconcat #'identity pro-ai-ellama-agents-md-filenames ", ")
               default-directory))
     ((not (pro-ai-ellama--available-p))
      (message "[pro-ai-ellama] ellama не загружен — сначала M-x pro-ai-ellama-open"))
     (t
      (condition-case err
          (progn
            (require 'ellama-context)
            ;; Загружаем в обратном порядке: от корня к проекту, чтобы
            ;; локальный AGENTS.md оказался последним в context-е и
            ;; имел приоритет.
            (let ((loaded 0))
              (dolist (p (reverse paths))
                (ellama-context-add-file p)
                (cl-incf loaded))
              (message "[pro-ai-ellama] загружено %d instruction-файл(ов) в context: %s"
                       loaded
                       (mapconcat #'file-name-nondirectory paths ", "))))
        (error
         (message "[pro-ai-ellama] не удалось добавить instruction-файлы: %S" err)))))))

;; --- Ephemeral context ---------------------------------------------------
;;
;; Ellama поддерживает три типа ephemeral-входов: file, directory,
;; image. Каждый добавляется в `ellama-context` для ОДНОГО запроса
;; (не persistent — отличие от load-agents-md). Используется когда
;; нужно прогнать LLM по конкретному файлу/директории без
;; модификации persistent context.

(defun pro-ai-ellama--add-ephemeral-file (file)
  "Добавить FILE в Ellama context как ephemeral input.
Возвращает non-nil при успехе, nil при ошибке.
Идемпотентно: повторный вызов для того же файла не плодит дублей."
  (when (and (stringp file) (file-readable-p file)
             (pro-ai-ellama--available-p))
    (condition-case err
        (progn
          (require 'ellama-context)
          (unless (assoc file (alist-get :file ellama-context))
            (ellama-context-add-file file))
          (message "[pro-ai-ellama] ephemeral file: %s" file)
          t)
      (error
       (message "[pro-ai-ellama] не удалось добавить file %s: %S" file err)
       nil))))

(defun pro-ai-ellama--add-ephemeral-directory (dir)
  "Добавить DIR в Ellama context как ephemeral directory input."
  (when (and (stringp dir) (file-directory-p dir)
             (pro-ai-ellama--available-p))
    (condition-case err
        (progn
          (require 'ellama-context)
          (unless (assoc dir (alist-get :directory ellama-context))
            ;; ellama-context-add-directory — ellama API. Если недоступно,
            ;; fallback: добавляем каждый .el/.org/.md файл отдельно.
            (if (fboundp 'ellama-context-add-directory)
                (ellama-context-add-directory dir)
              (let ((added 0))
                (dolist (f (directory-files dir t "\\.\\(el\\|org\\|md\\|py\\|js\\|ts\\|rs\\|go\\)$"))
                  (when (and (file-readable-p f)
                             (not (member f (mapcar #'car (alist-get :file ellama-context)))))
                    (ellama-context-add-file f)
                    (cl-incf added)))
                (message "[pro-ai-ellama] fallback: %d files из %s" added dir))))
          (message "[pro-ai-ellama] ephemeral directory: %s" dir)
          t)
      (error
       (message "[pro-ai-ellama] не удалось добавить dir %s: %S" dir err)
       nil))))

(defun pro-ai-ellama--add-ephemeral-image (image)
  "Добавить IMAGE в Ellama context как ephemeral image input."
  (when (and (stringp image) (file-readable-p image)
             (pro-ai-ellama--available-p))
    (condition-case err
        (progn
          (require 'ellama-context)
          (unless (assoc image (alist-get :image ellama-context))
            (ellama-context-add-image image))
          (message "[pro-ai-ellama] ephemeral image: %s" image)
          t)
      (error
       (message "[pro-ai-ellama] не удалось добавить image %s: %S" image err)
       nil))))

(defun pro-ai-ellama-add-buffer-as-context ()
  "Сохранить текущий buffer в /tmp и добавить как ephemeral file context.
Полезно когда нужно прогнать LLM по unsaved buffer contents
(без записи на диск в постоянное место)."
  (interactive)
  (let* ((name (or (buffer-file-name) (buffer-name)))
         (tmp-file (make-temp-file (concat (file-name-base (or name "buffer"))
                                          "-ellama-")
                                   nil (concat "." (file-name-extension name))))
         (coding-system-for-write 'utf-8))
    (with-temp-file tmp-file
      (set-buffer-multibyte t)
      (insert-buffer-substring (current-buffer)))
    (when (pro-ai-ellama--add-ephemeral-file tmp-file)
      (message "[pro-ai-ellama] buffer saved to %s и добавлен в context"
               tmp-file))))

(defun pro-ai-ellama-add-region-as-context ()
  "Сохранить активную region в /tmp file и добавить как ephemeral file context."
  (interactive)
  (cond
   ((not (use-region-p))
    (message "[pro-ai-ellama] нет активной region — выделите текст и повторите"))
   (t
    (let* ((start (region-beginning))
           (end (region-end))
           (tmp-file (make-temp-file "ellama-region-" nil ".txt"))
           (coding-system-for-write 'utf-8))
      (write-region start end tmp-file)
      (when (pro-ai-ellama--add-ephemeral-file tmp-file)
        (message "[pro-ai-ellama] region [%d:%d] saved to %s и добавлен в context"
                 start end tmp-file))))))

;; --- Session management ------------------------------------------------
;;
;; Ellama хранит persistent sessions в `ellama-sessions-directory'
;; (default `~/.config/emacs/ellama/sessions/'). Каждая сессия — файл
;; с историей сообщений + метаданными. Эти команды помогают
;; пользователю управлять этим каталогом без запоминания путей.

(defvar pro-ai-ellama-sessions-directory
  (expand-file-name "ellama/sessions/" user-emacs-directory)
  "Каталог persistent Ellama sessions. По умолчанию
`~/.config/emacs/ellama/sessions/'.")

(defun pro-ai-ellama-list-sessions-files ()
  "Вернуть список файлов сессий в `pro-ai-ellama-sessions-directory'.
Сортирует по mtime (новые first)."
  (when (file-directory-p pro-ai-ellama-sessions-directory)
    (let ((files (directory-files pro-ai-ellama-sessions-directory t "\\.json$" t)))
      (sort files
            (lambda (a b)
              (time-less-p (nth 5 (file-attributes b))
                            (nth 5 (file-attributes a))))))))

(defun pro-ai-ellama-session-count ()
  "Вернуть количество persistent sessions."
  (length (pro-ai-ellama-list-sessions-files)))

(defun pro-ai-ellama--session-preview (file)
  "Вернуть первую непустую строку FILE, или '<unreadable>' при ошибке."
  (condition-case nil
      (with-temp-buffer
        (insert-file-contents file nil 0 200)
        (string-trim (car (split-string (buffer-string) "\n"))))
    (error "<unreadable>")))

(defun pro-ai-ellama-show-sessions ()
  "Показать список Ellama sessions в отдельном буфере.
Полезно для быстрого обзора: имя файла, размер, mtime, превью
первой строки."
  (interactive)
  (let ((files (pro-ai-ellama-list-sessions-files)))
    (with-output-to-temp-buffer "*pro-ai-ellama-sessions*"
      (princ (format "Ellama sessions: %d\n\n" (length files)))
      (dolist (f files)
        (let* ((attrs (file-attributes f))
               (size (nth 7 attrs))
               (mtime (nth 5 attrs))
               (preview (pro-ai-ellama--session-preview f)))
          (princ (format "  %s\n    size=%d  mtime=%s\n    %s\n\n"
                         (file-name-nondirectory f)
                         size
                         (format-time-string "%Y-%m-%d %H:%M" mtime)
                         preview))))
      (princ (format "\nTotal: %d sessions\n" (length files)))
    (message "[pro-ai-ellama] %d sessions" (length files)))))

(defun pro-ai-ellama-delete-session (session-file)
  "Удалить SESSION-FILE из `pro-ai-ellama-sessions-directory'.
Interactive prompt требует подтверждения."
  (interactive (list (completing-read "Delete session: "
                                     (mapcar #'file-name-nondirectory
                                             (pro-ai-ellama-list-sessions-files))
                                     nil t)))
  (let* ((name (expand-file-name session-file pro-ai-ellama-sessions-directory)))
    (when (and (file-exists-p name)
               (y-or-n-p (format "Delete session %s? " session-file)))
      (delete-file name)
      (message "[pro-ai-ellama] session %s удалена" session-file))))

;; --- Публичные команды ---------------------------------------------------

(defun pro-ai-ellama-open ()
  "Открыть Ellama chat buffer (lazy-load + setup).
Безопасный entry point: проверяет наличие ellama, иначе выводит
информативное сообщение. `C-u` — стартовать новую сессию с выбором модели."
  (interactive)
  (if (pro-ai-ellama--available-p)
      (progn
        (pro-ai-ellama--apply-setup)
        (call-interactively #'ellama))
    (message "[pro-ai-ellama] пакет `ellama' не найден. Пересоберите Emacs-профиль через `just switch' (ellama в `modules/pro-users-nixos.nix`).")))

(defun pro-ai-ellama-summarize ()
  "Summarize the active region (or buffer) через Ellama."
  (interactive)
  (if (pro-ai-ellama--available-p)
      (progn
        (pro-ai-ellama--apply-setup)
        (pro-ai-ellama-load-agents-md)
        (call-interactively #'ellama-summarize))
    (message "[pro-ai-ellama] пакет `ellama' не найден")))

(defun pro-ai-ellama-code-review ()
  "Code-review активной region/buffer через Ellama.
Автоматически подключает AGENTS.md как project context."
  (interactive)
  (if (pro-ai-ellama--available-p)
      (progn
        (pro-ai-ellama--apply-setup)
        (pro-ai-ellama-load-agents-md)
        (call-interactively #'ellama-code-review))
    (message "[pro-ai-ellama] пакет `ellama' не найден")))

(defun pro-ai-ellama-plan-and-act ()
  "Запустить plan-and-act loop (агент: составить план, выполнить шаги)."
  (interactive)
  (if (pro-ai-ellama--available-p)
      (progn
        (pro-ai-ellama--apply-setup)
        (pro-ai-ellama-load-agents-md)
        (call-interactively #'ellama-plan-and-act))
    (message "[pro-ai-ellama] пакет `ellama' не найден")))

(defun pro-ai-ellama-list-sessions ()
  "Открыть transient с активными сессиями (compact / switch / rename)."
  (interactive)
  (if (pro-ai-ellama--available-p)
      (progn
        (pro-ai-ellama--apply-setup)
        (condition-case err
            (progn
              (require 'ellama-transient)
              (ellama-transient-session-menu))
          (error
           (message "[pro-ai-ellama] session menu failed: %S" err)
           (call-interactively #'ellama-session-switch))))
    (message "[pro-ai-ellama] пакет `ellama' не найден")))

;; --- Привязки (через pro-keys registry) ----------------------------------

(defun pro-ai-ellama--register-keys ()
  "Зарегистрировать предложения для emacs-keys.org через `pro-keys' registry."
  (when (fboundp 'pro/register-module-keys)
    (pro/register-module-keys
     'pro-ai-ellama
     '(("C-c e e" . pro-ai-ellama-open)
       ("C-c e s" . pro-ai-ellama-summarize)
       ("C-c e r" . pro-ai-ellama-code-review)
       ("C-c e p" . pro-ai-ellama-plan-and-act)
       ("C-c e l" . pro-ai-ellama-list-sessions)
       ("C-c e a" . pro-ai-ellama-load-agents-md)
       ("C-c e m" . pro-ai-ellama-use-shared-model)
       ("C-c e b" . pro-ai-ellama-add-buffer-as-context)
       ("C-c e r" . pro-ai-ellama-add-region-as-context)
       ("C-c e h" . pro-ai-ellama-show-sessions)
       ("C-c e d" . pro-ai-ellama-delete-session)))))

;; --- Shared AI model/provider registry ------------------------------------
;;
;; В pro-nix каталог моделей и ключей живёт в `pro-ai/ai-models.json'
;; (см. pro-ai.el: `pro-ai-models-file'). Ellama может реuse-ить те
;; же provider-credentials из authinfo, но сейчас хранит выбор в
;; `ellama-provider' отдельно от `gptel-backend'. Эти функции
;; связывают обе системы: пользователь выбирает backend один раз —
;; и gptel, и ellama используют одно и то же.

(defun pro-ai-ellama--llm-make-from-shared (provider)
  "Сконструировать `llm-make-*' instance для PROVIDER из `pro-ai' registry.

PROVIDER — символ/строка из `pro-ai-models.json' (`openrouter',
`siliconflow', `aitunnel'). Берёт host, endpoint, auth_user,
auth_host из `pro-ai--provider-config' и ключ из authinfo.
Возвращает llm-provider struct или nil, если конструктор не
найден в runtime (например, `llm-openai' не загружен)."
  (when (and (pro-ai-ellama--llm-available-p)
             (fboundp 'pro-ai--provider-config))
    (let* ((config (pro-ai--provider-config provider))
           (auth-host (or (alist-get 'auth_host config)
                         (alist-get 'host config)))
           (key (pro-ai--load-key-from-authinfo
                  auth-host
                  (or (alist-get 'auth_user config) "token")))
           (backend (or (alist-get 'backend config) 'openai)))
      (cond
       ((null key) nil)
       ((and (eq backend 'openai) (fboundp 'make-llm-openai-compatible))
        (make-llm-openai-compatible
         :key key
         :url (alist-get 'endpoint config)
         :chat-model (or (car (pro-ai--provider-models config)) "unset")))
       ((and (eq backend 'ollama) (fboundp 'make-llm-ollama))
        (make-llm-ollama
         :host (alist-get 'host config)
         :chat-model (or (car (pro-ai--provider-models config)) "unset")
         :embedding-model "nomic-embed-text"))))))

(defun pro-ai-ellama-use-shared-model ()
  "Взять активный provider из pro-ai.el и применить к Ellama.

Синхронизирует `ellama-provider' с `gptel-backend'/`gptel-model',
используя общий ключ из authinfo. Удобно когда оба стека
(gptel через curl и Ellama через `llm' пакет) должны использовать
одну модель OpenAI-compatible — например, aitunnel или openrouter."
  (interactive)
  (cond
   ((not (pro-ai-ellama--llm-available-p))
    (message "[pro-ai-ellama] `llm' пакет не загружен — нужен для shared registry"))
   ((not (pro-ai-ellama--available-p))
    (message "[pro-ai-ellama] ellama не загружен — сначала M-x pro-ai-ellama-open"))
   ((not (fboundp 'pro-ai--provider-config))
    (message "[pro-ai-ellama] pro-ai.el не загружен (нет `pro-ai--provider-config')"))
   (t
    (let* ((provider (pro-ai-provider-name))
           (llm-instance (pro-ai-ellama--llm-make-from-shared provider)))
      (cond
       ((null llm-instance)
        (message "[pro-ai-ellama] не удалось построить llm-instance для %s — проверьте authinfo"
                 provider))
(t
         (setq ellama-provider llm-instance)
         (message "[pro-ai-ellama] provider обновлён: %s (model=%s)"
                  provider
                  (or (alist-get 'chat-model
                                (cdr (assq 'model (cdr llm-instance))))
                     "auto"))))))))

;; --- Org-babel integration ----------------------------------------------
;;
;; Регистрирует язык `ellama' для org-babel. Использование:
;;
;;   #+begin_src ellama :results value
;;   Summarize this Org subtree in one paragraph.
;;   #+end_src
;;
;; Содержимое блока передаётся как prompt; результат вставляется как
;; `:results value`. Регистрация `org-babel-execute:ellama` совместима с
;; `org-babel-do-load-languages`, но не требует предварительной
;; декларации через `org-babel-load-languages' (мы ставим функцию
;; напрямую).

(defun org-babel-execute:ellama (body params)
  "Выполнить Ellama на BODY с org-babel PARAMS.
Возвращает строку — результат LLM. Если `ellama-stream' доступен,
использует его для синхронного получения ответа; иначе просто
вызывает `ellama-chat-sync' (если есть) или возвращает error."
  (condition-case err
      (let ((prompt (org-babel-trim body))
            (result nil))
        (with-temp-buffer
          (progn
            (require 'ellama)
            (if (fboundp 'ellama-chat-sync)
                (setq result (ellama-chat-sync prompt))
              (ellama-chat prompt)
              (setq result (buffer-string))))
          result))
    (error
     (format "## Ellama error: %S" err))))

;; Регистрация только если `org' загружен (lazy).
(with-eval-after-load 'org
  (with-eval-after-load 'ob-core
    ;; Указываем org-babel что `ellama' — известный язык.
    (add-to-list 'org-babel-load-languages '(ellama . t))
    ;; Безопасный fallback для users без явной регистрации.
    (unless (assoc "ellama" org-babel-interpreters)
      (push '("ellama" . org-babel-execute:ellama) org-babel-interpreters))))

;; Регистрация предложений откладывается до момента, когда pro-keys загружен.
(with-eval-after-load 'pro-keys
  (pro-ai-ellama--register-keys))

(provide 'pro-ai-ellama)
;;; pro-ai-ellama.el ends here
