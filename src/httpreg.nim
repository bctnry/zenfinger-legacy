import std/[asyncdispatch, asynchttpserver]
import std/cookies
import std/strtabs
import std/json
import checksums/bcrypt
import config
import urlencoded
import dbutil
import zftemplate
from std/strutils import parseInt, startsWith, strip
from std/parsecfg import getSectionValue
from htmlgen as html import nil

defineTemplate(regSubmittedPageTemplate, "templates/reg.submitted.template.html")
proc renderRegSubmittedPage(config: ZConfig): string =
  var prop = newProperty()
  prop["siteName"] = config.getConfig(CONFIG_GROUP_HTTP, CONFIG_KEY_HTTP_SITE_NAME)
  return regSubmittedPageTemplate(prop)

defineTemplate(regBlockedPageTemplate, "templates/reg.blocked.template.html")
proc renderRegBlockedPage(config: ZConfig): string =
  var prop = newProperty()
  prop["siteName"] = config.getConfig(CONFIG_GROUP_HTTP, CONFIG_KEY_HTTP_SITE_NAME)
  return regBlockedPageTemplate(prop)

defineTemplate(regPageTemplate, "templates/reg.template.html")
proc renderRegPage(config: ZConfig, message: string = ""): string =
  var prop = newProperty()
  prop["siteName"] = config.getConfig(CONFIG_GROUP_HTTP, CONFIG_KEY_HTTP_SITE_NAME)
  prop["message"] = message
  return regPageTemplate(prop)

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

      
