import nre
from os import commandLineParams
from strutils import join, strip, splitLines, `%`, repeatChar
from sequtils import toSeq, mapIt
import optional_t
import tables

let
  utilPatterms = """
      (?(DEFINE)
        (?<generic_pat>\[.+\])
        (?<docstring_pat>(?:[ ]{2,} \#\# \s .*\n)+)
      )
    """
  typeDefPattern = re("""(*ANYCRLF)(?mix)
      ^(?:type \h+|\h+)
      (?<type>
        \w+ \s* \* \s*
        .* 
        = \s*
        (?:
          (?:ref)? \s* object \s* (?:of \s* \w+)?|
          distinct \s* \w+ |
          enum
        )
      )
      \n
      (?<docstring>(?&docstring_pat))
    """ & utilPatterms)
  procDefPattern = re("""(*ANYCRLF)(?mix)
      ^\s*
      (?<def>
        (?:proc|template|iterator|macro) \s*
        (?:\w+|`[\]\[*=$]+`) \s* \*
        (?:[\S\s](?!=\n))*
      ) \s* = \n
      (?<docstring>(?&docstring_pat))
    """ & utilPatterms)
  moduleCommentPattern = re"""(?imx) ^ \#\# (?:[ ] (.+))? \h* $"""
  multipleWhitespacePattern = re"\s{2,}"

proc box*[T](val: T): ref T =
  new result
  result[] = val


proc findAllCaptureTables(input:  string, re: Regex): seq[ref Table[string, string]]=
  result = @[]
  for match in input.findIter(re):
    result.add(box match.captures.toTable())


proc stripComments(self: string): string =
  result = ""
  for line in splitLines(self):
    result.add(line.strip()[3 .. ^1])
    result.add("\l")


proc renderProc(self: ref Table[string, string]): string =
  result = "``$#``" % [
    self["def"].replace(multipleWhitespacePattern, " "),
  ]
  result.add('\l' & repeatChar(result.len, '~') & '\l')
  result.add(self["docstring"].stripComments())

proc renderType*(self: ref Table[string, string]): string =
  result = "``type $#``" % [
    self["type"].replace(multipleWhitespacePattern, " "),
  ]
  result.add('\l' & repeatChar(result.len, '~') & '\l')
  result.add(self["docstring"].stripComments())



let sourceFile = readFile(commandLineParams()[0])
let moduleComments = toSeq(sourceFile.findIter(moduleCommentPattern))
                     .mapIt(string, if it.captures[0] != nil: it.captures[0] else: "")
                     .join("\l")
let procs = sourceFile.findAllCaptureTables(procDefPattern)
let types = sourceFile.findAllCaptureTables(typeDefPattern)

var result = moduleComments
result.add "\l"

result.add "Types\l"
result.add "-----\l"
for t in types:
  result.add "\l"
  result.add renderType(t)

result.add "\l"
result.add "Operations\l"
result.add "----------\l"
for p in procs:
  result.add "\l"
  result.add renderProc(p)

echo result
