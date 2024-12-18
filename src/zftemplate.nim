import std/macros


proc parseTemplate(x: string): seq[(bool, string)] {.compileTime.} =
  var res: seq[(bool, string)] = @[]
  var isTag = false
  var currentPiece = ""
  var currentTag = ""
  var i = 0
  let lenx = x.len
  while i < lenx:
    if x[i] == '{' and i+1 < lenx and x[i+1] == '{':
      if isTag:
        currentTag.add('{')
        currentTag.add('{')
        i += 2
      else:
        res.add((false, currentPiece))
        currentPiece = ""
        isTag = true
        i += 2
    elif x[i] == '}' and i+1 < lenx and x[i+1] == '}':
      if not isTag:
        currentPiece.add('}')
        currentPiece.add('}')
        i += 2
      else:
        res.add((true, currentTag))
        currentTag = ""
        isTag = false
        i += 2
    else:
      if isTag:
        currentTag.add(x[i])
        i += 1
      else:
        currentPiece.add(x[i])
        i += 1
  if isTag and currentTag.len > 0:
    currentPiece &= "{{" & currentTag
  if currentPiece.len > 0:
    res.add((false, currentPiece))
  return res

macro useTemplate*(name: untyped, filename: static[string]): untyped =
  result = nnkStmtList.newTree()
  let s = staticRead(filename)
  let v = s.parseTemplate
  result.add quote do:
    proc `name`(prop: StringTableRef): string =
      let p = `v`
      var res: seq[string] = @[]
      for k in p:
        if k[0]:
          res.add(if prop.hasKey(k[1]): prop[k[1]] else: "")
        else:
          res.add(k[1])
      return res.join("")

  
