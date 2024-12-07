import std/[asyncnet, asyncfile, asyncdispatch]
import std/paths
import std/files
import log
import config
import contentresolve

proc serveFinger*(config: ZConfig) {.async.} =
  var server = newAsyncSocket()
  server.setSockOpt(OptReuseAddr, true)
  server.bindAddr(79.Port)
  server.listen

  while true:
    let client = await server.accept()
    let line = await client.recvLine()
    let clientAddr = client.getPeerAddr()
    await log("Finger Request: " & line.repr & " from " & clientAddr[0])
    var p: Path
    if line != "":
      let r = await processRequest(if line == "\r\n": "" else: line, config)
      await client.send(r)
    client.close()
    
