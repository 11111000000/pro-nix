;;; pro-epistemology.el --- Package knowledge graph

(require 'subr-x)

(defvar pro--knowledge-graph nil)
(defvar pro--knowledge-trace nil)

(defun pro--knowing-agent (pkg)
  "Return the knowledge source for PKG."
  (cond
   ((pro--package-declared-by-nix-p pkg) 'nix)
   ((pro--package-provided-p pkg) 'runtime)
   (t 'unknown)))

(defun pro--trace-knowledge (pkg &optional reason)
  "Log PKG acquisition."
  (push (cons pkg reason) pro--knowledge-trace))

(defun pro--reconstruct ()
  "Build knowledge graph."
  (setq pro--knowledge-graph nil)
  (dolist (pkg (if (boundp 'pro-packages-provided-by-nix)
                   pro-packages-provided-by-nix))
    (push (cons pkg (pro--knowing-agent pkg)) pro--knowledge-graph)))

(defun pro--epistemic-report ()
  "Return report."
  (format "[pro-epistemology] packages: %d" (length pro--knowledge-graph)))

(provide 'pro-epistemology)