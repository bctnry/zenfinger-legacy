import std/asyncdispatch
import std/asyncfile
import std/paths
import std/files
import std/dirs
import std/random
import log
import config
from std/strutils import join, split

proc listDir(config: ZConfig): seq[string] =
  var res: seq[string] = @[]
  let baseDir = config.getConfig(CONFIG_GROUP_DATA, CONFIG_KEY_DATA_BASE_DIR).Path
  for k in baseDir.walkDir(relative=true, skipSpecial=true):
    if (baseDir / k.path).dirExists():
      res.add(k.path.string)
  return res

proc assembleUserProfile(username: string, config: ZConfig): Future[string] {.async.} =
  let baseDir = config.getConfig(CONFIG_GROUP_DATA, CONFIG_KEY_DATA_BASE_DIR).Path
  let userDir = baseDir / username.Path
  let profile = userDir / "profile".Path
  let main = userDir / "main".Path
  let contact = userDir / "contact".Path
  let project = userDir / "project".Path
  let plan = userDir / "plan".Path
  let pgpPubkey = userDir / "pgp_pubkey".Path
  let pgpPubkeySig = userDir / "pgp_pubkey.sig".Path

  if profile.fileExists():
    var f = openAsync(profile.string, fmRead)
    let r = await f.readAll()
    f.close()
    return r
    
  var mainContent = ""
  if main.fileExists():
    var f = openAsync(main.string, fmRead)
    mainContent = await f.readAll()
    f.close()

  var contactContent = ""
  if contact.fileExists():
    var f = openAsync(contact.string, fmRead)
    contactContent = await f.readAll()
    f.close()

  var pubkeyLine = ""
  if pgpPubkey.fileExists():
    pubkeyLine &= "PGP public key: " & username & "/pgp_pubkey\n"
    if pgpPubkeySig.fileExists():
      var f = openAsync(pgpPubkeySig.string, fmRead)
      let sig = await f.readAll()
      f.close()
      pubkeyLine &= "Fingerprint: " & sig & "\n"
    else:
      pubkeyLine &= "(Fingerprint file not found)\n"
    
  var projectContent = ""
  if project.fileExists():
    var f = openAsync(project.string, fmRead)
    projectContent = "Project:\n" & await f.readAll()
    f.close()

  var planContent = ""
  if plan.fileExists():
    var f = openAsync(plan.string, fmRead)
    planContent = "Plan:\n" & await f.readAll()
    f.close()

  return mainContent & "\n" & contactContent & "\n" & pubkeyLine & projectContent & "\n" & planContent & "\n"

proc resolveUser(x: string, config: ZConfig): Future[string] {.async.} =
  var p: Path
  if x == "":
    p = config.getConfig(CONFIG_GROUP_DATA, CONFIG_KEY_DATA_HOMEPAGE_PATH).Path
  else:
    let prefix = config.getConfig(CONFIG_GROUP_DATA, CONFIG_KEY_DATA_BASE_DIR)
    let req = x.Path.absolutePath(prefix.Path)
    if not req.isRelativeTo(prefix.Path):
      await log("Rejected due to invalid request")
      return ""
    p = req
  if p.fileExists():
    var f = openAsync(p.string, fmRead)
    let res = await f.readAll()
    f.close()
    return res
  elif p.dirExists():
    # NOTE: we don't support directory under user directory so this must be
    # a request for a certain user.
    return await assembleUserProfile(x, config)
  else:
    return "Cannot find the requested data."

# NOTE: x would be whatever the client would send without the ending crlf.
proc processRequest*(xx: string, config: ZConfig): Future[string] {.async.}  =
  # NOTE: this treats question mark `?` as the same as the slash `/`.
  # in my opinion this isn't exactly ideal, but i currently couldn't think
  # of a situation where maintaining a distinction would be beneficial in
  # the context of Zenfinger.
  let x = xx.split('\t').join("/")
  if x == "_random":
    let allUserList = listDir(config)
    let choice = rand(allUserList.len-1)
    let selectedUser = allUserList[choice]
    return "User: " & selectedUser & "\n\n" & await resolveUser(selectedUser, config)
  else:
    return await resolveUser(x, config)
    
