# Decisions: Emacs packages ownership

Этот документ фиксирует решения о том, какие Emacs-пакеты находятся под управлением Nix
и какие могут быть обновлены пользователем в своём Emacs user layer.

Decision: gptel -> Nix (system)
- Pressure: Feature / Reproducibility
- Rationale: gptel используется как провайдер AI в базовом профиле; держать его в Nix
  упрощает воспроизводимость с точки зрения образов и CI. Если пользователь нуждается
  в более новой версии, он может установить её локально и зафиксировать решение в
  `~/.config/emacs/decisions.el` (см. пример ниже).

Migration
- Impact: None on runtime; users who have installed gptel from MELPA will continue
  to have their version in the user layer (user wins at runtime if they shadow the package).
- Strategy: keep gptel in nix/provided-packages.nix; document the decision here and
  recommend using user-level pinning for any MELPA override.

User example (~/ .config/emacs/decisions.el)

```
;; decisions.el example
(setq pro-packages-decisions
      '((gptel . always)  ;; user wants always-install-from-MELPA despite Nix
        (somepkg . never)))
```

Notes
- This decisions file is a living document; add entries for other contested packages as needed.
