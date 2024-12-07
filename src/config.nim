# config.
#
# Zenfinger retrieves the most basic truth about the system starting from the
# config file. The filename of the config file would be `.zenfinger-config`.
# Zenfinger would try to find any file with this name at the directory where
# the executable resides unless a different path is specified, in which case
# Zenfinger would still try to find `.zenfinger-config` in the directory of
# the executable but not until it couldn't find the config file in the supplied
# path. If a config file is not found, Zenfinger would refuse to start as
# a server.

import std/paths
import std/files
import std/parsecfg
import checksums/bcrypt
from std/asyncdispatch import asyncCheck
from std/strutils import strip
from aux import getExecutableDir
from log import log

let configFileName = ".zenfinger-config"

type
  ZConfig* = ref object
    sourcePath*: string
    config*: Config

var config: ZConfig = nil
proc getCurrentConfig*(): ZConfig = config

proc initConfig*(findPath: string = ""): bool =
  var fp = findPath.strip()
  if fp != "" and fp.Path.fileExists():
    config = ZConfig(sourcePath: fp, config: fp.loadConfig())
    return true
  fp = (getExecutableDir() / (configFileName.Path)).string
  if fp != "" and fp.Path.fileExists():
    config = ZConfig(sourcePath: fp, config: fp.loadConfig())
    return true
  asyncCheck log("Failed to load config file from " & findPath.repr)
  return false

proc flushConfig*(config: ZConfig): void =
  config.config.writeConfig(config.sourcePath)

proc getConfig*(config: ZConfig, group: string, key: string): string  =
  config.config.getSectionValue(group, key, "")

proc setConfig*(config: ZConfig, group: string, key: string, value: string): void =
  config.config.setSectionKey(group, key, value)

const CONFIG_GROUP_DATA* = "content"
const CONFIG_KEY_DATA_HOMEPAGE_PATH* = "homepage_path"
const CONFIG_KEY_DATA_BASE_DIR* = "base_dir"
const CONFIG_KEY_DATA_PASSWORD_DIR* = "password_dir"

const CONFIG_GROUP_HTTP* = "http"
const CONFIG_KEY_HTTP_ADDR* = "address"
const CONFIG_KEY_HTTP_PORT* = "port"
const CONFIG_KEY_HTTP_STATIC_ASSETS_DIR* = "static_assets_dir"

const CONFIG_GROUP_ADMIN* = "admin"
const CONFIG_KEY_ADMIN_PASSWORD* = "password"

  
