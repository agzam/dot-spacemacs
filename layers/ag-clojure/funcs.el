;;; funcs.el --- ag-clojure layer functions file.
;;
;; Copyright (c) 2012-2016 Sylvain Benner & Contributors
;;
;; Author: Ag Ibragimov <agzam.ibragimov@gmail.com>
;; URL: https://github.com/agzam/dot-spacemacs
;;
;; This file is not part of GNU Emacs.
;;
;;; License: GPLv3

(defun switch-to-nrepl-window (&optional PROMT-PROJECT CLJS-TOO)
  (save-selected-window)
  (let* ((nrepl-buf (nrepl-make-buffer-name
                     nrepl-server-buffer-name-template
                     (clojure-project-dir (cider-current-dir)))))
    (when (not (equal (buffer-name) nrepl-buf))
      (switch-to-buffer-other-window nrepl-buf))))

;; (with-eval-after-load 'cider
;;   (advice-add 'cider-jack-in :after #'switch-to-nrepl-window)
;;   ;; (add-hook 'cider-connected-hook (lambda ()
;;   ;;                                   (save-selected-window
;;   ;;                                     (switch-to-nrepl-window)
;;   ;;                                     (split-window-below-and-focus)
;;   ;;                                     (switch-to-buffer (cider-current-repl-buffer)))))
;;   )

(defun clojars-find ()
  "Lookup for symbol at point on clojars. Useful for updating packages in project.clj"
  (interactive)
  (clojars (symbol-at-point)))

(defun cljr-toggle-ignore-form ()
  "clojure - ignore (comment) form"
  (interactive)
  (if (search-backward "#_" 2 t 1)
      (delete-char 2)
    (progn
      (let ((fc (following-char)))
        (cond ((-contains? '( ?\) ?\] ?\} ) fc) (paredit-backward-up))
              ((-contains? '( ?\( ?\[ ?\: ?\{ ) fc) nil)
              (t (beginning-of-thing 'sexp)))
        (insert "#_")))))

(defun clj-fully-qualified-symbol-at-point ()
  (interactive)
  (let ((sym (cond ((lsp--capability :hoverProvider)
                    (let ((s (-some->> (lsp--text-document-position-params)
                               (lsp--make-request "textDocument/hover")
                               (lsp--send-request)
                               (gethash "contents")
                               (gethash "value"))))
                      (string-match "\\(```.*\n\\)\\(.*\\)\n\\(```\\)" s)
                      (string-trim (match-string 2 s))))

                   ((cider-connected-p)
                    (let ((cb (lambda (x)
                                (when-let ((v (nrepl-dict-get x "value"))
                                           (s (replace-regexp-in-string "[()]" "" v)))
                                  (message (string-trim s))
                                  (kill-new s)))))
                      (cider-interactive-eval
                       (concat "`(" (cider-symbol-at-point t) ")")
                       cb)))
                   (t (message "Neither lsp nor cider are connected")))))
    (message sym)
    (kill-new sym)
    sym))

(defun re-frame-jump-to-reg ()
  "Borrowed from https://github.com/oliyh/re-jump.el"
  (interactive)
  (let* ((kw (cider-symbol-at-point 'look-back))
         (ns-qualifier (and
                        (string-match "^:+\\(.+\\)/.+$" kw)
                        (match-string 1 kw)))
         (kw-ns (if ns-qualifier
                    (cider-resolve-alias (cider-current-ns) ns-qualifier)
                  (cider-current-ns)))
         (kw-to-find (concat "::" (replace-regexp-in-string "^:+\\(.+/\\)?" "" kw))))

    (when (and ns-qualifier (string= kw-ns (cider-current-ns)))
      (error "Could not resolve alias \"%s\" in %s" ns-qualifier (cider-current-ns)))

    (progn (cider-find-ns "-" kw-ns)
           (search-forward-regexp (concat "reg-[a-zA-Z-]*[ \\\n]+" kw-to-find) nil 'noerror))))

(defun add-reframe-regs-to-imenu ()
  (add-to-list
   'imenu-generic-expression
   '("re-frame" "(*reg-\\(event-db\\|sub\\|sub-raw\\|fx\\|event-fx\\|event-ctx\\|cofx\\)[ \n]+\\([^\t \n]+\\)" 2)
   t))

(defun cljr-ns-align ()
  "Align ns requires."
  (interactive)
  (end-of-buffer)
  (when (re-search-backward "^\(ns.*\\(\n.*\\)*\(:require" nil t nil)
    (mark-sexp)
    (align-regexp (region-beginning)
                  (region-end)
                  "\\(\\s-*\\)\\s-:")))

(defun kill-cider-buffers ()
  "Kill all CIDER buffers without asking any questions. Useful to execute when Emacs gets stuck."
  (interactive)
  (flet ((kill-buffer-ask (buffer) (kill-buffer buffer)))
    (let ((kill-buffer-query-functions
           (delq 'process-kill-buffer-query-function kill-buffer-query-functions))))
    (kill-matching-buffers "cider")))

(defun format-edn ()
  "Formats edn without cider"
  (interactive)
  (let ((start (when mark-active (region-beginning)))
        (end (when mark-active (region-end))))
    (let ((jet (executable-find "jet")))
      (call-process-region
       start end jet
       :delete '(t nil)
       :display "--pretty"))))

(defun clojure-unalign (beg end)
  "Un-align (remove extra spaces) in vertically aligned sexp around the point."
  (interactive (if (use-region-p)
                   (list (region-beginning) (region-end))
                 (save-excursion
                   (let ((end (progn (end-of-defun)
                                     (point))))
                     (clojure-backward-logical-sexp)
                     (list (point) end)))))

  (save-excursion
    (save-restriction
      (narrow-to-region beg end)
      (goto-char (point-min))
      (while (re-search-forward "\\s-+" nil t)
        (replace-match " "))
      (indent-region beg end))))

;;; funcs.el ends here
