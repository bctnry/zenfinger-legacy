import std/[asyncdispatch, asynchttpserver]
import std/cookies
import std/strtabs
import config
import urlencoded
import dbutil
import zftemplate
from std/strutils import parseInt, startsWith
from htmlgen as html import nil

proc renderEditPage(config: ZConfig, content: StringTableRef = nil): string =
  let siteName = config.getConfig(CONFIG_GROUP_HTTP, CONFIG_KEY_HTTP_SITE_NAME)
  let profileEnabled = if content.hasKey("profile"): "checked" else: ""
  let mainEnabled = if content.hasKey("main"): "checked" else: ""
  let contactEnabled = if content.hasKey("contact"): "checked" else: ""
  let projectEnabled = if content.hasKey("project"): "checked" else: ""
  let planEnabled = if content.hasKey("plan"): "checked" else: ""
  let pubkeyEnabled = if content.hasKey("pgp_pubkey"): "checked" else: ""
  let pubkeySigEnabled = if content.hasKey("pgp_pubkey.sig"): "checked" else: ""
  expandTemplate(res, "templates/edit.template.html")
  return res

proc handleEdit*(req: Request, session: StringTableRef, config: ZConfig, username: string) {.async.} =
  let currentCookie = req.headers.getOrDefault("cookie").parseCookies
  if (
    not currentCookie.hasKey("currentUser") or
    (currentCookie["currentUser"] != "admin" and currentCookie["currentUser"] != username)
  ):
    await req.respond(Http303, "", {"Location": "/", "Content-Length": "0"}.newHttpHeaders())
    return

  case req.reqMethod:
    of HttpGet:
      let s = await readUserContent(config, username)
      await req.respond(Http200, renderEditPage(config, s), {"Content-Type": "text/html; charset=utf-8"}.newHttpHeaders())
    of HttpPost:
      let s = req.body.parseUrlencoded
      var p = newStringTable()
      if s.hasKey("enable-profile"): p["profile"] = s.getOrDefault("profile")
      if s.hasKey("enable-main"): p["main"] = s.getOrDefault("main")
      if s.hasKey("enable-contact"): p["contact"] = s.getOrDefault("contact")
      if s.hasKey("enable-project"): p["project"] = s.getOrDefault("project")
      if s.hasKey("enable-plan"): p["plan"] = s.getOrDefault("plan")
      if s.hasKey("enable-pubkey"): p["pgp_pubkey"] = s.getOrDefault("pubkey")
      if s.hasKey("enable-pubkey-sig"): p["pgp_pubkey.sig"] = s.getOrDefault("pubkey-sig")
      await writeUserProfile(config, username, p)
      let ss = await readUserContent(config, username)
      await req.respond(Http200, renderEditPage(config, ss), {"Content-Type": "text/html; charset=utf-8"}.newHttpHeaders())
    else:
      await req.respond(Http405, "", nil)

      
