;;; ----------------------------------------------------------*- lisp -*------
;;; boot.lisp - blow-cl framework bootstrap
;;;
;;; Loaded once by org.blowcl.BlowServlet with CL-USER::*BLOWCL-HOME*
;;; (framework lisp root) and CL-USER::*BLOWCL-WEBAPP* (application root)
;;; already bound.
;;;
;;; blow-cl is a modern rewrite of BLOW by Anthony Green
;;; <green@spindazzle.org>, distributed under the GNU LGPL v3 or later.
;;; ---------------------------------------------------------------------------

(in-package :cl-user)

(require :asdf)
(require :abcl-contrib)

;; Modern dependencies come from Quicklisp instead of jars/vendored
;; 2009 sources. First boot on a machine without ~/quicklisp downloads it.
(unless (find-package :quicklisp)
  (asdf:load-system :quicklisp-abcl))

(funcall (intern "QUICKLOAD" :ql) '(:cl-who :cl-ppcre :cl-emb) :silent t)

(load (merge-pathnames "blow/packages.lisp" *blowcl-home*))
(load (merge-pathnames "blow/blow.lisp" *blowcl-home*))

;; Load the application, mirroring the original blow layout:
;; <webapp>/WEB-INF/lisp/webapp.lisp defines package :webapp and pushes
;; its dispatchers onto BLOW:*DISPATCH-LIST*.
(let ((app (merge-pathnames "WEB-INF/lisp/webapp.lisp" *blowcl-webapp*)))
  (if (probe-file app)
      (load app)
      (format t "blow-cl: no webapp.lisp at ~a, serving framework defaults only~%" app)))

(format t "blow-cl booted: webapp ~a, ~d dispatcher(s)~%"
        *blowcl-webapp* (length blow:*dispatch-list*))
