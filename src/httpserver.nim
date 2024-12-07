import std/[asyncnet, asyncdispatch, asynchttpserver]
import config
import log
import contentresolve
from std/strutils import parseInt, startsWith
from htmlgen as html import nil

proc proxyTemplate(req: string, x: string): string =
  return (
    html.html(
      html.head(
        html.meta(charset="utf-8"),
        html.title(req)
      ),
      html.body(
        html.h1(req),
        html.pre(x),
        html.hr(),
        html.p("Powered by Zenfinger")
      )
    )
  )

proc serveHTTP*(config: ZConfig) {.async.} =
  var server = newAsyncHttpServer()
  proc cb(req: Request) {.async.} =
    echo (req.reqMethod, req.url, req.headers)
    var response = ""
    if req.url.path.startsWith("/finger"):
      let rawr = if req.url.path == "/finger": "/finger/" else: req.url.path
      let fingerReq = req.url.path.substr("/finger/".len)
      echo "fingereq ", fingerReq
      let r = await processRequest(fingerReq, config)
      response = "<!DOCTYPE html>\n" & proxyTemplate(fingerReq, r)
    elif req.url.path == "/reg":
      response = "Shh... register page not done yet!"
    elif req.url.path.startsWith("/edit"):
      response = "Shh... user edit page not done yet!"
    elif req.url.path.startsWith("/admin"):
      response = "Shh... admin page not done yet!"
    elif req.url.path != "/":
      await req.respond(Http308, "", {"Location": "/", "Content-Length": "0"}.newHttpHeaders())
    else:
      response = "Shh... front page not done yet!"
      
    let headers = {"Content-type": "text/html; charset=utf-8"}
    await req.respond(Http200, response, headers.newHttpHeaders())

  let portNumber = config.getConfig(CONFIG_GROUP_HTTP, CONFIG_KEY_HTTP_PORT).parseInt
  let bindAddr = config.getConfig(CONFIG_GROUP_HTTP, CONFIG_KEY_HTTP_ADDR)
  server.listen(Port(portNumber), address=bindAddr)
  asyncCheck log("HTTP proxy server bind at " & bindAddr & ":" & $portNumber)
  while true:
    if server.shouldAcceptRequest():
      await server.acceptRequest(cb)
    else:
      # too many concurrent connections, `maxFDs` exceeded
      # wait 500ms for FDs to be closed
      await sleepAsync(500)

      
