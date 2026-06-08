;;;; pic.lisp -- parse the MicroProse PIC/PAL chunked container.
;;;;
;;;; Container = sequence of chunks: [u16 magic][u16 length][length bytes].
;;;;   magic 0x304D "M0" : 256-entry VGA palette
;;;;   magic 0x3045 "E0" : 8bpp->4bpp colour conversion table (skipped here)
;;;;   magic 0x3058 "X0" : 8bpp image (LZW+RLE)
;;;;   magic 0x3158 "X1" : 4bpp image (LZW+RLE)

(in-package #:civ-extract)

(defconstant +magic-e0+ #x3045)
(defconstant +magic-m0+ #x304D)
(defconstant +magic-x0+ #x3058)
(defconstant +magic-x1+ #x3158)

(defstruct pic
  source        ; base name string
  width height
  depth         ; 8 or 4
  pixels        ; (height x width) array of palette indices
  palette       ; (256 x 4) rgba array
  has-m0 has-e0 has-x0 has-x1)

(defun %read-palette (bytes data-start palette)
  "Parse an M0 palette chunk body into PALETTE (256x4 rgba)."
  (let ((first (u8 bytes data-start))
        (last  (u8 bytes (1+ data-start)))
        (p (+ data-start 2)))
    (dotimes (i 256)
      (if (and (>= i first) (<= i last))
          (let ((r (u8 bytes p)) (g (u8 bytes (+ p 1))) (b (u8 bytes (+ p 2))))
            (incf p 3)
            (setf (palette-rgb palette i) (list (* r 4) (* g 4) (* b 4))))
          (setf (palette-rgb palette i) (list 0 0 0))))
    ;; colour 0 is always transparent
    (setf (aref palette 0 3) 0)))

(defun %decode-image (bytes data-start length)
  "Decode an X0/X1 chunk body: skip width/height/bits header, LZW+RLE the rest."
  (let* ((comp-start (+ data-start 5))      ; width(2)+height(2)+bits(1)
         (comp-len (- length 5))
         (comp (make-array comp-len :element-type '(unsigned-byte 8))))
    (replace comp bytes :start2 comp-start :end2 (+ comp-start comp-len))
    (rle-decode (lzw-decode comp))))

(defun %fill-x0 (pic decoded)
  (let ((w (pic-width pic)) (h (pic-height pic)) (c 0) (n (length decoded)))
    (dotimes (y h)
      (dotimes (x w)
        (setf (aref (pic-pixels pic) y x)
              (if (< c n) (aref decoded c) 0))
        (incf c)))))

(defun %fill-x1 (pic decoded)
  (let ((w (pic-width pic)) (h (pic-height pic)) (c 0) (n (length decoded)))
    (dotimes (y h)
      (let ((x 0))
        (loop while (< x w) do
          (let ((byte (if (< c n) (aref decoded c) 0)))
            (incf c)
            (setf (aref (pic-pixels pic) y x) (logand byte #x0F))
            (when (< (1+ x) w)
              (setf (aref (pic-pixels pic) y (1+ x)) (ash (logand byte #xF0) -4)))
            (incf x 2)))))))

(defun parse-pic (path)
  "Parse a .PIC/.PAL file at PATH into a PIC struct (NIL if it has no image)."
  (let* ((bytes (read-file-octets path))
         (len (length bytes))
         (palette (make-palette))
         (have-m0 nil) (have-e0 nil) (have-x0 nil) (have-x1 nil)
         (base (pathname-name path))
         (pic nil)
         (index 0))
    (loop while (<= (+ index 4) len) do
      (let* ((magic (u16 bytes index))
             (length (u16 bytes (+ index 2)))
             (data-start (+ index 4)))
        (cond
          ((= magic +magic-m0+)
           (setf have-m0 t)
           (%read-palette bytes data-start palette))
          ((= magic +magic-e0+)
           (setf have-e0 t))            ; colour-conversion table: not needed
          ((= magic +magic-x0+)
           (setf have-x0 t)
           (let* ((w (u16 bytes data-start))
                  (h (u16 bytes (+ data-start 2)))
                  (px (make-array (list h w) :element-type '(unsigned-byte 8))))
             (setf pic (make-pic :source base :width w :height h :depth 8
                                 :pixels px :palette palette))
             (%fill-x0 pic (%decode-image bytes data-start length))))
          ((= magic +magic-x1+)
           (setf have-x1 t)
           ;; only build from X1 if no X0 image was found
           (unless (and pic (= (pic-depth pic) 8))
             (let* ((w (u16 bytes data-start))
                    (h (u16 bytes (+ data-start 2)))
                    (px (make-array (list h w) :element-type '(unsigned-byte 8))))
               (setf pic (make-pic :source base :width w :height h :depth 4
                                   :pixels px :palette palette))
               (%fill-x1 pic (%decode-image bytes data-start length))))))
        (setf index (+ data-start length))))
    (when pic
      ;; 4-bit image without an embedded palette: use the default 16-colour set
      (when (and (= (pic-depth pic) 4) (not have-m0))
        (setf (pic-palette pic) *default-palette-16*))
      (setf (pic-has-m0 pic) have-m0
            (pic-has-e0 pic) have-e0
            (pic-has-x0 pic) have-x0
            (pic-has-x1 pic) have-x1))
    pic))
