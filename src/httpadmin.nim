import std/[asyncdispatch, asynchttpserver]
import std/strtabs
import std/asyncfile
import std/cookies
import config
import urlencoded
import dbutil
import zftemplate
from std/strutils import parseInt, startsWith, split, join
from std/parsecfg import getSectionValue
from htmlgen as html import nil

proc adminPath(x: string): string = "/zenfinger-admin" & x

useTemplate(adminEditConfigTemplate, "admin.edit-config.template.html")
proc renderEditConfigPage(config: ZConfig): string =
  var prop = newStringTable()
  prop["siteName"] = config.getConfig(CONFIG_GROUP_HTTP, CONFIG_KEY_HTTP_SITE_NAME)
  return adminEditConfigTemplate(prop)

useTemplate(adminEditIndexTemplate, "admin.edit-index.template.html")
proc renderEditIndexPage(config: ZConfig, x: string): string =
  let prop = newStringTable()
  prop["siteName"] = config.getConfig(CONFIG_GROUP_HTTP, CONFIG_KEY_HTTP_SITE_NAME)
  prop["x"] = x
  return adminEditIndexTemplate(prop)
  
useTemplate(adminDonePageTemplate, "admin.done.template.html")
proc renderDonePage(config: ZConfig): string =
  let prop = newStringTable()
  prop["siteName"] = config.getConfig(CONFIG_GROUP_HTTP, CONFIG_KEY_HTTP_SITE_NAME)
  return adminDonePageTemplate(prop)

useTemplate(adminPageTemplate, "admin.template.html")
proc renderAdminPage(config: ZConfig): string =
  let prop = newStringTable()
  prop["siteName"] = config.getConfig(CONFIG_GROUP_HTTP, CONFIG_KEY_HTTP_SITE_NAME)
  return adminPageTemplate(prop)

proc renderNewUserQueue(config: ZConfig, pendingUserList: seq[string]): string =
  let siteName = config.getConfig(CONFIG_GROUP_HTTP, CONFIG_KEY_HTTP_SITE_NAME)
  var r: seq[string] = @[]
  echo pendingUserList
  for k in pendingUserList:
    r.add(
      html.tr(
        html.td(k),
        html.td(config.registerQueue.getSectionValue("", k).split(";")[0]),
        html.td(config.registerQueue.getSectionValue("", k).split(";")[2]),
        html.td(html.a(href=("/newuser-approve/" & k).adminPath, "approve")),
        html.td(html.a(href=("/newuser-disapprove/" & k).adminPath, "disapprove")),
      )
    )
  return (
    html.html(
      html.head(
        html.meta(charset="utf-8"),
        html.title("new user queue :: admin panel :: " & siteName),
      ),
      html.body(
        html.h1("New User Queue"),
        html.hr(),
        html.table(
          html.tr(
            html.th("username"),
            html.th("application datetime"),
            html.th("reason"),
            html.th("approve"),
            html.th("disapprove"),
          ),
          r.join("")
        ),
        html.hr(),
        html.p(html.a(href="/", "Back"))
      )
    )
  )

proc renderUserManagement(config: ZConfig, userList: seq[string]): string =
  let siteName = config.getConfig(CONFIG_GROUP_HTTP, CONFIG_KEY_HTTP_SITE_NAME)
  var r: seq[string] = @[]
  for k in userList:
    r.add(
      html.tr(
        html.td(k),
        html.td(html.a(href=("/edit-user/" & k), "edit")),
        html.td(html.a(href=("/delete-user/" & k).adminPath, "delete"))
      )
    )
  return (
    html.html(
      html.head(
        html.meta(charset="utf-8"),
        html.title("user management :: admin panel :: " & siteName),
      ),
      html.body(
        html.h1("User Management"),
        html.hr(),
        html.table(
          html.tr(
            html.th("username"),
            html.th("edit"),
            html.th("delete"),
          ),
          r.join("")
        ),
        html.hr(),
        html.p(html.a(href="/", "Back"))
      )
    )
  )
  
      
proc handleAdmin*(req: Request, session: StringTableRef, config: ZConfig) {.async.} =
  let currentCookie = req.headers.getOrDefault("cookie").parseCookies
  # NOTE: we can directly do this because other edge cases is handled at a global level at httpserver.nim.
  if not currentCookie.hasKey("currentUser") or currentCookie["currentUser"] != "admin":
    await req.respond(Http303, "", {"Location": "/", "Content-Length": "0"}.newHttpHeaders())
    return

  if req.url.path == "/edit-config".adminPath or req.url.path == "/edit-config/".adminPath:
    await req.respond(Http200, renderEditConfigPage(config), {"Content-Type": "text/html; charset=utf-8"}.newHttpHeaders())
  elif req.url.path == "/edit-index".adminPath or req.url.path == "/edit-index/".adminPath:
    case req.reqMethod:
      of HttpGet:
        let f = openAsync(".zenfinger-index", fmRead)
        let s = await f.readAll()
        f.close()
        await req.respond(Http200, renderEditIndexPage(config, s), {"Content-Type": "text/html; charset=utf-8"}.newHttpHeaders())
      of HttpPost:
        let q = req.body.parseUrlencoded
        let f = openAsync(".zenfinger-index", fmWrite)
        await f.write(q["content"])
        f.close()
        await req.respond(Http200, renderDonePage(config), {"Content-Type": "text/html; charset=utf-8"}.newHttpHeaders())
      else:
        await req.respond(Http405, "", nil)
  elif req.url.path == "/newuser-queue".adminPath or req.url.path == "/newuser-queue/".adminPath:
    let s = await getAllPendingUser()
    await req.respond(Http200, renderNewUserQueue(config, s),
                      {"Content-Type": "text/html; charset=utf-8"}.newHttpHeaders())
  elif req.url.path.startsWith("/newuser-approve/".adminPath):
    let un = req.url.path.substr("/newuser-approve/".adminPath.len)
    await approveUser(config, un)
    await req.respond(Http200, renderDonePage(config),
                      {"Content-Type": "text/html; charset=utf-8"}.newHttpHeaders())
  elif req.url.path.startsWith("/newuser-disapprove/".adminPath):
    let un = req.url.path.substr("/newuser-disapprove/".adminPath.len)
    await disapproveUser(config, un)
    await req.respond(Http200, renderDonePage(config),
                      {"Content-Type": "text/html; charset=utf-8"}.newHttpHeaders())
  elif req.url.path == "/user".adminPath or req.url.path == "/user/".adminPath:
    let s = await listAllUser(config)
    echo s
    await req.respond(Http200, renderUserManagement(config, s), {"Content-Type": "text/html; charset=utf-8"}.newHttpHeaders())
  elif req.url.path.startsWith("/delete-user/".adminPath):
    let un = req.url.path.substr("/delete-user/".adminPath.len)
    await deleteUser(config, un)
    await req.respond(Http200, renderDonePage(config),
                      {"Content-Type": "text/html; charset=utf-8"}.newHttpHeaders())
  elif req.url.path == "".adminPath or req.url.path == "/".adminPath:
    await req.respond(Http200, renderAdminPage(config), {"Content-Type": "text/html; charset=utf-8"}.newHttpHeaders())
  else:
    echo req.url.path
    await req.respond(Http307, "", {"Location": "".adminPath, "Content-Length": "0"}.newHttpHeaders())

