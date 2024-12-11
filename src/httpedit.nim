import std/[asyncdispatch, asynchttpserver]
import std/cookies
import std/strtabs
import config
import urlencoded
import dbutil
from std/strutils import parseInt, startsWith
from htmlgen as html import nil

proc renderEditPage(config: ZConfig, content: StringTableRef = nil): string =
  let siteName = config.getConfig(CONFIG_GROUP_HTTP, CONFIG_KEY_HTTP_SITE_NAME)
  return (
    html.html(
      html.head(
        html.meta(charset="utf-8"),
        html.title("edit user content :: ", siteName)
      ),
      html.body(
        html.h1("Edit User Content"),
        html.hr(),
        """<form action="" method="POST">""",
        html.h2("File ", html.code("profile")),
        html.p("NOTE: This file has a higher precedence than any other files listed below. If you enable <code>profile</code>, this would be the only thing people see when querying for your page on this server."),
        """<label for="enable-main">Enable <code>profile</code>""",
        """<input type="checkbox" name="enable-profile" id="enable-profile" """, if content.hasKey("profile"): "checked" else: "", """/><br />""",
        """<textarea name="profile" id="profile" row="25" col="80">""", content.getOrDefault("profile"),
        """</textarea>""",
        
        html.hr(),
        
        html.h2("File ", html.code("main")),
        html.p("A place for you to put your self-introduction."),
        """<label for="enable-main">Enable <code>main</code>""",
        """<input type="checkbox" name="enable-main" id="enable-main"""", if content.hasKey("main"): "checked" else: "", """ /><br />""",
        """<textarea name="main" id="main" row="25" col="80">""", content.getOrDefault("main"),
        """</textarea>""",
        
        html.hr(),

        html.h2("File ", html.code("contact")),
        html.p("Your contact info."),
        """<label for="enable-contact">Enable <code>contact</code>""",
        """<input type="checkbox" name="enable-contact" id="enable-contact"""", if content.hasKey("contact"): "checked" else: "", """ /><br />""",
        """<textarea name="contact" id="contact" row="25" col="80">""", content.getOrDefault("contact"),
        """</textarea>""",
        
        html.hr(),

        html.h2("File ", html.code("project")),
        html.p("What kind of project are you currently working on?"),
        """<label for="enable-project">Enable <code>project</code>""",
        """<input type="checkbox" name="enable-project" id="enable-project"""", if content.hasKey("project"): "checked" else: "", """ /><br />""",
        """<textarea name="project" id="project" row="25" col="80">""", content.getOrDefault("project"),
        """</textarea>""",
        
        html.hr(),

        html.h2("File ", html.code("plan")),
        html.p("What plan do you currently have?"),
        """<label for="enable-plan">Enable <code>plan</code>""",
        """<input type="checkbox" name="enable-plan" id="enable-plan"""", if content.hasKey("plan"): "checked" else: "", """ /><br />""",
        """<textarea name="plan" id="plan" row="25" col="80">""", content.getOrDefault("plan"),
        """</textarea>""",
        
        html.hr(),

        html.h2("File ", html.code("pgp_pubkey")),
        """<label for="enable-pubkey">Enable <code>pgp_pubkey</code>""",
        """<input type="checkbox" name="enable-pubkey" id="enable-pubkey"""", if content.hasKey("pgp_pubkey"): "checked" else: "", """ /><br />""",
        """<textarea name="pubkey" id="pubkey" row="25" col="80">""", content.getOrDefault("pgp_pubkey"),
        """</textarea>""",
        
        html.hr(),

        html.h2("File ", html.code("pgp_pubkey.sig")),
        """<label for="enable-pubkey-sig">Enable <code>pgp_pubkey.sig</code>""",
        """<input type="checkbox" name="enable-pubkey-sig" id="enable-pubkey-sig"""", if content.hasKey("pgp_pubkey.sig"): "checked" else: "", """ /><br />""",
        """<textarea name="pubkey-sig" id="pubkey-sig" row="25" col="80">""", content.getOrDefault("pgp_pubkey.sig"),
        """</textarea>""",

        html.hr(),

        """<input type="submit" value="Save" />""",
        """</form>""",
        """ <a href="/">Back</a>""",
        html.hr(),
        html.p("Powered by Zenfinger")
      )
    )
  )

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

      
