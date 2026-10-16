/*
 * BlowServlet.java - boots ABCL and delegates HTTP requests to Lisp
 *
 * This file is part of blow-cl, a modern rewrite of BLOW,
 * "A Web Application Framework in LISP" by Anthony Green.
 * The original BLOW shipped an org.spindazzle.BlowServlet with the
 * same job; this one targets ABCL 1.9+ and Jakarta Servlet 5.
 *
 * blow-cl is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as
 * published by the Free Software Foundation; either version 3, or
 * (at your option) any later version.
 */
package org.blowcl;

import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import org.armedbear.lisp.Interpreter;
import org.armedbear.lisp.JavaObject;
import org.armedbear.lisp.LispObject;
import org.armedbear.lisp.Packages;
import org.armedbear.lisp.Symbol;

import java.io.IOException;
import java.nio.file.Paths;

public class BlowServlet extends HttpServlet {

    private static volatile LispObject serviceFn;

    @Override
    public void init() throws ServletException {
        synchronized (BlowServlet.class) {
            if (serviceFn != null) return;
            try {
                String webapp = (String) getServletContext().getAttribute("blowcl.webapp");
                String lispHome = System.getProperty("blowcl.lisp.home", "src/main/lisp");
                Interpreter interp = Interpreter.getInstance() != null
                        ? Interpreter.getInstance()
                        : Interpreter.createInstance();

                // Hand the Lisp world its two roots, then boot the framework
                // and the application's WEB-INF/lisp/webapp.lisp.
                interp.eval(String.format(
                    "(progn" +
                    "  (defvar cl-user::*blowcl-home* #p\"%s/\")" +
                    "  (defvar cl-user::*blowcl-webapp* #p\"%s/\")" +
                    "  (load \"%s/blow/boot.lisp\"))",
                    escape(abs(lispHome)), escape(abs(webapp)), escape(abs(lispHome))));

                org.armedbear.lisp.Package pkg = Packages.findPackage("BLOW");
                if (pkg == null) throw new ServletException("ABCL booted but package BLOW is missing");
                Symbol sym = pkg.findAccessibleSymbol("SERVICE-HTTP-REQUEST");
                if (sym == null) throw new ServletException("BLOW:SERVICE-HTTP-REQUEST not found");
                serviceFn = sym.getSymbolFunction();
            } catch (ServletException e) {
                throw e;
            } catch (Throwable t) {
                throw new ServletException("Failed to boot ABCL/blow-cl", t);
            }
        }
    }

    @Override
    protected void service(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        try {
            serviceFn.execute(new JavaObject(req), new JavaObject(resp));
        } catch (Throwable t) {
            log("Lisp handler error for " + req.getRequestURI(), t);
            if (!resp.isCommitted()) {
                resp.sendError(500, "Lisp handler error: " + t.getMessage());
            }
        }
    }

    private static String abs(String p) {
        return Paths.get(p).toAbsolutePath().normalize().toString().replace('\\', '/');
    }

    private static String escape(String s) {
        return s.replace("\\", "\\\\").replace("\"", "\\\"");
    }
}
