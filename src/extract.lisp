;;;; extract.lisp -- top-level extraction driver.
;;;;
;;;; EXTRACT-ALL decodes every .PIC in a directory to a PNG, slices the known
;;;; sprite sheets into individual tiles, renders one master atlas containing
;;;; every sprite, and writes a JSON sprite index describing it all.

(in-package #:civ-extract)

;;; --- tiny JSON construction helpers (com.inuoe.jzon) --------------------

(defun obj (&rest kv)
  "Build an ordered string-keyed hash-table object from KV pairs."
  (let ((h (make-hash-table :test 'equal :size (floor (length kv) 2))))
    (loop for (k v) on kv by #'cddr do (setf (gethash k h) v))
    h))

(defun vec (list) (coerce list 'vector))

(defun chunk-string (pic)
  (format nil "~{~A~^,~}"
          (remove nil (list (and (pic-has-e0 pic) "E0")
                            (and (pic-has-m0 pic) "M0")
                            (and (pic-has-x0 pic) "X0")
                            (and (pic-has-x1 pic) "X1")))))

;;; --- single file --------------------------------------------------------

(defun extract-file (path out-dir &key (write-tiles t) (skip-blank t))
  "Decode PATH, write its PNG (and sprite tiles) under OUT-DIR.
Returns (values metadata-object sprite-records) where sprite-records is a list
of (pic spec sprite tile-relpath) for atlas rendering, or NIL."
  (let ((pic (parse-pic path)))
    (unless pic (return-from extract-file (values nil nil)))
    (let* ((base (pic-source pic))
           (img-rel (format nil "images/~A.png" base))
           (img-path (merge-pathnames img-rel out-dir)))
      (pic->png pic img-path)
      (let ((meta (obj "file" (file-namestring path)
                       "base" base
                       "width" (pic-width pic)
                       "height" (pic-height pic)
                       "depth" (pic-depth pic)
                       "chunks" (chunk-string pic)
                       "palette_source" (cond ((pic-has-m0 pic) "embedded-M0")
                                              ((= (pic-depth pic) 4) "default-16")
                                              (t "none"))
                       "image" img-rel))
            (spec (find-sheet-spec base))
            (records '()))
        (when spec
          (multiple-value-bind (sprites cols rows) (slice-sheet pic spec)
            (let ((entries '()) (nblank 0))
              (dolist (sp sprites)
                (let* ((blank (sprite-blank-p pic sp))
                       (tile-rel (format nil "sprites/~A/tile_~3,'0D_~3,'0D.png"
                                         base (getf sp :row) (getf sp :col))))
                  (when blank (incf nblank))
                  (unless (and skip-blank blank)
                    ;; only small uniform sheets feed the master atlas
                    (when (sheet-spec-in-atlas spec)
                      (push (list pic spec sp tile-rel) records))
                    (when write-tiles
                      (write-tile pic sp (merge-pathnames tile-rel out-dir))))
                  (push (obj "index" (getf sp :index)
                             "col" (getf sp :col) "row" (getf sp :row)
                             "x" (getf sp :x) "y" (getf sp :y)
                             "w" (getf sp :w) "h" (getf sp :h)
                             "blank" (if blank 1 0)
                             "file" (if (and skip-blank blank) "" tile-rel))
                        entries)))
              (setf (gethash "sheet" meta)
                    (obj "tile_w" (sheet-spec-tile-w spec)
                         "tile_h" (sheet-spec-tile-h spec)
                         "cols" cols "rows" rows
                         "count" (length sprites)
                         "blank" nblank
                         "label" (or (sheet-spec-label spec) "")
                         "dir" (format nil "sprites/~A/" base)
                         "sprites" (vec (nreverse entries)))))))
        (values meta (nreverse records))))))

(defun write-tile (pic sprite path)
  "Write a single sprite tile from PIC to PATH."
  (let* ((w (getf sprite :w)) (h (getf sprite :h))
         (x0 (getf sprite :x)) (y0 (getf sprite :y))
         (px (pic-pixels pic)) (pw (pic-width pic)) (ph (pic-height pic))
         (tile (make-array (list h w) :element-type '(unsigned-byte 8))))
    (dotimes (yy h)
      (dotimes (xx w)
        (let ((x (+ x0 xx)) (y (+ y0 yy)))
          (setf (aref tile yy xx)
                (if (and (< x pw) (< y ph)) (aref px y x) 0)))))
    (write-indexed-png tile (pic-palette pic) w h path)))

;;; --- master atlas -------------------------------------------------------

(defun render-atlas (records out-dir &key (columns 32) (gap 1))
  "Render every sprite in RECORDS onto one master sprite sheet (atlas.png).
Returns an atlas metadata object (with each sprite's cell position)."
  (when (null records) (return-from render-atlas nil))
  (let* ((cell-w (reduce #'max records :key (lambda (r) (getf (third r) :w))))
         (cell-h (reduce #'max records :key (lambda (r) (getf (third r) :h))))
         (n (length records))
         (rows (ceiling n columns))
         (aw (+ gap (* columns (+ cell-w gap))))
         (ah (+ gap (* rows (+ cell-h gap))))
         (canvas (make-canvas aw ah))
         (cells '()))
    (loop for r in records
          for i from 0
          do (let* ((pic (first r)) (sp (third r))
                    (col (mod i columns)) (row (floor i columns))
                    (dx (+ gap (* col (+ cell-w gap))))
                    (dy (+ gap (* row (+ cell-h gap)))))
               (blit-indexed canvas (pic-pixels pic) (pic-palette pic)
                             (getf sp :x) (getf sp :y) (getf sp :w) (getf sp :h)
                             dx dy)
               (push (obj "atlas_index" i
                          "source" (pic-source pic)
                          "sprite_index" (getf sp :index)
                          "atlas_x" dx "atlas_y" dy
                          "w" (getf sp :w) "h" (getf sp :h)
                          "file" (fourth r))
                     cells)))
    (write-canvas canvas (merge-pathnames "atlas.png" out-dir))
    (obj "image" "atlas.png"
         "columns" columns "rows" rows
         "cell_w" cell-w "cell_h" cell-h "gap" gap
         "sprite_count" n
         "cells" (vec (nreverse cells)))))

;;; --- whole directory ----------------------------------------------------

(defun extract-all (&key (source-dir #p"../")
                         (out-dir #p"extracted/")
                         (write-tiles t) (skip-blank t)
                         (atlas-columns 32))
  "Extract every *.PIC under SOURCE-DIR into OUT-DIR.  Writes images/, sprite
tiles, a master atlas.png, and sprite-index.json.  Returns the output path."
  (let* ((source-dir (truename source-dir))
         (out-dir (ensure-directories-exist (merge-pathnames out-dir)))
         (pics (sort (directory (merge-pathnames "*.PIC" source-dir))
                     #'string< :key #'pathname-name))
         (file-metas '())
         (all-records '()))
    (format t "~&Extracting ~D PIC files from ~A~%" (length pics) source-dir)
    (dolist (p pics)
      (handler-case
          (multiple-value-bind (meta records) (extract-file p out-dir
                                                            :write-tiles write-tiles
                                                            :skip-blank skip-blank)
            (when meta
              (push meta file-metas)
              (setf all-records (nconc all-records records))
              (format t "  ~A -> ~Dx~D (~Dbpp)~@[  [~D sprites]~]~%"
                      (pathname-name p) (gethash "width" meta) (gethash "height" meta)
                      (gethash "depth" meta)
                      (let ((s (gethash "sheet" meta)))
                        (and s (length (gethash "sprites" s)))))))
        (error (e)
          (format t "  !! ~A: ~A~%" (pathname-name p) e))))
    (format t "~&Rendering master atlas (~D sprites)...~%" (length all-records))
    ;; extract the bitmap fonts (FONTS.CV), one specimen sheet per font
    (let ((font-metas '())
          (font-path (merge-pathnames "FONTS.CV" source-dir)))
      (when (probe-file font-path)
        (handler-case
            (let ((fonts (parse-fonts font-path)))
              (dolist (f fonts)
                (let ((rel (format nil "fonts/font~D.png" (font-index f))))
                  (render-font-sheet f (merge-pathnames rel out-dir))
                  (push (obj "index" (font-index f)
                             "first_char" (font-first f) "last_char" (font-last f)
                             "height" (font-height f) "glyphs" (font-charcount f)
                             "byte_length" (font-byte-length f)
                             "space_x" (font-space-x f) "space_y" (font-space-y f)
                             "image" rel)
                        font-metas)))
              (format t "  fonts: ~D rendered from FONTS.CV~%" (length fonts)))
          (error (e) (format t "  !! FONTS.CV: ~A~%" e))))
    (let* ((atlas (render-atlas all-records out-dir :columns atlas-columns))
           (root (obj "game" "Sid Meier's Civilization (DOS, 1991)"
                      "format" "MicroProse PIC chunked container (M0/E0/X0/X1), LZW+RLE"
                      "source_dir" (namestring source-dir)
                      "file_count" (length file-metas)
                      "files" (vec (nreverse file-metas))
                      "fonts" (vec (nreverse font-metas))
                      "atlas" (or atlas (obj)))))
      (with-open-file (s (merge-pathnames "sprite-index.json" out-dir)
                         :direction :output :if-exists :supersede
                         :if-does-not-exist :create)
        (com.inuoe.jzon:stringify root :stream s :pretty t))
      (format t "~&Done. Output in ~A~%  - images/*.png  (full assets)~%  - sprites/<SHEET>/*.png  (tiles)~%  - fonts/font*.png  (bitmap fonts)~%  - atlas.png  (all sprites)~%  - sprite-index.json~%" out-dir)
      out-dir))))
