;;; ----------------------------------------------------------*- lisp -*------
;;; blow.lisp - the blow-cl web framework core
;;;
;;; A modern rewrite of blow.lisp from BLOW, Copyright (C) 2007-2009
;;; Anthony Green <green@spindazzle.org>. The dispatcher design (and the
;;; dispatcher creators, originally copied from Hunchentoot) is his;
;;; the interop is rewritten from jfli to ABCL's JAVA package, the
;;; mime.types table is replaced by java.nio.file.Files, and static
;;; serving is hardened against path traversal.
;;;
;;; blow-cl is free software; you can redistribute it and/or modify it
;;; under the terms of the GNU Lesser General Public License as
;;; published by the Free Software Foundation; either version 3, or
;;; (at your option) any later version.
;;; ---------------------------------------------------------------------------

(in-package :blow)

(defvar *webapp-root* cl-user::*blowcl-webapp*
  "Root directory of the deployed web application.")

;;; --------------------------------------------------------------------------
;;; Servlet interop, the part jfli used to do.
;;; --------------------------------------------------------------------------

(defun request-uri (request)
  (java:jcall "getRequestURI" request))

(defun request-parameter (request name)
  "Value of query/form parameter NAME, or NIL."
  (let ((v (java:jcall "getParameter" request name)))
    (if (java:java-object-p v) nil v)))

(defun write-html-response (response html &key (content-type "text/html; charset=utf-8")
                                               (status 200))
  (java:jcall "setStatus" response status)
  (java:jcall "setContentType" response content-type)
  (java:jcall "setCharacterEncoding" response "UTF-8")
  (let ((writer (java:jcall "getWriter" response)))
    (java:jcall "println" writer html)
    (java:jcall "close" writer)))

;;; --------------------------------------------------------------------------
;;; Sessions. One Lisp user-session object per servlet session, created by
;;; WEBAPP:MAKE-USER-SESSION when the application defines it.
;;; --------------------------------------------------------------------------

