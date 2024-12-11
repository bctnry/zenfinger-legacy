import std/asyncdispatch
import std/asyncfile
import std/paths
import std/files
import std/dirs
import std/times
import std/parsecfg
import std/strtabs
import checksums/bcrypt
import config
import aux
from std/strutils import strip, split
from std/strformat import `&`


proc hasUser*(config: ZConfig, user: string): Future[bool] {.async.} =
  if user == "admin": return true
  let baseDir = config.getConfig(CONFIG_GROUP_DATA, CONFIG_KEY_DATA_BASE_DIR)
  let passwordDir = config.getConfig(CONFIG_GROUP_DATA, CONFIG_KEY_DATA_PASSWORD_DIR)
  let userBaseDir = baseDir.Path / user.Path
  let userPasswordFile = passwordDir.Path / user.Path
  return (userBaseDir.dirExists and userPasswordFile.fileExists)

proc checkUserPassword*(config: ZConfig, user: string, password: string): Future[bool] {.async.}=
  if user == "admin":
    let adminPasswordHash = config.getConfig(CONFIG_GROUP_ADMIN, CONFIG_KEY_ADMIN_PASSWORD)
    return password.verify(adminPasswordHash)
  let passwordDir = config.getConfig(CONFIG_GROUP_DATA, CONFIG_KEY_DATA_PASSWORD_DIR)
  let userPasswordPath = passwordDir.Path / user.Path
  if not userPasswordPath.fileExists: return false
  let pf = openAsync(userPasswordPath.string, fmRead)
  let p = await pf.readAll()
  pf.close()
  return password.verify(p.strip())
    
proc newUser*(config: ZConfig, user: string, passwordHash: string, reason: string = "") {.async.} =
  let t = &"""{getTime().format("yyyy-MM-dd HH:mm:ss")} UTC"""
  config.registerQueue.setSectionKey("", user, &"""{t};{passwordHash};{reason}""")
  config.registerQueue.writeConfig(config.registerQueuePath)

proc approveUser*(config: ZConfig, user: string) {.async.} =
  let passwordHash = config.registerQueue.getSectionValue("", user).split(";")[1]
  config.registerQueue.delSectionKey("", user)
  config.registerQueue.writeConfig(config.registerQueuePath)
  let baseDir = config.getConfig(CONFIG_GROUP_DATA, CONFIG_KEY_DATA_BASE_DIR)
  let dirPath = baseDir.Path / user.Path
  dirPath.createDir()
  let passwordDir = config.getConfig(CONFIG_GROUP_DATA, CONFIG_KEY_DATA_PASSWORD_DIR)
  let passwordFilePath = passwordDir.Path / user.Path
  let f = openAsync(passwordFilePath.string, fmWrite)
  await f.write(passwordHash)
  f.close()

proc disapproveUser*(config: ZConfig, user: string) {.async.} =
  config.registerQueue.delSectionKey("", user)
  config.registerQueue.writeConfig(config.registerQueuePath)
  
proc getAllPendingUser*(): Future[seq[string]] {.async.} =
  var res: seq[string] = @[]
  let f = openAsync((getExecutableDir() / ".zenfinger-applications".Path).string, fmRead)
  let s = await f.readAll()
  f.close()
  for k in s.strip().split("\n"):
    let kk = k.split("=", maxsplit=1)
    if kk[0].len > 0:
      res.add(kk[0])
  return res
  
proc deleteUser*(config: ZConfig, user: string) {.async.} =
  let baseDir = config.getConfig(CONFIG_GROUP_DATA, CONFIG_KEY_DATA_BASE_DIR)
  let dirPath = baseDir.Path / user.Path
  let passwordDir = config.getConfig(CONFIG_GROUP_DATA, CONFIG_KEY_DATA_PASSWORD_DIR)
  let passwordFilePath = passwordDir.Path / user.Path
  for k in dirPath.walkDir:
    let p = dirPath / k.path
    if p.fileExists: p.removeFile
    elif p.dirExists: p.removeDir
  dirPath.removeDir
  passwordFilePath.removeFile
      
proc listAllUser*(config: ZConfig): Future[seq[string]] {.async.} =
  var res: seq[string] = @[]
  let baseDir = config.getConfig(CONFIG_GROUP_DATA, CONFIG_KEY_DATA_BASE_DIR).Path
  let passwordDir = config.getConfig(CONFIG_GROUP_DATA, CONFIG_KEY_DATA_PASSWORD_DIR).Path
  for k in baseDir.walkDir:
    if k.path.dirExists:
      let a = k.path.relativePath(baseDir)
      if (passwordDir / a).fileExists:
        res.add(a.string)
  return res

proc readUserContent*(config: ZConfig, username: string): Future[StringTableRef] {.async.} =
  var res = newStringTable()
  let baseDir = config.getConfig(CONFIG_GROUP_DATA, CONFIG_KEY_DATA_BASE_DIR).Path
  let userDir = baseDir / username.Path
  if (userDir / "profile".Path).fileExists:
    let f = (userDir / "profile".Path).string.openAsync(fmRead)
    res["profile"] = await f.readAll()
    f.close()
  if (userDir / "main".Path).fileExists:
    let f = (userDir / "main".Path).string.openAsync(fmRead)
    res["main"] = await f.readAll()
    f.close()
  if (userDir / "contact".Path).fileExists:
    let f = (userDir / "contact".Path).string.openAsync(fmRead)
    res["contact"] = await f.readAll()
    f.close()
  if (userDir / "project".Path).fileExists:
    let f = (userDir / "project".Path).string.openAsync(fmRead)
    res["project"] = await f.readAll()
    f.close()
  if (userDir / "plan".Path).fileExists:
    let f = (userDir / "plan".Path).string.openAsync(fmRead)
    res["plan"] = await f.readAll()
    f.close()
  if (userDir / "pgp_pubkey".Path).fileExists:
    let f = (userDir / "pgp_pubkey".Path).string.openAsync(fmRead)
    res["pgp_pubkey"] = await f.readAll()
    f.close()
  if (userDir / "pgp_pubkey.sig".Path).fileExists:
    let f = (userDir / "pgp_pubkey.sig".Path).string.openAsync(fmRead)
    res["pgp_pubkey.sig"] = await f.readAll()
    f.close()
  return res

proc writeUserProfile*(config: ZConfig, username: string, content: StringTableRef) {.async.} =
  let baseDir = config.getConfig(CONFIG_GROUP_DATA, CONFIG_KEY_DATA_BASE_DIR).Path
  let userDir = baseDir / username.Path
  for k in @["profile", "main", "contact", "project", "plan", "pgp_pubkey", "pgp_pubkey.sig"]:
    if not content.hasKey(k):
      let fp = userDir / k.Path
      let targetfp = userDir / ("." & k).Path
      if targetfp.fileExists:
        removeFile(targetfp)
      if fp.fileExists:
        moveFile(fp, targetfp)
    else:
      let targetfp = userDir / k.Path
      let f = openAsync(targetfp.string, fmWrite)
      await f.write(content[k])
      f.close()
  
