;;; ----------------------------------------------------------*- lisp -*------
;;; packages.lisp - package definition for blow-cl
;;;
;;; blow-cl is a modern rewrite of BLOW by Anthony Green
;;; <green@spindazzle.org>, distributed under the GNU LGPL v3 or later.
;;; The jfli-generated Java class packages of the original are gone;
;;; all interop goes through ABCL's built-in JAVA package.
;;; ---------------------------------------------------------------------------

(in-package :cl-user)

(defpackage :blow
  (:use :cl :cl-who :cl-ppcre :cl-emb)
  (:export :*dispatch-list*
           :create-prefix-dispatcher
           :create-regex-dispatcher
           :create-conditional-dispatcher
           :def-who-page
           :def-html-page
           :service-http-request
           :request-uri
           :request-parameter
           :write-html-response
           :*webapp-root*))

(pushnew :blow-cl *features*)
