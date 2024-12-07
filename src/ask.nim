from std/sequtils import mapIt
from std/strutils import toLowerAscii, join, strip
from std/rdstdin import readLineFromStdin

proc askWithChoice*(prompt: string, choice: seq[string] = @[], caseInsensitive: bool = true, allowCustom: bool = false): string =
  ## When called without `caseInsensitive=true`, every choice is converted to lowercase,
  ## including the returning value.
  let choiceStr = (if allowCustom:
                     "Input your answer or choose within: "
                   else:
                     "") & "[" & choice.join("/") & "]"
  let fullPrompt = prompt & " " & choiceStr
  var ch = if caseInsensitive:
             choice.mapIt(it.toLowerAscii())
           else:
             choice
  var r = readLineFromStdin(fullPrompt)
  if allowCustom: return r
  if caseInsensitive: r = r.toLowerAscii()
  while not (r in ch):
    r = readLineFromStdin(choiceStr)
    if caseInsensitive: r = r.toLowerAscii()
  return r

proc askWithDefault*(prompt: string, default: string): string =
  let fullPrompt = prompt & " (Press Enter for default option.) [" & default & "]"
  let res = readLineFromStdin(fullPrompt)
  if res.strip().len <= 0: return default
  return res
  
