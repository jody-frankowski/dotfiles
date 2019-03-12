;;(require 'org)

;; Also set in config.org, but we duplicate it here so it doesn't
;; bother us when we edit the emacs config that is just changed, thus
;; regenerated.
(setq vc-follow-symlinks t)

;; Load the emacs code from the org file
;; Seems like elisp wants absolute paths
(org-babel-load-file (expand-file-name "config.org" user-emacs-directory))
