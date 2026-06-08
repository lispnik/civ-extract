;;;; lzw.lisp -- variable-width LZW decoder for MicroProse PIC image data.
;;;;
;;;; Faithful port of the CivOne (CC0) LZW.Decode, with the parameters the
;;;; Civilization PIC files actually use:
;;;;   min-bits = 8, max-bits = 11, no clear/end-reset codes, flush on full.
;;;; Code 256 (== 1<<min-bits) terminates the stream.  Codes are packed
;;;; least-significant-bit first.  The read code width is recomputed once per
;;;; *input byte* (not per code), exactly as the reference implementation does.

(in-package #:civ-extract)

(declaim (inline code-length))
(defun code-length (n)
  "Number of bits needed to represent N (position of highest set bit + 1)."
  (if (<= n 0) 1 (integer-length n)))

(defun %make-lzw-dictionary (min-bits)
  "Return (values dict values-table) initialised with all MIN-BITS literals
plus one empty trailing entry, matching DecodeDictionary(clearEnd=false)."
  (let* ((base (ash 1 min-bits))
         (dict (make-array (+ base 1) :adjustable t :fill-pointer 0))
         (values (make-hash-table :test 'equalp)))
    (dotimes (i base)
      (let ((v (make-array 1 :element-type '(unsigned-byte 8)
                             :initial-element i)))
        (vector-push-extend v dict)
        (setf (gethash v values) t)))
    ;; trailing empty entry (code = base)
    (let ((empty (make-array 0 :element-type '(unsigned-byte 8))))
      (vector-push-extend empty dict)
      (setf (gethash empty values) t))
    (values dict values)))

(defun %append-byte (vec byte)
  "Return a fresh octet vector = VEC with BYTE appended."
  (let* ((n (length vec))
         (out (make-array (1+ n) :element-type '(unsigned-byte 8))))
    (replace out vec)
    (setf (aref out n) byte)
    out))

(defun lzw-decode (input &key (min-bits 8) (max-bits 11))
  "Decode the LZW byte vector INPUT, returning a fresh octet vector."
  (declare (type octets input))
  (let ((out (make-array (* 4 (length input))
                         :element-type '(unsigned-byte 8)
                         :adjustable t :fill-pointer 0))
        (end-code (ash 1 min-bits))
        (value 0)
        (counter 0)
        (entry (make-array 0 :element-type '(unsigned-byte 8))))
    (multiple-value-bind (dict values) (%make-lzw-dictionary min-bits)
      (flet ((reset ()
               (multiple-value-setq (dict values)
                 (%make-lzw-dictionary min-bits))
               (setf entry (make-array 0 :element-type '(unsigned-byte 8)))))
        (loop for i from 0 below (length input) do
          (let ((clen (min (code-length (fill-pointer dict)) max-bits))
                (byte (aref input i)))
            (dotimes (bit 8)
              (setf value (logior value (ash (logand (ash byte (- bit)) 1) counter)))
              (incf counter)
              (when (= counter clen)
                ;; a complete code has been assembled in VALUE
                (when (= value end-code)
                  (return-from lzw-decode (coerce out 'octets)))
                ;; KwKwK: code not yet defined -> entry + entry[0]
                (when (and (>= value (fill-pointer dict))
                           (plusp (length entry)))
                  (let ((nb (%append-byte entry (aref entry 0))))
                    (vector-push-extend nb dict)
                    (setf (gethash nb values) t)))
                (let* ((out-val (aref dict value))
                       (new-entry (%append-byte entry (aref out-val 0))))
                  ;; emit decoded bytes
                  (loop for b across out-val do (vector-push-extend b out))
                  ;; learn entry + first(out-val) if novel (flush=t: always add)
                  (when (not (gethash new-entry values))
                    (vector-push-extend new-entry dict)
                    (setf (gethash new-entry values) t))
                  (setf entry out-val))
                (setf value 0 counter 0)
                ;; flush the dictionary once it would exceed max-bits
                (when (> (code-length (fill-pointer dict)) max-bits)
                  (reset))))))
        (coerce out 'octets)))))
