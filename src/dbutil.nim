import std/asyncdispatch
import std/asyncfile
import std/paths
import std/files
import std/dirs
import std/times
import std/parsecfg
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
    
proc newUser*(config: ZConfig, user: string, passwordHash: string) {.async.} =
  let t = &"""{getTime().format("yyyy-MM-dd HH:mm:ss")} UTC"""
  config.registerQueue.setSectionKey("", user, &"""{t};{passwordHash}""")
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
  
proc getAllPendingUser*(): Future[seq[string]] {.async.} =
  var res: seq[string] = @[]
  let f = openAsync((getExecutableDir() / ".zenfinger-applications".Path).string, fmRead)
  let s = await f.readAll()
  f.close()
  for k in s.strip().split("\n"):
    let kk = k.split("=", maxsplit=1)
    res.add(kk[0])
  return res
  
  
