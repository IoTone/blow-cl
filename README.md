# blow-cl

A Lisp web application framework for the JVM.

blow-cl is a modern rewrite of [BLOW](https://github.com/atgreen/blow) — "A Web Application
Framework in LISP" by Anthony Green (2007–2010). BLOW's idea was ahead of its time: write web
applications in Common Lisp, run them on boring, deployable Java servlet infrastructure. The
idea aged well; the 2009 toolchain did not. blow-cl keeps the programming model and replaces
everything underneath it.

| 2009 BLOW | blow-cl |
|---|---|
| Makefile + magic `blow` shell script | Gradle 8 (`./gradlew run`), nothing else |
| Winstone 0.9.10 / Tomcat 6 jars | Embedded Jetty 11 (Jakarta Servlet 5) |
| Vendored abcl.jar (2009) | ABCL 1.9.x from Maven Central |
| jfli interop (abandoned) | ABCL's built-in `JAVA` package |
| Vendored 2009 cl-who / cl-ppcre / cl-emb / etc. | Quicklisp-current versions, loaded at boot |
| `mime.types` hashtable | `java.nio.file.Files.probeContentType` |
| log4j 1.2.13 | slf4j 2 |

The programming model is unchanged and intentionally tiny:

- **`*DISPATCH-LIST*`** — a list of dispatchers tried in order per request
  (`create-prefix-dispatcher`, `create-regex-dispatcher`, `create-conditional-dispatcher` —
  the design BLOW borrowed from Hunchentoot).
- **`def-who-page`** — pages as [cl-who](https://edicl.github.io/cl-who/) forms.
- **`def-html-page`** — pages as functions returning an HTML string.
- **`.blo` templates** — HTML with embedded Lisp, executed by cl-emb.
- **Sessions** — your app exports `webapp:make-user-session`; its result is passed to every
  page function.
- Static files are served automatically (with path-traversal and `WEB-INF` protection, which
  the 2009 original did not have).

## Quickstart

Requires JDK 11+. First run downloads Gradle, the Maven dependencies, and (via Quicklisp)
the Common Lisp libraries.

```
./gradlew run
```

Then:

- http://localhost:9999/ — `index.blo` template demo
- http://localhost:9999/hello — compiled cl-who page with per-session state

Run your own app:

```
./gradlew run -Pwebapp=/path/to/your/app -Pport=8088
```

where `your/app` follows the BLOW layout:

```
app/
├── index.blo            templates and static files at the root
├── style.css
└── WEB-INF/
    └── lisp/
        └── webapp.lisp  defines package :webapp, pushes dispatchers
```

`./gradlew repl` starts a plain ABCL REPL on the project classpath.

## Writing an app

```lisp
(defpackage :webapp
  (:use :cl :blow :cl-who)
  (:export :make-user-session))
(in-package :webapp)

(defun make-user-session () (random 1000000))

(def-who-page page-hello (request response session)
  (:html (:body (:p "Hello from Lisp. Session: " (str session)))))

(push (create-prefix-dispatcher "/hello" #'page-hello) *dispatch-list*)
```

See `demo/app/` for the complete example.

## Status and roadmap

v0.5.0 — the core works: dispatchers, both page macros, `.blo` templates, static serving,
sessions, 404 handling. Not yet ported from the original:

- `rdf.lisp` — BLOW's Jena/SPARQL binding. Modern Jena renamed every package
  (`com.hp.hpl.jena` → `org.apache.jena`), so this is a separate rewrite.
- `.war` packaging for external servlet containers (embedded Jetty only for now).
- The `blow <appname>` project generator (use `demo/app` as a template).

blow-cl is part of the [spicemine](https://github.com/IoTone) / codentea-ya effort to build
source-control hosting that isn't a GitHub clone, on a deliberately polyglot JVM stack.

## Credits and license

BLOW was written by Anthony Green <green@spindazzle.org>. blow-cl is a derived work: the
dispatcher design, page-macro contract, `.blo` concept, and app layout are his. The
dispatcher creators were originally copied from [Hunchentoot](https://edicl.github.io/hunchentoot/)
(see `COPYING.hunchentoot` in the original distribution).

blow-cl is free software, distributed under the GNU Lesser General Public License,
version 3 or (at your option) any later version. See `COPYING.LESSER`.
