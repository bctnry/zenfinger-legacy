import std/[asyncnet, asyncdispatch, asynchttpserver]
import std/random
import fingerserver
import httpserver
import config
import log
import ask
import install

randomize()

if not initConfig():
  asyncCheck log("Asking for initialization...")
  let c = askWithChoice("It seems like you don't have a config file. Create one?", @["y","n"])
  if c == "n":
    asyncCheck log("Initialization denied. Exiting.")
    echo "Initialization denied. Exiting."
    quit(0)
  else:
    install()
    let r = initConfig()
    if not r:
      asyncCheck log("Failed to load config. Exiting.")
      echo "Failed to load config. Exiting."
      quit(0)

let c = getCurrentConfig()

asyncCheck serveFinger(c)
asyncCheck serveHTTP(c)
runForever()


