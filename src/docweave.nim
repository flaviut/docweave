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
        (?<docstring_pat>(?:[ ]{2,} \#\# \s .+\n)*)
      )
    """
  typeDefPattern = re("""(?mix)
      ^(?:type \h+|\h+)
      (?<name>\w+) \s* \* \s*
      (?<generic_args>(?&generic_pat))? \s*
      (?<pragmas> {\. .* \.})? \s*
      = \s*
      (?<type>
        (?:ref)? \s* object \s* (?:of \s* \w+)?|
        distinct \s* \w+ |
        enum
      )
      \n
      (?<docstring>(?&docstring_pat))
    """ & utilPatterms)
  procDefPattern = re("""(?mix)
      ^
      (?<type>proc|template|iterator|macro) \s*
      (?<name>\w+|`[\]\[*=$]+`) \s* \* \s*
      (?<generic_args>(?&generic_pat))? \s*
      \((?<args>
        (?:.+ \s* (?: : \s*+ .+ \s* )?,)*?
        (?:.+ \s* (?: : \s*+ .+ \s* )?)?
      )\)\s*
      (?: : \s* (?<return_type>\w+ \s*? (?&generic_pat)?))? \s*
      (?<pragmas> {\. .* \.})? \s*
      = \s* \n
      (?<docstring>(?&docstring_pat))
    """ & utilPatterms)
  moduleCommentPattern = re"""(?imx) ^ \#\# \s (.+) \s* $"""


proc findAllCaptureTables(input:  string, re: Regex): seq[Table[string, string]]=
  result = @[]
  for match in input.findIter(re):
    result.add(match.captures.toTable())


proc stripComments(self: string): string =
  result = ""
  for line in splitLines(self):
    let nextLine = line.strip()[3 .. ^1]
    if nextLine != "":
      result.add(nextLine)
      result.add("\l")


proc renderProc(self: Table[string, string]): string =
  result = "``$# $#*$#($#): $#``" % [
    self["type"],
    self["name"],
    if self["generic_args"] != nil: self["generic_args"] else: "",
    self["args"],
    self["return_type"],
  ]
  result.add('\l' & repeatChar(result.len, '~') & '\l')
  result.add(self["docstring"].stripComments())

proc renderType*(self: Table[string, string]): string =
  result = "``type $#*$# = $#``" % [
    self["name"],
    if self["generic_args"] != nil: self["generic_args"] else: "",
    self["type"],
  ]
  result.add('\l' & repeatChar(result.len, '~') & '\l')
  result.add(self["docstring"].stripComments())



let sourceFile = readFile(commandLineParams()[0])
let moduleComments = toSeq(sourceFile.findIter(moduleCommentPattern))
                     .mapIt(string, it.captures[0])
                     .join("\l")
let procs = sourceFile.findAllCaptureTables(procDefPattern)
let types = sourceFile.findAllCaptureTables(typeDefPattern)

echo moduleComments

echo "Operations"
echo "----------"
for p in procs:
  echo()
  echo(renderProc(p))

echo "Types"
echo "-----"
for t in types:
  echo()
  echo(renderType(t))
