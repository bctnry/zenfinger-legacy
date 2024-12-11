import std/[asyncnet, asyncdispatch]
import std/paths
import log
import config
import contentresolve
from std/strutils import parseInt

proc serveFinger*(config: ZConfig) {.async.} =
  var server = newAsyncSocket()
  server.setSockOpt(OptReuseAddr, true)
  let portNumber = config.getConfig(CONFIG_GROUP_FINGER, CONFIG_KEY_FINGER_PORT).parseInt
  let bindAddr = config.getConfig(CONFIG_GROUP_FINGER, CONFIG_KEY_FINGER_ADDR)
  server.bindAddr(portNumber.Port, address=bindAddr)
  server.listen
  asyncCheck log("Finger server bind at " & bindAddr & ":" & $portNumber)

  while true:
    let client = await server.accept()
    let line = await client.recvLine()
    let clientAddr = client.getPeerAddr()
    await log("Finger request: " & line.repr & " from " & clientAddr[0])
    var p: Path
    if line != "":
      let r = await processRequest(if line == "\r\n": "" else: line, config)
      await client.send(r)
    client.close()
    
