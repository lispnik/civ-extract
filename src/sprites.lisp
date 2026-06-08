;;;; sprites.lisp -- sprite-sheet definitions and grid slicing.
;;;;
;;;; Many PIC files are sprite sheets: a grid of fixed-size tiles.  A SHEET-SPEC
;;;; describes how to cut one.  The classic Civilization terrain/unit sheets use
;;;; 16x16 tiles; others can be added here or sliced on demand via a custom spec.

(in-package #:civ-extract)

(defstruct (sheet-spec (:constructor make-sheet-spec
                           (name &key (tile-w 16) (tile-h 16)
                                      (origin-x 0) (origin-y 0)
                                      (gap-x 0) (gap-y 0)
                                      cols rows label)))
  name tile-w tile-h origin-x origin-y gap-x gap-y cols rows label)

(defparameter *sprite-sheets*
  (list
   (make-sheet-spec "SP257"   :tile-w 16 :tile-h 16 :label "units, icons, city sizes")
   (make-sheet-spec "SP299"   :tile-w 16 :tile-h 16 :label "sprites")
   (make-sheet-spec "SPRITES" :tile-w 16 :tile-h 16 :label "cursors / misc sprites")
   (make-sheet-spec "TER257"  :tile-w 16 :tile-h 16 :label "terrain tiles"))
  "Known sprite sheets and their tile geometry.  Files not listed here are
extracted as a single image only (unless :force-tile is passed to EXTRACT-ALL).")

(defun find-sheet-spec (base)
  (find base *sprite-sheets* :key #'sheet-spec-name :test #'string-equal))

(defun slice-sheet (pic spec)
  "Return a list of sprite plists (:index :col :row :x :y :w :h) for PIC per SPEC."
  (let* ((tw (sheet-spec-tile-w spec))
         (th (sheet-spec-tile-h spec))
         (ox (sheet-spec-origin-x spec))
         (oy (sheet-spec-origin-y spec))
         (gx (sheet-spec-gap-x spec))
         (gy (sheet-spec-gap-y spec))
         (cols (or (sheet-spec-cols spec)
                   (floor (- (pic-width pic) ox) (+ tw gx))))
         (rows (or (sheet-spec-rows spec)
                   (floor (- (pic-height pic) oy) (+ th gy))))
         (sprites '())
         (index 0))
    (dotimes (row rows)
      (dotimes (col cols)
        (push (list :index index :col col :row row
                    :x (+ ox (* col (+ tw gx)))
                    :y (+ oy (* row (+ th gy)))
                    :w tw :h th)
              sprites)
        (incf index)))
    (values (nreverse sprites) cols rows)))

(defun sprite-blank-p (pic sprite)
  "T if every pixel of SPRITE in PIC is the transparent index 0."
  (let ((px (pic-pixels pic))
        (x0 (getf sprite :x)) (y0 (getf sprite :y))
        (w (getf sprite :w)) (h (getf sprite :h))
        (pw (pic-width pic)) (ph (pic-height pic)))
    (dotimes (yy h t)
      (dotimes (xx w)
        (let ((x (+ x0 xx)) (y (+ y0 yy)))
          (when (and (< x pw) (< y ph)
                     (plusp (aref px y x)))
            (return-from sprite-blank-p nil)))))))
