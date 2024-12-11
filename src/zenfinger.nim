import std/asyncdispatch
import std/random
import std/net
import std/cmdline
import fingerserver
import httpserver
import config
import log
import ask
import install
from std/strutils import rsplit, strip, join

randomize()

when isMainModule:
  if paramCount() <= 0:
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
  else:
    # this is the client part. we'll do it with blocking sockets.
    let q = paramStr(1).strip().rsplit('@', maxsplit=1)
    let query = q[0]
    let server = if q.len <= 1: "127.0.0.1" else: q[1]
    let socket = newSocket()
    socket.connect(server, 79.Port)
    socket.send(query & "\r\n")
    var res: seq[string] = @[]
    var s: string
    while true:
      socket.readLine(s)
      if s == "": break
      elif s == "\r\n": res.add("")
      else: res.add(s)
    echo res.join("\n")

