;;;; civ-extract.asd
;;;;
;;;; ASDF system for extracting graphics assets from the DOS game
;;;; Sid Meier's Civilization (1991).  Dependencies are managed with ocicl.
;;;;
;;;; The .PIC / .PAL files use MicroProse's IFF-like chunked container:
;;;;   - "M0" chunk: 256-entry VGA palette (6-bit RGB)
;;;;   - "E0" chunk: 256-entry 8bpp->4bpp colour conversion table
;;;;   - "X0" chunk: 8bpp image, LZW + RLE compressed
;;;;   - "X1" chunk: 4bpp image, LZW + RLE compressed
;;;; The compression algorithm matches the (CC0) CivOne reference decoder.

(asdf:defsystem "civ-extract"
  :description "Extract graphics assets (with sprite index) from DOS Civilization .PIC files."
  :author "mkennedy@swiftsensors.com"
  :license "CC0"
  :version "1.0.0"
  :depends-on ("zpng" "com.inuoe.jzon")
  :serial t
  :pathname "src"
  :components ((:file "package")
               (:file "binary")
               (:file "lzw")
               (:file "rle")
               (:file "palette")
               (:file "pic")
               (:file "png")
               (:file "sprites")
               (:file "extract")))
