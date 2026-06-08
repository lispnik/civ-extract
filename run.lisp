;;;; run.lisp -- batch entry point.  Usage:
;;;;   sbcl --non-interactive --load run.lisp
(asdf:load-system :civ-extract)
;; Point :source-dir at wherever the game's .PIC files live.
(civ-extract:extract-all
 :source-dir #p"~/Projects/CIVILIZATION/"
 :out-dir #p"extracted/")
