import std/random
from std/paths import getCurrentDir, Path, `/`, parentDir
from std/cmdline import paramStr

proc getExecutableDir*(): Path =
  (getCurrentDir() / (paramStr(0).Path)).parentDir()

const RAND_STR_GEN_SOURCE = "abcdefghijklmnopqrstuvwxyz23456789_+=@#%"
proc randStrGen*(length: int): string =
  var res = ""
  for _ in 0..<length:
    res.add(RAND_STR_GEN_SOURCE[rand(RAND_STR_GEN_SOURCE.len-1)])
  return res
  
