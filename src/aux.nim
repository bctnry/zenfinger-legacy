from std/paths import getCurrentDir, Path, `/`, parentDir
from std/cmdline import paramStr

proc getExecutableDir*(): Path =
  (getCurrentDir() / (paramStr(0).Path)).parentDir()
