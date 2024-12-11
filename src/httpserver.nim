import std/[asyncdispatch, asynchttpserver]
import std/cookies
import std/strtabs
import std/times
import config
import log
import contentresolve
import httpadmin
import httplogin
import httpreg
import httpedit
from std/strutils import parseInt, startsWith
from htmlgen as html import nil

proc proxyTemplate(req: string, x: string): string =
  return (
    html.html(
      html.head(
        html.meta(charset="utf-8"),
        html.title(req),
        html.style("pre { font-size: 1rem }")
      ),
      html.body(
        html.h1(req),
        html.pre(x),
        html.hr(),
        html.p("Powered by Zenfinger")
      )
    )
  )

proc renderIndexPage(req: Request, x: string, config: ZConfig): string =
  let siteName = config.getConfig(CONFIG_GROUP_HTTP, CONFIG_KEY_HTTP_SITE_NAME)
  let currentCookie = req.headers.getOrDefault("cookie").parseCookies
  return (
    html.html(
      html.head(
        html.meta(charset="utf-8"),
        html.title(siteName),
        html.style("pre { font-size: 1rem }")
      ),
      html.body(
        html.h1(siteName),
        html.pre(x),
        html.hr(),
        html.p("Powered by Zenfinger"),
        (
          if currentCookie.hasKey("currentUser"):
           html.p(
             "Currently logged in as " & currentCookie["currentUser"] & ". ",
             html.a(href="/logout", "Logout"),
             if currentCookie["currentUser"] == "admin":
               """ <a href="/zenfinger-admin">Admin</a>"""
             else:
               """ <a href="/edit-user/""" & currentCookie["currentuser"] & """">Edit</a> <a href="/~""" & currentCookie["currentuser"] & """">Profile</a>"""
           )
         else:
           html.p(
             html.a(href="/login", "Login"),
             " ",
             html.a(href="/reg", "Register")
           )
        )
      )
    )
  )

proc checkSession(x: StringTableRef, k: StringTableRef): bool =
  return (
    x.hasKey(k["currentUser"]) and
    (x[k["currentUser"]] == k["currentSession"]) and
    x.hasKey(k["currentSession"]) and
    (x[k["currentSession"]] == k["currentUser"])
  )

proc invalidCookie(x: StringTableRef): bool =
  return (
    (x.hasKey("currentUser") and not x.hasKey("currentSession")) or
    (x.hasKey("currentSession") and not x.hasKey("currentUser"))
  )

proc logout(sessionStore: StringTableRef, req: Request) {.async.} =
  let cookieRemovingDT = now() - initDuration(days=7)
  let currentCookie = req.headers.getOrDefault("cookie").parseCookies
  let cookies = @[
    ("Set-Cookie", setCookie(
      "currentUser",
      "",
      secure=true,
      httpOnly=true,
      expires=cookieRemovingDT
    ).substr("Set-Cookie: ".len)),
    ("Set-Cookie", setCookie(
      "currentSession",
      "",
      secure=true,
      httpOnly=true,
      expires=cookieRemovingDT
    ).substr("Set-Cookie: ".len)),
    ("Location", "/"),
    ("Content-Length", "0")
  ]
  if sessionStore.hasKey(currentCookie["currentSession"]):
    sessionStore.del(currentCookie["currentSession"])
  if sessionStore.hasKey(currentCookie["currentUser"]):
    sessionStore.del(currentCookie["currentUser"])
  await req.respond(Http303, "", cookies.newHttpHeaders())

proc serveHTTP*(config: ZConfig) {.async.} =
  var server = newAsyncHttpServer()
  var sessionStore = newStringTable()
  proc cb(req: Request) {.async.} =
    asyncCheck log("HTTP Request: " & $req.reqMethod & " " & req.url.path & req.url.query)
    let currentCookie = req.headers.getOrDefault("cookie").parseCookies
    if (
      invalidCookie(currentCookie) or
      (currentCookie.hasKey("currentUser") and
       currentCookie.hasKey("currentSession") and
       not sessionStore.checkSession(currentCookie))
    ):
      await logout(sessionStore, req)
      return
    var response = ""
    if req.url.path.startsWith("/~"):
      let fingerReq = req.url.path.substr("/~".len)
      let r = await processRequest(fingerReq, config)
      response = "<!DOCTYPE html>\n" & proxyTemplate(fingerReq, r)
    elif req.url.path == "/reg":
      await handleReg(req, sessionStore, config)
    elif req.url.path.startsWith("/edit-user/"):
      let x = req.url.path.substr("/edit-user/".len)
      await handleEdit(req, sessionStore, config, x)
    elif req.url.path == "/login":
      await handleLogin(req, sessionStore, config)
    elif req.url.path == "/logout/":
      await req.respond(Http303, "", {"Location": "/logout", "Content-Length": "0"}.newHttpHeaders())
    elif req.url.path == "/logout":
      await logout(sessionStore, req)
    elif req.url.path.startsWith("/zenfinger-admin"):
      await handleAdmin(req, sessionStore, config)
      return
    elif req.url.path != "/":
      await req.respond(Http307, "", {"Location": "/", "Content-Length": "0"}.newHttpHeaders())
      return
    else:
      let r = await processRequest("", config)
      response = "<!DOCTYPE html>\n" & renderIndexPage(req, r, config)
      
    let headers = {"Content-type": "text/html; charset=utf-8"}
    await req.respond(Http200, response, headers.newHttpHeaders())

  let portNumber = config.getConfig(CONFIG_GROUP_HTTP, CONFIG_KEY_HTTP_PORT).parseInt
  let bindAddr = config.getConfig(CONFIG_GROUP_HTTP, CONFIG_KEY_HTTP_ADDR)
  server.listen(portNumber.Port, address=bindAddr)
  asyncCheck log("HTTP proxy server bind at " & bindAddr & ":" & $portNumber)
  while true:
    if server.shouldAcceptRequest():
      await server.acceptRequest(cb)
    else:
      # too many concurrent connections, `maxFDs` exceeded
      # wait 500ms for FDs to be closed
      await sleepAsync(500)

      
