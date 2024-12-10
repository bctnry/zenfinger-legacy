import std/strtabs
from std/strutils import join

type
  Property* = StringTableRef
  Template* = proc (prop: Property): string

type
  IsTag = bool
  TemplatePiece = (IsTag, string)
proc loadTemplateSource*(x: string): string {.compileTime.} =
  return staticRead(x)
  
proc toTemplate*(content: string): Template =
  var templatePieceList: seq[TemplatePiece] = @[]
  var i = 0
  var res: string = ""
  var readingTag: bool = false
  var tag = ""
  var piece = ""
  while i < content.len:
    if i+1 < content.len and content[i] == '%' and content[i+1] == '%':
      if not readingTag:
        readingTag = true
        templatePieceList.add((false.IsTag, piece))
        piece = ""
      else:
        readingTag = false
        templatePieceList.add((true.IsTag, tag))
        tag = ""
      i += 2
    elif readingTag:
      tag.add(content[i])
      i += 1
    else:
      piece.add(content[i])
      i += 1
  if readingTag:
    templatePieceList.add((false.IsTag, "%%" & tag))
  elif piece.len > 0:
    templatePieceList.add((true.IsTag, piece))

  return (
    proc (prop: Property): string =
      var res: seq[string] = @[]
      for k in templatePieceList:
        res.add(
          if not k[0]:
            k[1]
          elif prop.hasKey(k[1]):
            prop[k[1]]
          else:
            ""
        )
      return res.join("")
  )
