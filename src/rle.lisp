;;;; rle.lisp -- run-length decode applied after LZW (CivOne RLE.Decode port).
;;;;
;;;; 0x90 is the repeat marker.  A normal byte V is emitted as-is; a following
;;;; 0x90 N (N != 0) repeats the previous value so it appears N times total
;;;; (i.e. N-1 additional copies).  The sequence 0x90 0x00 is the literal
;;;; escape for a single 0x90 byte.

(in-package #:civ-extract)

(defconstant +rle-repeat+ #x90)
(defconstant +rle-escape+ #x00)

(defun rle-decode (input)
  "Decode the RLE octet vector INPUT, returning a fresh octet vector."
  (declare (type octets input))
  (let ((out (make-array (* 2 (length input))
                         :element-type '(unsigned-byte 8)
                         :adjustable t :fill-pointer 0))
        (len (length input))
        (value 0))
    (let ((i 0))
      (loop while (< i len) do
        (let* ((cur (aref input i))
               (next (if (< (1+ i) len) (aref input (1+ i)) +rle-escape+)))
          (cond
            ;; literal byte (incl. the 0x90 0x00 escape)
            ((or (/= cur +rle-repeat+) (= next +rle-escape+))
             (setf value cur)
             (vector-push-extend value out)
             (when (and (= cur +rle-repeat+) (= next +rle-escape+))
               (incf i)))             ; consume the escape 0x00
            ;; repeat marker: emit (next-1) additional copies of VALUE
            (t
             (dotimes (k (1- next))
               (vector-push-extend value out))
             (incf i)))               ; consume the count byte
          (incf i))))
    (coerce out 'octets)))
