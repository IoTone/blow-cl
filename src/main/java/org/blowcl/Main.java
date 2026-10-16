/*
 * Main.java - embedded Jetty launcher for blow-cl
 *
 * This file is part of blow-cl, a modern rewrite of BLOW,
 * "A Web Application Framework in LISP" by Anthony Green.
 *
 * blow-cl is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as
 * published by the Free Software Foundation; either version 3, or
 * (at your option) any later version.
 */
package org.blowcl;

import org.eclipse.jetty.server.Server;
import org.eclipse.jetty.servlet.ServletContextHandler;
import org.eclipse.jetty.servlet.ServletHolder;

public class Main {

    public static void main(String[] args) throws Exception {
        int port = Integer.parseInt(System.getProperty("blowcl.port", "9999"));
        String webapp = System.getProperty("blowcl.webapp", "demo/app");

        Server server = new Server(port);

        ServletContextHandler context = new ServletContextHandler(ServletContextHandler.SESSIONS);
        context.setContextPath("/");
        context.setAttribute("blowcl.webapp", webapp);
        context.addServlet(new ServletHolder(new BlowServlet()), "/*");

        server.setHandler(context);
        server.start();
        System.out.println("(blow-cl) listening on http://localhost:" + port + "/  webapp=" + webapp);
        server.join();
    }
}
