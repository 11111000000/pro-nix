;;; pro-docker.el --- Docker integration for pro-nix -*- lexical-binding: t; -*-
;;
;; Тонкий слой поверх пакета `docker' (https://github.com/emacs-pe/docker.el):
;;   - подключается, если пакет заявлен Nix'ом (см. pro-packages-provided-by-nix)
;;     и доступен на load-path;
;;   - регистрирует биндинги на основные буферы (containers/images/volumes/networks);
;;   - активирует docker-tramp (`/docker:<container>:<path>') — открытие файлов
;;     внутри контейнера прямо из dired/find-file.
;;
;; Модуль намеренно лёгкий: тяжёлая настройка (логины, prune-политики)
;; остаётся пользователю.

(defgroup pro-docker nil
  "Docker integration helpers for pro-nix." :group 'pro)

(defcustom pro-docker-enable t
  "Enable pro docker helpers (containers/images/volumes/networks buffers + tramp)."
  :type 'boolean :group 'pro-docker)

(defcustom pro-docker-keymap-prefix "C-c d"
  "Prefix for pro-docker interactive commands (e.g. C-c d c)."
  :type 'string :group 'pro-docker)

(defvar pro-docker-keymap (make-sparse-keymap)
  "Keymap for `pro-docker-mode'. Not bound globally; commands live under
`pro-docker-keymap-prefix' for explicit access.")

(defun pro-docker--try-require (feature)
  "Try to require FEATURE silently. Return non-nil on success."
  (condition-case nil
      (progn (require feature nil t) (featurep feature))
    (error nil)))

(defun pro-docker--available-p ()
  "Return non-nil if the `docker' package can be loaded right now."
  (pro-docker--try-require 'docker))

(defun pro-docker--declared-p ()
  "Return non-nil if `docker' is declared by Nix in
`pro-packages-provided-by-nix' (advisory)."
  (and (boundp 'pro-packages-provided-by-nix)
       (memq 'docker pro-packages-provided-by-nix)))

;;;###autoload
(defun pro-docker-containers ()
  "Open the docker containers list buffer."
  (interactive)
  (unless (pro-docker--available-p)
    (user-error "pro-docker: пакет `docker' не загружен (проверьте Nix-профиль)"))
  (docker-containers-list))

;;;###autoload
(defun pro/docker-images ()
  "Open the docker images list buffer."
  (interactive)
  (unless (pro-docker--available-p)
    (user-error "pro-docker: пакет `docker' не загружен (проверьте Nix-профиль)"))
  (docker-images-list))

;;;###autoload
(defun pro/docker-volumes ()
  "Open the docker volumes list buffer."
  (interactive)
  (unless (pro-docker--available-p)
    (user-error "pro-docker: пакет `docker' не загружен (проверьте Nix-профиль)"))
  (docker-volumes-list))

;;;###autoload
(defun pro/docker-networks ()
  "Open the docker networks list buffer."
  (interactive)
  (unless (pro-docker--available-p)
    (user-error "pro-docker: пакет `docker' не загружен (проверьте Nix-профиль)"))
  (docker-networks-list))

(define-key pro-docker-keymap (kbd "c") #'pro-docker-containers)
(define-key pro-docker-keymap (kbd "i") #'pro/docker-images)
(define-key pro-docker-keymap (kbd "v") #'pro/docker-volumes)
(define-key pro-docker-keymap (kbd "n") #'pro/docker-networks)

(when pro-docker-enable
  ;; Глобальный префикс `pro-docker-keymap-prefix' (по умолчанию C-c d)
  ;; активируется всегда — это явный, легко отключаемый «opt-in»,
  ;; аналогично другим pro-* модулям.
  (global-set-key (kbd pro-docker-keymap-prefix) pro-docker-keymap)

  ;; docker-tramp: открытие файлов внутри контейнера по пути
  ;; /docker:<container>:/<path> — работает сразу, если docker.el загружен.
  (when (pro-docker--available-p)
    (with-eval-after-load 'docker
      (when (fboundp 'docker-tramp-activate)
        (ignore-errors (docker-tramp-activate))))))

(provide 'pro-docker)

;;; pro-docker.el ends here
