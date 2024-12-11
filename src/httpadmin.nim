import std/[asyncdispatch, asynchttpserver]
import std/strtabs
import std/asyncfile
import std/cookies
import config
import urlencoded
import dbutil
from std/strutils import parseInt, startsWith, split, join
from std/parsecfg import getSectionValue
from htmlgen as html import nil

proc adminPath(x: string): string = "/zenfinger-admin" & x

proc renderEditConfigPage(config: ZConfig): string =
  let siteName = config.getConfig(CONFIG_GROUP_HTTP, CONFIG_KEY_HTTP_SITE_NAME)
  return (
    html.html(
      html.head(
        html.meta(charset="utf-8"),
        html.title("edit config :: admin panel :: " & siteName),
      ),
      html.body(
        html.h1("Edit Config"),
        html.p(
          html.b("Note"),
          """: Please fill in the field that you want to change ONLY."""
        ),
        html.hr(),
        """<form action="" method="POST">""",
        
        html.h2("Section ", html.code("finger")),
        """<label for="finger-address">Server bind address:</label>""",
        """<input name="finger-address" id="finger-address" />""",
        html.br(),
        """<label for="finger-port">Server bind port:</label>""",
        """<input name="finger-port" id="finger-port" />""",
        html.br(),

        html.hr(),
        
        html.h2("Section ", html.code("content")),
        """<label for "content-homepage-path">Homepage path:</label>""",
        """<input name="content-homepage-path" id="content-homepage-path" />""",
        html.br(),
        """<label for "content-base-dir">Base directory:</label>""",
        """<input name="content-base-dir" id="content-base-dir" />""",
        html.br(),
        """<label for "content-password-dir">Password dir:</label>""",
        """<input name="content-password-dir" id="content-password-dir" />""",
        html.br(),

        html.hr(),

        html.h2("Section ", html.code("http")),
        """<label for "http-port">HTTP server bind port:</label>""",
        """<input name="http-port" id="http-port" />""",
        html.br(),
        """<label for "http-address">HTTP server bind address:</label>""",
        """<input name="http-address" id="http-address" />""",
        html.br(),
        """<label for "http-static-assets-dir">Static assets directory:</label>""",
        """<input name="http-static-assets-dir" id="http-static-assets-dir" />""",
        html.br(),
        """<label for "http-site-name">HTTP site name:</label>""",
        """<input name="http-site-name" id="http-site-name" />""",
        html.br(),
        
        html.hr(),
        """<input type="submit" value="Save" />""",
        """</form>""",
        html.hr(),
        html.p(html.a(href="".adminPath, "Back"))
      )
    )
  )

proc renderEditIndexPage(config: ZConfig, x: string): string =
  let siteName = config.getConfig(CONFIG_GROUP_HTTP, CONFIG_KEY_HTTP_SITE_NAME)
  return (
    html.html(
      html.head(
        html.meta(charset="utf-8"),
        html.title("edit index :: admin panel :: " & siteName),
      ),
      html.body(
        html.h1("Edit index page"),
        html.hr(),
        """<form action="" method="POST">""",
        """<label for="content">Content: </label><br />""",
        """<textarea name="content", id="content" col="80" row="25">""",
        x,
        """</textarea><br />""",
        """<input type="submit" value="Save" />""",
        """</form>""",
        html.hr(),
        html.p(html.a(href="".adminPath, "Back"))
      )
    )
  )
  

proc renderDonePage(config: ZConfig): string =
  let siteName = config.getConfig(CONFIG_GROUP_HTTP, CONFIG_KEY_HTTP_SITE_NAME)
  return (
    html.html(
      html.head(
        html.meta(charset="utf-8"),
        html.title("admin panel :: " & siteName),
      ),
      html.body(
        html.h1("Admin Panel"),
        html.hr(),
        html.p(
          "Action complete. Click ",
          html.a(href="".adminPath, "here"),
          " to go back to the admin panel."
        )
      )
    )
  )
  
proc renderAdminPage(config: ZConfig): string =
  let siteName = config.getConfig(CONFIG_GROUP_HTTP, CONFIG_KEY_HTTP_SITE_NAME)
  return (
    html.html(
      html.head(
        html.meta(charset="utf-8"),
        html.title("admin panel :: " & siteName),
      ),
      html.body(
        html.h1("Admin Panel"),
        html.hr(),
        html.p(html.a(href="/edit-config".adminPath, "Edit Config")),
        html.p(html.a(href="/edit-index".adminPath, "Edit Index")),
        html.p(html.a(href="/newuser-queue".adminPath, "New User Queue")),
        html.p(html.a(href="/user".adminPath, "User Management")),
        html.hr(),
        html.p(html.a(href="/", "Back"))
      )
    )
  )

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

