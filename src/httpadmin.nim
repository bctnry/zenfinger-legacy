import std/[asyncnet, asyncdispatch, asynchttpserver]
import config
import log
import contentresolve
from std/strutils import parseInt, startsWith
from htmlgen as html import nil

proc renderAdminPage(config: ZConfig): string =
  let siteName = config.getConfig(CONFIG_GROUP_HTTP, CONFIG_KEY_HTTP_SITE_NAME)
  return (
    html.html(
      html.head(
        html.meta(charset="utf-8"),
        html.title("admin panel :: " & siteName),
      ),
      html.body(
        
      )
    )
  )
      


proc handleAdmin*(req: Request, config: ZConfig) {.async.} =
  await req.respond(Http200, "Shh... admin page not done yet!", {"Content-Type": "text/html; charset=utf-8"}.newHttpHeaders())