(defvar *user-sessions* (make-hash-table :test 'equal))

(defun new-user-session ()
  (let* ((pkg (find-package :webapp))
         (sym (and pkg (find-symbol "MAKE-USER-SESSION" pkg))))
    (if (and sym (fboundp sym))
        (funcall sym)
        (get-universal-time))))

(defun ensure-user-session (request)
  (let ((id (java:jcall "getId" (java:jcall "getSession" request))))
    (or (gethash id *user-sessions*)
        (setf (gethash id *user-sessions*) (new-user-session)))))

;;; --------------------------------------------------------------------------
;;; Page macros. Same contract as 2009: a page is a function of
;;; (request response session) that writes the response.
;;; --------------------------------------------------------------------------

(defmacro def-who-page (name (request response session) &body body)
  "Define a page function whose body is CL-WHO forms."
  `(defun ,name (,request ,response ,session)
     (declare (ignorable ,request ,session))
     (write-html-response
      ,response
      (with-html-output-to-string (*standard-output* nil :prologue t)
        ,@body))))

(defmacro def-html-page (name (request response session) &body body)
  "Define a page function whose body returns an HTML string."
  `(defun ,name (,request ,response ,session)
     (declare (ignorable ,request ,session))
     (write-html-response ,response (progn ,@body))))

;;; --------------------------------------------------------------------------
;;; Mapping request URIs to files under *WEBAPP-ROOT*, safely.
;;; --------------------------------------------------------------------------

(defun uri-file (request)
  "The file under *WEBAPP-ROOT* a request addresses, or NIL.
Rejects path traversal and anything under WEB-INF."
  (let ((uri (request-uri request)))
    (when (and uri (plusp (length uri)) (not (search ".." uri)))
      (let ((rel (string-left-trim "/" uri)))
        (when (string= rel "")
          (setf rel "index.blo"))
        (unless (or (eql 0 (search "WEB-INF" rel :test #'char-equal))
                    (eql 0 (search "META-INF" rel :test #'char-equal)))
          (probe-file (merge-pathnames rel *webapp-root*)))))))

(defun file-extension-p (file ext)
  (string-equal (pathname-type file) ext))

;;; --------------------------------------------------------------------------
;;; Static content. Files.probeContentType replaces the 2009 mime.types
;;; hashtable; Files.copy replaces the byte-pump in BlowServlet.
;;; --------------------------------------------------------------------------

(defparameter *extra-mime-types*
  '(("css" . "text/css") ("js" . "text/javascript") ("mjs" . "text/javascript")
    ("svg" . "image/svg+xml") ("wasm" . "application/wasm")
    ("woff2" . "font/woff2") ("lisp" . "text/plain") ("blo" . "text/plain"))
  "Fallbacks for types probeContentType misses on some platforms.")

(defun content-type-for (file)
  (let ((path (java:jstatic "get" "java.nio.file.Paths" (namestring file)
                            (java:jnew-array "java.lang.String" 0))))
    (or (cdr (assoc (pathname-type file) *extra-mime-types* :test #'string-equal))
        (let ((probed (java:jstatic "probeContentType" "java.nio.file.Files" path)))
          (if (stringp probed) probed "application/octet-stream")))))

(defun page-serve-static-content (request response session)
  (declare (ignorable session))
  (let ((file (uri-file request)))
    (java:jcall "setContentType" response (content-type-for file))
    (let ((path (java:jstatic "get" "java.nio.file.Paths" (namestring file)
                              (java:jnew-array "java.lang.String" 0)))
          (out (java:jcall "getOutputStream" response)))
      (java:jstatic "copy" "java.nio.file.Files" path out)
      (java:jcall "close" out))))

;;; --------------------------------------------------------------------------
;;; .blo templates: HTML with embedded Lisp, executed by CL-EMB, exactly
;;; as in 2009 but against a Quicklisp-current cl-emb.
;;; --------------------------------------------------------------------------

(def-html-page page-process-template (request response session)
  (declare (ignorable response))
  (let ((blow-session session))
    (declare (ignorable blow-session))
    (execute-emb (uri-file request))))

;;; --------------------------------------------------------------------------
;;; The default 404 page.
;;; --------------------------------------------------------------------------

(defun page-not-found (request response session)
  (declare (ignorable session))
  (java:jcall "setStatus" response 404)
  (java:jcall "setContentType" response "text/html; charset=utf-8")
  (let ((writer (java:jcall "getWriter" response)))
    (java:jcall "println" writer
                (with-html-output-to-string (*standard-output* nil :prologue t)
                  (:html (:head (:title "blow-cl: not found"))
                         (:body (:h1 "404")
                                (:p "No dispatcher claimed "
                                    (esc (request-uri request)))))))
    (java:jcall "close" writer)))

;;; --------------------------------------------------------------------------
;;; Dispatcher creators. Design copied from Hunchentoot via BLOW.
;;; --------------------------------------------------------------------------

(defun create-prefix-dispatcher (prefix page-function)
  "Dispatch to PAGE-FUNCTION when the request URI starts with PREFIX."
  (lambda (request response session)
    (declare (ignorable response session))
    (let* ((path (request-uri request))
           (mismatch (mismatch path prefix :test #'char=)))
      (and (or (null mismatch)
               (>= mismatch (length prefix)))
           page-function))))

(defun create-regex-dispatcher (regex page-function)
  "Dispatch to PAGE-FUNCTION when the request URI matches the CL-PPCRE REGEX."
  (let ((scanner (create-scanner regex)))
    (lambda (request response session)
      (declare (ignorable response session))
      (and (scan scanner (request-uri request))
           page-function))))

(defun create-conditional-dispatcher (condition page-function)
  (lambda (request response session)
    (and (funcall condition request response session)
         page-function)))

;;; --------------------------------------------------------------------------
;;; *DISPATCH-LIST*: tried in order on every request. Applications push
;;; their own dispatchers in front of these defaults.
;;; --------------------------------------------------------------------------

(defvar *dispatch-list*
  (list
   ;; .blo templates
   (create-conditional-dispatcher
    (lambda (request response session)
      (declare (ignorable response session))
      (let ((file (uri-file request)))
        (and file (file-extension-p file "blo"))))
    #'page-process-template)
   ;; static files
   (create-conditional-dispatcher
    (lambda (request response session)
      (declare (ignorable response session))
      (let ((file (uri-file request)))
        (and file (pathname-name file))))
    #'page-serve-static-content)))

;;; --------------------------------------------------------------------------
;;; Entry point, called per request by org.blowcl.BlowServlet.
;;; --------------------------------------------------------------------------

(defun service-http-request (request response)
  (let ((session (ensure-user-session request)))
    (loop for dispatcher in *dispatch-list*
          for action = (funcall dispatcher request response session)
          when action
            return (funcall action request response session)
          finally (return (page-not-found request response session)))))
