import std/asyncdispatch
import std/asyncfile
import std/paths
import std/times
from std/strformat import `&`
from aux import getExecutableDir

proc log*(x: string) {.async.} =
  let logFile = openAsync((getExecutableDir() / ".zenfinger-log".Path).string, fmAppend)
  let data = &"""[{getTime().format("yyyy-MM-dd HH:mm:ss")} UTC] {x}"""
  echo data
  await logFile.write(data & "\n")

  
