;; Copyright (c) 2003 Nikodemus Siivola
;; 
;; Permission is hereby granted, free of charge, to any person obtaining
;; a copy of this software and associated documentation files (the
;; "Software"), to deal in the Software without restriction, including
;; without limitation the rights to use, copy, modify, merge, publish,
;; distribute, sublicense, and/or sell copies of the Software, and to
;; permit persons to whom the Software is furnished to do so, subject to
;; the following conditions:
;; 
;; The above copyright notice and this permission notice shall be included
;; in all copies or substantial portions of the Software.
;; 
;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
;; EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
;; MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
;; IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
;; CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
;; TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
;; SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

(in-package :linedit)

(defclass terminal (backend)
  ((translations :initform *terminal-translations*)))

(uffi:def-function ("linedit_terminal_columns" c-terminal-columns)
    ((default :int))
  :returning :int)

(defmethod backend-columns ((backend terminal))
  (c-terminal-columns *default-columns*))

(uffi:def-function ("linedit_terminal_lines" c-terminal-lines)
    ((default :int))
  :returning :int)

(defmethod backend-lines ((backend terminal))
  (c-terminal-lines *default-lines*))

(uffi:def-function ("linedit_terminal_init" c-terminal-init)
    ()
  :returning :int)

(defmethod backend-init ((backend terminal))
  (invariant (not (backend-ready-p backend)))
  (invariant (zerop (c-terminal-init)))
  (setf (backend-ready-p backend) t))

(uffi:def-function ("linedit_terminal_close" c-terminal-close)
    ()
  :returning :int)

(defmethod backend-close ((backend terminal))
  (invariant (backend-ready-p backend))
  (invariant (zerop (c-terminal-close)))
  (setf (backend-ready-p backend) nil))

(defmethod read-chord ((backend terminal))
  (invariant (backend-ready-p backend))
  (flet ((read-open-chord ()
	   (do ((chars nil)
		(c #1=(read-char) #1#))
	       ((member c '(#\- #\~ #\$)) (nconc (nreverse chars) (list c)))
	     (push c chars))))
    (let ((chord
	   (acase (read-char)
		  (#\Esc
		   (cons it (acase (read-char)
				   (#\[ (cons
					 it
					 (let ((char (read-char)))
					   (if (digit-char-p char)
					       (cons char
						     (read-open-chord))
					       (list char)))))
				   (t (list it)))))
		  (t (if (graphic-char-p it)
			 it
			 (char-code it))))))
      (gethash chord
	       (backend-translations backend)
	       (if (characterp chord)
		   chord
		   (list 'untranslated chord))))))

(defmethod beep ((b terminal))
  (declare (ignore b))
  (and (write-char #\Bell *error-output*)
       (force-output *error-output*)))

(defmethod page ((backend terminal))
  (write-string "--more--")
  (force-output)
  (let ((q (read-chord backend)))
    (write-char #\Return)
    (not (equal #\q q))))

(defmethod print-in-columns ((backend terminal) list &key width)
  (unwind-protect
       (let ((max-col (truncate (backend-columns backend) width))
	     (col 0)
	     (line 0)
	     (pad ""))
	 (dolist (item list)
	   ;; Ensure new line
	   (when (= 1 (incf col)) ; you remember C ? ;)
	     (newline backend))
	   ;; Pad after previsous
	   (write-string pad)
	   (setf pad "")
	   ;; Item
	   (write-string item)
	   ;; Maybe newline
	   (cond ((= col max-col)
		  (setf col 0)
		  (when (= (1+ (incf line)) (backend-lines backend))
		    (setf line 0)
		    (unless (page backend)
		      (return-from print-in-columns nil))))
		 (t 
		  (setf pad (make-string (- width (length item)) 
					 :initial-element #\space))))))
    ;; needed for the return-from
    (newline backend)))

(defmethod print-in-lines ((backend terminal) string)
  (terpri)
  (do ((i 0 (1+ i))
       (lines 0))
      ((= i (length string)))
    (let ((c (schar string i)))
      (when (= lines (backend-lines backend))
	(setf lines 0)
	(unless (page backend)
	  (return-from print-in-lines nil)))
      (when (eql #\newline c)
	(incf lines))
      (write-char c)))
  (terpri))

(defmethod newline ((backend terminal))
  (write-char #\newline)
  (write-char #\return))
