;;; ----------------------------------------------------------*- lisp -*------
;;; webapp.lisp - the blow-cl demo application
;;;
;;; Same contract as the original BLOW sample app by Anthony Green:
;;; define package :webapp, export MAKE-USER-SESSION, define page
;;; functions, and push dispatchers onto BLOW:*DISPATCH-LIST*.
;;; ---------------------------------------------------------------------------

(defpackage :webapp
  (:use :cl :blow :cl-who)
  (:export :make-user-session))

(in-package :webapp)

;; Called once per servlet session; the result is handed to every
;; page function as its SESSION argument.
(defun make-user-session ()
  (random 1000000))

(def-who-page page-hello-world (request response session)
  (:html (:head (:title "blow-cl: Lisp On Web")
                (:link :rel "stylesheet" :type "text/css" :href "/style.css"))
         (:body
          (:h1 "(blow-cl)")
          (:p "Hello World! This web application blows, again, in " (:b "2026") ".")
          (:p (fmt "Session: ~a" session))
          (:p (fmt "Random number: ~a" (random 1000)))
          (:p (:a :href "/" "index.blo template demo")))))

(push (create-prefix-dispatcher "/hello" #'page-hello-world)
      *dispatch-list*)
