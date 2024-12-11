import std/[asyncdispatch, asynchttpserver]
import std/cookies
import std/strtabs
import std/times
import config
import urlencoded
import dbutil
import aux
from std/strutils import parseInt, startsWith
from htmlgen as html import nil

proc renderLoginPage(config: ZConfig, message: string = ""): string =
  let siteName = config.getConfig(CONFIG_GROUP_HTTP, CONFIG_KEY_HTTP_SITE_NAME)
  return (
    html.html(
      html.head(
        html.meta(charset="utf-8"),
        html.title("Login :: ", siteName)
      ),
      html.body(
        html.h1("Login"),
        html.hr(),
        (if message.len > 0:
           """<span style="color: red">""" & message & """</span>"""
         else:
           ""),
        """<form action="" method="POST">""",
        """<label for="username">User name: </label>""",
        """<input name="username" id="username" required />""",
        html.br(),
        """<label for="password">Password: </label>""",
        """<input type="password" name="password" id="password" required />""",
        html.br(),
        """<input type="submit" value="Login" />""",
        """</form>""",
        html.hr(),
        html.p("Powered by Zenfinger")
      )
    )
  )

proc handleLogin*(req: Request, session: StringTableRef, config: ZConfig) {.async.} =
  let currentCookie = req.headers.getOrDefault("cookie").parseCookies
  if (
    currentCookie.hasKey("currentUser") and
    currentCookie.hasKey("currentSession") and
    currentCookie["currentSession"] == session[currentCookie["currentUser"]] and
    currentCookie["currentUser"] == session[currentCookie["currentSession"]]
  ):
    await req.respond(Http303, "", {"Location": "/", "Content-Length": "0"}.newHttpHeaders())
  else:
    if req.url.path == "/login":
      case req.reqMethod:
        of HttpHead:
          await req.respond(Http200, "", nil)
        of HttpGet:
          await req.respond(Http200, renderLoginPage(config), {"Content-Type": "text/html; charset=utf-8"}.newHttpHeaders())
        of HttpPost:
          let q = req.body.parseUrlencoded
          if await config.checkUserPassword(q["username"], q["password"]):
            let sesh = randStrGen(24)
            let dt = now() + initDuration(days=7)
            let cookies = @[
              ("Set-Cookie", setCookie(
                "currentUser",
                q["username"],
                secure=true,
                httpOnly=true,
                expires=dt
              ).substr("Set-Cookie: ".len)),
              ("Set-Cookie", setCookie(
                "currentSession",
                sesh,
                secure=true,
                httpOnly=true,
                expires=dt
              ).substr("Set-Cookie: ".len)),
              ("Location", "/"),
              ("Content-Length", "0")
            ]
            session[q["username"]] = sesh
            session[sesh] = q["username"]
            await req.respond(Http303, "", cookies.newHttpHeaders())
          else:
            await req.respond(Http200, renderLoginPage(config, "wrong username or password"), {"Content-Type": "text/html; charset=utf-8"}.newHttpHeaders())
          await req.respond(Http200, renderLoginPage(config), {"Content-Type": "text/html; charset=utf-8"}.newHttpHeaders())
        else:
          await req.respond(Http405, "", nil)
    else:
      await req.respond(Http307, "", {"Location": "/login", "Content-Length": "0"}.newHttpHeaders())

      
