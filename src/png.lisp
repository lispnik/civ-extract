;;;; png.lisp -- RGBA PNG output via zpng.

(in-package #:civ-extract)

(defun write-indexed-png (pixels palette width height path)
  "Write an indexed image (PIXELS = HxW array of palette indices) to PATH as RGBA."
  (let* ((png (make-instance 'zpng:png :color-type :truecolor-alpha
                             :width width :height height))
         (data (zpng:data-array png)))
    (dotimes (y height)
      (dotimes (x width)
        (let ((idx (aref pixels y x)))
          (setf (aref data y x 0) (aref palette idx 0)
                (aref data y x 1) (aref palette idx 1)
                (aref data y x 2) (aref palette idx 2)
                (aref data y x 3) (aref palette idx 3)))))
    (ensure-directories-exist path)
    (zpng:write-png png path)
    path))

(defun pic->png (pic path)
  "Write a whole PIC to PATH."
  (write-indexed-png (pic-pixels pic) (pic-palette pic)
                     (pic-width pic) (pic-height pic) path))

;;; --- compositing for the master sprite atlas ----------------------------

(defun make-canvas (width height)
  "A transparent RGBA canvas (zpng:png)."
  (make-instance 'zpng:png :color-type :truecolor-alpha
                 :width width :height height))

(defun blit-indexed (canvas pixels palette sx sy sw sh dx dy
                     &key (skip-transparent t))
  "Copy the SW x SH region at (SX,SY) of indexed PIXELS into CANVAS at (DX,DY)."
  (let ((data (zpng:data-array canvas))
        (cw (zpng:width canvas))
        (ch (zpng:height canvas))
        (ph (array-dimension pixels 0))
        (pw (array-dimension pixels 1)))
    (dotimes (yy sh)
      (dotimes (xx sw)
        (let ((px (+ sx xx)) (py (+ sy yy))
              (qx (+ dx xx)) (qy (+ dy yy)))
          (when (and (< px pw) (< py ph) (< qx cw) (< qy ch))
            (let* ((idx (aref pixels py px))
                   (a (aref palette idx 3)))
              (unless (and skip-transparent (zerop a))
                (setf (aref data qy qx 0) (aref palette idx 0)
                      (aref data qy qx 1) (aref palette idx 1)
                      (aref data qy qx 2) (aref palette idx 2)
                      (aref data qy qx 3) a)))))))))

(defun write-canvas (canvas path)
  (ensure-directories-exist path)
  (zpng:write-png canvas path)
  path)
