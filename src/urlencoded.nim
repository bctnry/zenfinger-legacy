# web/urlencoded
#
# a parser for urlencoded data, which mostly comes from POST requests.
import std/strtabs
import std/tables
from std/strutils import split, join

proc hexDigitToInt(x: char): int =
  if '0' <= x and x <= '9': return x.ord - '0'.ord
  elif 'a' <= x and x <= 'f': return x.ord - 'a'.ord + 10
  elif 'A' <= x and x <= 'F': return x.ord - 'A'.ord + 10
  else: return 0

proc decodeURIComponent*(x: string): string =
  var res = ""
  var i = 0
  let lenx = x.len
  while i < lenx:
    case x[i]:
      of '+':
        res.add(' ')
        i += 1
      of '%':
        var o = (x[i+1].hexDigitToInt)*16 + (x[i+2].hexDigitToInt)
        res.add(o.chr)
        i += 3
      else:
        res.add(x[i])
        i += 1
  return res

proc parseUrlencoded*(x: string): StringTableRef =
  var res = newStringTable()
  if x.len <= 0: return res
  for it in x.split("&"):
    let z = it.split("=")
    res[z[0]] = z[1].decodeURIComponent()
  return res

proc toHexDigit(x: int): char =
  if 0 <= x and x <= 9: ('0'.ord + x).chr
  else: ('A'.ord + x - 10).chr

proc encodeURIComponent*(x: string): string =
  var res = ""
  var i = 0
  let lenx = x.len
  while i < lenx:
    if (('A' <= x[i] and x[i] <= 'Z') or
        ('a' <= x[i] and x[i] <= 'z') or
        ('0' <= x[i] and x[i] <= '9') or
        "-_.!~*'()".contains(x[i])):
      res.add(x[i])
      i += 1
    else:
      res.add('%')
      let o = x[i].ord
      let fst = (o div 16).toHexDigit
      let snd = (o mod 16).toHexDigit
      res.add(fst)
      res.add(snd)
      i += 1
  return res

proc urlEncode*(x: StringTableRef): string =
  var res: seq[string] = @[]
  for k in x.keys():
    res.add(k.encodeURIComponent() & "=" & x[k].encodeURIComponent())
  return res.join("&")

proc urlEncode*(x: TableRef): string =
  var res: seq[string] = @[]
  for k in x.keys():
    res.add(($k).encodeURIComponent() & "=" & ($x[k]).encodeURIComponent())
  return res.join("&")

proc urlEncode*(x: Table): string =
  var res: seq[string] = @[]
  for k in x.keys():
    res.add(($k).encodeURIComponent() & "=" & ($x[k]).encodeURIComponent())
  return res.join("&")
  
proc urlEncode*[A](x: openarray[(string,A)]): string =
  var res: seq[string] = @[]
  for k in x:
    res.add(k[0].encodeURIComponent() & "=" & ($k[1]).encodeURIComponent())
  return res.join("&")

  
