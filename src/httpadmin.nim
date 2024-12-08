import std/[asyncnet, asyncdispatch, asynchttpserver]
import config
import log
import contentresolve
from std/strutils import parseInt, startsWith
from htmlgen as html import nil


proc handleAdmin*(req: Request, config: ZConfig) {.async.} =
  await req.respond(Http200, "Shh... admin page not done yet!", {"Content-Type": "text/html; charset=utf-8"})
