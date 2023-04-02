;;; 
;;; cm-sfz.lisp
;;;
;;; **********************************************************************
;;; Copyright (c) 2021 Orm Finnendahl <orm.finnendahl@selma.hfmdk-frankfurt.de>
;;;
;;; Revision history: See git repository.
;;;
;;; This program is free software; you can redistribute it and/or
;;; modify it under the terms of the Gnu Public License, version 2 or
;;; later. See https://www.gnu.org/licenses/gpl-2.0.html for the text
;;; of this agreement.
;;; 
;;; This program is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
;;; GNU General Public License for more details.
;;;
;;; **********************************************************************

(in-package :cm)

(defparameter *debug* nil)

(defobject sfz (event)
    ((keynum :initform 60 :accessor sfz-keynum)
     (amplitude :initform -6 :accessor sfz-amplitude)
     (duration :initform 1 :accessor sfz-duration)     
     (preset :initform :flute-nv :accessor sfz-preset)
     (play-fn :initform nil :accessor sfz-play-fn)
     (pan :initform 0.5 :accessor sfz-pan)
     (startpos :initform 0 :accessor sfz-startpos)
     (chan :initform 100 :accessor sfz-chan))
  (:parameters time keynum amplitude duration preset play-fn pan startpos chan)
  (:event-streams))

(eval-when (:compile-toplevel :load-toplevel)
  (defobject sfz (event)
      ((keynum :initform 60 :accessor sfz-keynum)
       (amplitude :initform 1 :accessor sfz-amplitude)
       (duration :initform 1 :accessor sfz-duration)     
       (preset :initform :flute-nv :accessor sfz-preset)
       (play-fn :initform nil :accessor sfz-play-fn)
       (pan :initform 0.5 :accessor sfz-pan)
       (startpos :initform 0 :accessor sfz-startpos)
       (chan :initform 100 :accessor sfz-chan)
       )
    (:parameters time keynum amplitude duration preset play-fn pan startpos chan)
    (:event-streams)))

(declaim (inline get-lsample))
(defun get-lsample (keynum map)
  (aref map (min (round keynum) 127)))

(defun function-name (fn)
  (cl-ppcre:regex-replace
   "^#<function \+\([^>]\+\)>"
   (format nil "~a" fn)
   "\\\1"))

(defun svg->sfz (&rest args)
  "recreate a sfz from the :attributes property and the coords of the svg element."
  (if *debug* (format t "~&svg->sfz: ~a~%" args))
  (apply #'make-instance 'sfz
         (list* :amplitude (opacity->db (getf args :amplitude))
                (ou:get-props-list args '(:time :keynum :duration :preset :play-fn :pan :startpos)))))

(add-svg-assoc-fns
 `((sfz . ,#'svg->sfz)
   (play-sfz-one-shot . ,#'cl-sfz:play-sfz-one-shot)
   (play-sfz-loop . ,#'cl-sfz:play-sfz-loop)))



(defmethod write-event ((obj sfz) (fil svg-file) scoretime)
  "convert a poolevt object into a freshly allocated svg-line object and
insert it at the appropriate position into the events slot of
svg-file."
  (if *debug* (format t "~&sfz->svg: ~a, time: ~a~%" obj scoretime))
  (with-slots (keynum amplitude duration preset play-fn pan startpos chan) obj
    (let* ((id (sxhash preset))
           (x-scale (x-scale fil))
           (stroke-width 0.5)
           (color (chan->color id))
           (line (let ((x1 (float (* x-scale scoretime) 1.0))
                       (y1 (float keynum 1.0))
                       (width (float (* x-scale duration) 1.0))
                       (opacity (float (db->opacity amplitude) 1.0)))
                   (make-instance
                    'svg-ie::svg-line
                    :x1 x1 :y1 y1
                    :x2 (+ x1 width) :y2 y1
                    :stroke-width stroke-width
                    :opacity opacity
                    :stroke-color color 
                    ;; :fill-color color
                    :attributes (format nil ":type sfz :preset ~S :play-fn ~a :pan ~a :startpos ~a :chan ~a"
                                        preset play-fn pan startpos chan)
                    :id (new-id fil 'line-ids)))))
;;;      (break "line: ~a, obj: ~a ~a ~a" line buffer-file cl-poolplayer:*pool-hash* (gethash buffer-file cl-poolplayer:*pool-hash*))
      (if *debug* (format t "~&obj: ~a, ~a~%" obj (db->opacity amplitude)))
      (svg-file-insert-line line chan fil))))

(defmethod write-event ((obj sfz) (to incudine-stream) scoretime)
  "output sfz object."
  (if *debug* (format t "~&sfz->svg: ~a~%" obj))
  (with-slots (keynum amplitude duration preset play-fn pan startpos chan) obj
    (let ((time (+ (rts-now) (* *rt-scale* scoretime))))
      (at time (or play-fn #'cl-sfz:play-sfz) keynum amplitude duration :preset preset :pan pan :startpos startpos :out1 (mod (- chan 100) 8)))))

(defmethod write-event ((obj sfz) (fil fomus-file) scoretime)
  "output sfz object to fomus."
  (let* ((myid (sfz-chan obj))
         (part (fomus-file-part fil myid))
         (marks '()))
    (setf (part-events part)
          (cons (make-note :partid myid :off scoretime :note
                 (sfz-keynum obj) :dur (sfz-duration obj) :marks
                 marks)
                (part-events part)))))

(export '(sfz sfz-keynum sfz-dur sfz-amp sfz-preset sfz-play-fn sfz-play-fn sfz-pan sfz-startpos svg->sfz) 'cm)
