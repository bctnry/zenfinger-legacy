import std/syncio
import checksums/bcrypt
import std/terminal
import ask
import aux
import config
import log
from std/asyncdispatch import asyncCheck
from std/strutils import strip
from std/paths import `/`, Path
from std/dirs import dirExists, createDir

proc install*(): void =
  let s = askWithDefault(
    "Please tell me where you'd like your config file to be.\n",
    (getExecutableDir() / (".zenfinger-config".Path)).string
  )
  var f: File
  discard f.open(s, fmWrite)
  f.close()
  if not initConfig(s):
    asyncCheck log("Somehow failed to create a config file. Exiting...")
    echo "Somehow failed to create a config file. Exiting..."
    return
  var c = getCurrentConfig()

  let fingerPort = askWithDefault(
    "Finger protocol runs on port 79, but some operating systems does not allow a normal user to open up port 1 ~ 1024 without administrator priviledge; yet it's also kind of a security concern to run this software with priviledged user. So - are you planning to run this server with a normal user and have port forwarding set up elsewhere (e.g. you're running this with Docker or Unikraft or other kind of encapsulation)? If yes, then pick the port number this server is going to bind to.",
    "79"
  )
  c.setConfig(CONFIG_GROUP_FINGER, CONFIG_KEY_FINGER_PORT, fingerPort)

  let fingerAddr = askWithDefault(
    "This option sets the address the Finger server is going to bind to. If you're planning to do port forwarding, you might want to set this option to 127.0.0.1 so that the port chosen above won't get exposed.",
    "0.0.0.0"
  )
  c.setConfig(CONFIG_GROUP_FINGER, CONFIG_KEY_FINGER_ADDR, fingerAddr)
  
  let homepagePath = askWithDefault(
    "Please tell me where you'd like to put the \"home page\" file of this server. The content of this file would be shown if the query is empty.",
    (getExecutableDir() / (".zenfinger-index".Path)).string
  )
  discard f.open(homepagePath, fmWrite)
  f.write("Welcome to our Finger server.\n\nYou can visit `[server]/_random` using a Finger protocol client or `[server]/~_random` using a web browser")
  f.close()
  c.setConfig(CONFIG_GROUP_DATA, CONFIG_KEY_DATA_HOMEPAGE_PATH, homepagePath)
  
  let baseDir = askWithDefault(
    "Please tell me where you'd like your users' content be stored: ",
    (getExecutableDir() / ("zenfinger-root".Path)).string
  )
  if not baseDir.Path.dirExists(): baseDir.Path.createDir
  c.setConfig(CONFIG_GROUP_DATA, CONFIG_KEY_DATA_BASE_DIR, baseDir)
  echo "Please note that currently, absolutely everything under this directory would be served to the public. Please don't put anything private in there."

  let passwordDir = askWithDefault(
    "Please tell me where you'd like to store the users' passwords. This password is used to edit the content over the HTTP interface.",
    (getExecutableDir() / ("zenfinger-credential".Path)).string
  )
  if not passwordDir.Path.dirExists(): passwordDir.Path.createDir
  c.setConfig(CONFIG_GROUP_DATA, CONFIG_KEY_DATA_PASSWORD_DIR, passwordDir)

  let port = askWithDefault(
    "Please tell me which port you'd like the server's HTTP proxy to take.",
    "4079"
  )
  c.setConfig(CONFIG_GROUP_HTTP, CONFIG_KEY_HTTP_PORT, port)

  let httpaddr = askWithDefault(
    "Please tell me the IP address the HTTP proxy will bind to. The Finger server listens to all incoming connections by default, but for the HTTP server you might want to have a reverse proxy in front of it, in which case the HTTP server shall bind to 127.0.0.1 meaning that it would only accepts connections from the very machine it runs on. If you're sure you don't need a reverse proxy and is fine with the HTTP server directly exposed to the public (which I don't really recommend), set this to 0.0.0.0. If you aren't sure, leave it as 127.0.0.1.",
    "127.0.0.1"
  )
  c.setConfig(CONFIG_GROUP_HTTP, CONFIG_KEY_HTTP_ADDR, httpaddr)

  let staticAssetsDir = askWithDefault(
    "This option is used to specify the location the static assets (e.g. images & stylesheets) used by the HTTP server would be. If you're not sure what this is, leave it as is; it wouldn't affect the server's main functionalities.",
    (getExecutableDir() / ("zenfinger-http-static".Path)).string
  )
  if not staticAssetsDir.Path.dirExists(): staticAssetsDir.Path.createDir
  c.setConfig(CONFIG_GROUP_HTTP, CONFIG_KEY_HTTP_STATIC_ASSETS_DIR, staticAssetsDir)

  let proxyPrefix = askWithDefault(
    "This option is to determine the site name used for the HTTP proxy.",
    "A Zenfinger server"
  )
  c.setConfig(CONFIG_GROUP_HTTP, CONFIG_KEY_HTTP_SITE_NAME, proxyPrefix)

  echo "Now - one last option. Please enter the password for the admin user of the HTTP server."
  var adminPassword = ""
  while true:
    adminPassword = readPasswordFromStdin()
    echo "Please enter the password again to confirm it:"
    let confirmPassword = readPasswordFromStdin("confirm: ")
    if adminPassword == confirmPassword: break
    else:
      echo "The two inputs don't match. I shall have you try again."
  let hashedPassword = adminPassword.strip().bcrypt(generateSalt(8))
  c.setConfig(CONFIG_GROUP_ADMIN, CONFIG_KEY_ADMIN_PASSWORD, $hashedPassword)

  c.flushConfig()

  echo "Configuration complete."
  
