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
                                      cols rows label (in-atlas t))))
  name tile-w tile-h origin-x origin-y gap-x gap-y cols rows label
  ;; whether this sheet's tiles join the master 16x16 atlas
  (in-atlas t))

(defun %iconpg-numbered ()
  "The eight 3x3 numbered icon pages (ICONPG1..8)."
  (loop for i from 1 to 8
        collect (make-sheet-spec
                 (format nil "ICONPG~D" i)
                 :tile-w 110 :tile-h 68 :origin-x 1 :origin-y 1
                 :gap-x 1 :gap-y 1 :cols 3 :rows 3 :in-atlas nil
                 :label "improvement / category icons (3x3)")))

(defparameter *sprite-sheets*
  (append
   (list
    ;; --- 16x16 game sprite sheets (included in the master atlas) ---
    (make-sheet-spec "SP257"   :tile-w 16 :tile-h 16 :label "units, icons, city sizes")
    (make-sheet-spec "SP299"   :tile-w 16 :tile-h 16 :label "sprites")
    (make-sheet-spec "SPRITES" :tile-w 16 :tile-h 16 :label "cursors / misc sprites")
    (make-sheet-spec "TER257"  :tile-w 16 :tile-h 16 :label "terrain tiles"))
   ;; --- ICONPG civilopedia icon pages (large tiles, own grids) ---
   (%iconpg-numbered)
   (list
    ;; lettered pages: 2 columns, varying row counts
    (make-sheet-spec "ICONPGA" :tile-w 160 :tile-h 66 :cols 2 :rows 3 :in-atlas nil :label "unit illustrations (2x3)")
    (make-sheet-spec "ICONPGB" :tile-w 160 :tile-h 50 :cols 2 :rows 4 :in-atlas nil :label "unit illustrations (2x4)")
    (make-sheet-spec "ICONPGC" :tile-w 160 :tile-h 66 :cols 2 :rows 3 :in-atlas nil :label "unit illustrations (2x3)")
    (make-sheet-spec "ICONPGD" :tile-w 160 :tile-h 40 :cols 2 :rows 5 :in-atlas nil :label "unit illustrations (2x5)")
    (make-sheet-spec "ICONPGE" :tile-w 160 :tile-h 66 :cols 2 :rows 3 :in-atlas nil :label "unit illustrations (2x3)")
    ;; terrain/map preview pages: 3 columns x 2 rows
    (make-sheet-spec "ICONPGT1" :tile-w 106 :tile-h 87 :cols 3 :rows 2 :in-atlas nil :label "map/terrain previews (3x2)")
    (make-sheet-spec "ICONPGT2" :tile-w 106 :tile-h 87 :cols 3 :rows 2 :in-atlas nil :label "map/terrain previews (3x2)")))
  "Known sprite sheets and their tile geometry.  Files not listed here are
extracted as a single image only.")

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
