;;;; binary.lisp -- little-endian byte readers over a (vector (unsigned-byte 8))

(in-package #:civ-extract)

(deftype octets () '(simple-array (unsigned-byte 8) (*)))

(declaim (inline u8 u16))

(defun u8 (bytes index)
  "Unsigned 8-bit value at INDEX."
  (aref bytes index))

(defun u16 (bytes index)
  "Unsigned little-endian 16-bit value at INDEX."
  (logior (aref bytes index)
          (ash (aref bytes (1+ index)) 8)))

(defun read-file-octets (path)
  "Read PATH entirely into a (simple-array (unsigned-byte 8))."
  (with-open-file (s path :element-type '(unsigned-byte 8))
    (let ((buf (make-array (file-length s) :element-type '(unsigned-byte 8))))
      (read-sequence buf s)
      buf)))
