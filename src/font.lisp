;;;; font.lisp -- extract the bitmap fonts from Civilization's FONTS.CV.
;;;;
;;;; FONTS.CV layout (matches the CC0 CivOne FontSet reader):
;;;;   u16  count
;;;;   count * u16  offsets   (each points at a font's glyph-bitmap data)
;;;; For a font whose pointer is OFF:
;;;;   bytes OFF-8..OFF-2  = first, last, byte-length, top-row, bottom-row,
;;;;                         space-x, space-y
;;;;   the CHARCOUNT bytes ending at OFF-9 are the per-char pixel widths
;;;;   glyph bitmaps start at OFF, stored row-interleaved across all chars:
;;;;     byte(char ci, row r, col c) = bytes[OFF + ci*byteLen
;;;;                                          + r*(byteLen*charcount) + c]
;;;;   each glyph row is 1bpp, MSB-first.

(in-package #:civ-extract)

(defstruct font
  index first last byte-length top bottom height space-x space-y
  widths            ; vector of per-char pixel widths
  bytes off charcount)

(defun parse-fonts (path)
  "Parse FONTS.CV at PATH into a list of FONT structs."
  (let* ((bytes (read-file-octets path))
         (count (u16 bytes 0))
         (fonts '()))
    (dotimes (fi count)
      (let* ((off (u16 bytes (+ 2 (* 2 fi))))
             (first (u8 bytes (- off 8)))
             (last (u8 bytes (- off 7)))
             (byte-len (u8 bytes (- off 6)))
             (top (u8 bytes (- off 5)))
             (bottom (u8 bytes (- off 4)))
             (cc (1+ (- last first)))
             (widths (make-array cc)))
        (dotimes (ci cc)
          (setf (aref widths ci) (u8 bytes (+ (- off 9 cc) 1 ci))))
        (push (make-font :index fi :first first :last last :byte-length byte-len
                         :top top :bottom bottom :height (1+ (- bottom top))
                         :space-x (u8 bytes (- off 3)) :space-y (u8 bytes (- off 2))
                         :widths widths :bytes bytes :off off :charcount cc)
              fonts)))
    (nreverse fonts)))

(defun font-glyph-bit-p (font ci row x)
  "T if pixel (ROW,X) of char index CI in FONT is set."
  (let* ((bl (font-byte-length font))
         (b (aref (font-bytes font)
                  (+ (font-off font) (* ci bl)
                     (* row (* bl (font-charcount font)))
                     (floor x 8)))))
    (logbitp (- 7 (mod x 8)) b)))

(defun render-font-sheet (font path &key (columns 16))
  "Render every glyph of FONT into a specimen-sheet PNG (white on transparent)."
  (let* ((cc (font-charcount font))
         (h (font-height font))
         (maxw (max 1 (reduce #'max (font-widths font) :initial-value 1)))
         (rows (ceiling cc columns))
         (cw (1+ maxw)) (ch (1+ h))
         (sw (+ 1 (* columns cw)))
         (sh (+ 1 (* rows ch)))
         (pixels (make-array (list sh sw) :element-type '(unsigned-byte 8)))
         (pal (make-palette)))
    (setf (aref pal 1 0) 255 (aref pal 1 1) 255 (aref pal 1 2) 255 (aref pal 1 3) 255)
    (dotimes (ci cc)
      (let ((width (min (aref (font-widths font) ci) (* (font-byte-length font) 8)))
            (cx (+ 1 (* (mod ci columns) cw)))
            (cy (+ 1 (* (floor ci columns) ch))))
        (dotimes (row h)
          (dotimes (x width)
            (when (font-glyph-bit-p font ci row x)
              (setf (aref pixels (+ cy row) (+ cx x)) 1))))))
    (write-indexed-png pixels pal sw sh path)))