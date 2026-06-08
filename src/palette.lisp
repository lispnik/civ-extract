;;;; palette.lisp -- palettes.  A palette is a (256 x 4) array of (r g b a)
;;;; octets.  Index 0 is always transparent (alpha 0), matching the game's use
;;;; of colour 0 as the transparency key.

(in-package #:civ-extract)

(defun make-palette ()
  (make-array '(256 4) :element-type '(unsigned-byte 8) :initial-element 0))

(defun (setf palette-rgb) (rgb palette index)
  (destructuring-bind (r g b) rgb
    (setf (aref palette index 0) r
          (aref palette index 1) g
          (aref palette index 2) b
          (aref palette index 3) (if (zerop index) 0 255)))
  rgb)

(defparameter *default-palette-16*
  ;; CivOne default 16-colour palette (shades 0/104/183/255), entry 0 transparent.
  (let ((s #(0 104 183 255))
        (pal (make-palette)))
    (flet ((c (i r g b) (setf (palette-rgb pal i)
                              (list (aref s r) (aref s g) (aref s b)))))
      (c 0 0 0 0)                       ; transparent
      (c 1 0 0 2) (c 2 0 2 0) (c 3 0 2 2) (c 4 2 0 0) (c 5 0 0 0)
      (c 6 2 1 0) (c 7 2 2 2) (c 8 1 1 1) (c 9 1 1 3) (c 10 1 3 1)
      (c 11 1 3 3) (c 12 3 1 1) (c 13 3 1 3) (c 14 3 3 1) (c 15 3 3 3))
    ;; replicate the 16 colours across all 256 slots (only 0-15 are ever used
    ;; by 4-bit images, but this keeps lookups total).
    (dotimes (i 256)
      (let ((j (mod i 16)))
        (setf (aref pal i 0) (aref pal j 0)
              (aref pal i 1) (aref pal j 1)
              (aref pal i 2) (aref pal j 2)
              (aref pal i 3) (if (zerop i) 0 (aref pal j 3)))))
    pal))
