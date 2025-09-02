;; Also set in config.org, but we duplicate it here so it doesn't
;; bother us when we edit the emacs config that is just changed, thus
;; regenerated.
(setq vc-follow-symlinks t)

;; Install https://github.com/raxod502/straight.el which provides a
;; compatibility layer with use-package and handles org better
;; (https://github.com/jwiegley/use-package/issues/319#issuecomment-316899201). We
;; do this in init.el and not config.org in order to pull the org package before
;; ever using it.
(defvar bootstrap-version)
(let ((bootstrap-file
       (expand-file-name
        "straight/repos/straight.el/bootstrap.el"
        (or (bound-and-true-p straight-base-dir)
            user-emacs-directory)))
      (bootstrap-version 7))
  (unless (file-exists-p bootstrap-file)
    (with-current-buffer
        (url-retrieve-synchronously
         "https://raw.githubusercontent.com/radian-software/straight.el/develop/install.el"
         'silent 'inhibit-cookies)
      (goto-char (point-max))
      (eval-print-last-sexp)))
  (load bootstrap-file nil 'nomessage))

;; Install the package 'use-package' in order to have the macro 'use-package'
(straight-use-package 'use-package)
;; This avoids us setting ':straight t' for every use-package call because we
;; want use-package to use straight instead of the default package.el every
;; time.  See
;; https://github.com/raxod502/straight.el#integration-with-use-package and
;; https://github.com/jwiegley/use-package#usage-with-other-package-managers
(customize-set-variable 'straight-use-package-by-default t)

;; Enable shallow clones
;; Re-enable this setting when https://github.com/raxod502/straight.el/issues/527 is closed
;; (customize-set-variable 'straight-vc-git-default-clone-depth 1)

;; Pull the org packages
(straight-use-package '(org-plus-contrib :type git :host sourcehut :repo "bzg/org-contrib"))
(straight-use-package '(org :type git :host github :repo "emacs-straight/org-mode"))

;; The lastest version of org-babel-load-file doesn't follow symlinks when it
;; checks if the org file is newer :/
(require 'org-macs)
(require 'ob-tangle)
(defun me/org-babel-load-file (file &optional compile)
  "Load Emacs Lisp source code blocks in the Org FILE.
This function exports the source code using `org-babel-tangle'
and then loads the resulting file using `load-file'.  With
optional prefix argument COMPILE, the tangled Emacs Lisp file is
byte-compiled before it is loaded."
  (interactive "fFile to load: \nP")
  (let* ((tangled-file (concat (file-name-sans-extension file) ".el")))
    ;; Tangle only if the Org file is newer than the Elisp file.
    (unless (org-file-newer-than-p
             tangled-file
             (file-attribute-modification-time (file-attributes (file-truename file))))
      (org-babel-tangle-file file tangled-file "emacs-lisp"))
    (if compile
        (progn
          (byte-compile-file tangled-file 'load)
          (message "Compiled and loaded %s" tangled-file))
      (load-file tangled-file)
      (message "Loaded %s" tangled-file))))

;; Load the emacs code from the org file
;; Seems like elisp wants absolute paths
(me/org-babel-load-file (expand-file-name "config.org" user-emacs-directory))
