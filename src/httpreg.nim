import std/[asyncnet, asyncdispatch, asynchttpserver]
import std/cookies
import std/strtabs
import std/times
import checksums/bcrypt
import config
import log
import contentresolve
import urlencoded
import dbutil
import aux
from std/strutils import parseInt, startsWith, strip
from std/parsecfg import getSectionValue
from htmlgen as html import nil

proc renderRegSubmittedPage(config: ZConfig): string =
  let siteName = config.getConfig(CONFIG_GROUP_HTTP, CONFIG_KEY_HTTP_SITE_NAME)
  return (
    html.html(
      html.head(
        html.meta(charset="utf-8"),
        html.title("Register :: ", siteName)
      ),
      html.body(
        html.h1("Register"),
        html.hr(),
        html.p("Application sent. You should be able to login once the admin has approved your application."),
        html.p("Click ", html.a(href="/", "here"), " to return to home page."),
        html.hr(),
        html.p("Powered by Zenfinger")
      )
    )
  )
  
proc renderRegBlockedPage(config: ZConfig): string =
  let siteName = config.getConfig(CONFIG_GROUP_HTTP, CONFIG_KEY_HTTP_SITE_NAME)
  return (
    html.html(
      html.head(
        html.meta(charset="utf-8"),
        html.title("Register :: ", siteName)
      ),
      html.body(
        html.h1("Register"),
        html.hr(),
        html.p(
          "You are not allowed to do this when logged in. ",
          html.a(href="/logout", "Logout"), " and then try again",
          " or click ", html.a(href="/", "here"), " to go back to home page."
        ),
        html.hr(),
        html.p("Powered by Zenfinger")
      )
    )
  )
      

proc renderRegPage(config: ZConfig, message: string = ""): string =
  let siteName = config.getConfig(CONFIG_GROUP_HTTP, CONFIG_KEY_HTTP_SITE_NAME)
  return (
    html.html(
      html.head(
        html.meta(charset="utf-8"),
        html.title("Register :: ", siteName)
      ),
      html.body(
        html.h1("Register"),
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
        """<label for="reason">Reason: </label>""",
        """<textarea name="reason" id="reason"></textarea>""",
        """<input type="submit" value="Register" />""",
        """</form>""",
        html.hr(),
        html.p("Powered by Zenfinger")
      )
    )
  )

proc handleReg*(req: Request, session: StringTableRef, config: ZConfig) {.async.} =
  let currentCookie = req.headers.getOrDefault("cookie").parseCookies
  if (
    currentCookie.hasKey("currentUser") and
    currentCookie.hasKey("currentSession") and
    currentCookie["currentSession"] == session[currentCookie["currentUser"]] and
    currentCookie["currentUser"] == session[currentCookie["currentSession"]]
  ):
    await req.respond(Http200, renderRegBlockedPage(config), {"Content-Type": "text/html; charset=utf-8"}.newHttpHeaders())
  else:
    case req.reqMethod:
      of HttpHead:
        await req.respond(Http200, "", nil)
      of HttpGet:
        await req.respond(Http200, renderRegPage(config), {"Content-Type": "text/html; charset=utf-8"}.newHttpHeaders())
      of HttpPost:
        let q = req.body.parseUrlencoded
        if await config.hasUser(q["username"]):
          await req.respond(Http200, renderRegPage(config, "username taken"), {"Content-Type": "text/html; charset=utf-8"}.newHttpHeaders())
        elif config.registerQueue.getSectionValue("", q["username"]) != "":
          await req.respond(Http200, renderRegPage(config, "username registration applied & waiting for approval"), {"Content-Type": "text/html; charset=utf-8"}.newHttpHeaders())
        else:
          let h = $(q["password"].strip().bcrypt(generateSalt(8)))
          await config.newUser(q["username"], h)
          await req.respond(Http200, renderRegSubmittedPage(config), {"Content-Type": "text/html; charset=utf-8"}.newHttpHeaders())
      else:
        await req.respond(Http307, "", {"Location": "/reg", "Content-Length": "0"}.newHttpHeaders())

      
