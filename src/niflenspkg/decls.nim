## `niflens decls <file.s.nif> [symbol]` — one JSON object per SymbolDef (a
## declaration): {sym, name, kind, file, line, col}. `kind` is the enclosing
## NIF tag. Optional `symbol` filters by full symId (exact/prefix) or base name.

import std / [os, json, strutils]
include "nifprelude"
import core

proc cmd*(params: seq[string]) =
  if params.len < 1:
    stderr.writeLine "usage: niflens decls <file.s.nif> [symbol]"
    quit 1
  let path = params[0]
  let wanted = if params.len >= 2: params[1] else: ""
  if not fileExists(path):
    stderr.writeLine "niflens: no such file: " & path
    quit 2
  let buf = loadBuf(path)
  var tagStack: seq[string] = @[]
  var arr = newJArray()
  for i in 0 ..< buf.len:
    let tok = buf[i]
    case tok.kind
    of ParLe:
      tagStack.add tagName(tok)
    of ParRi:
      if tagStack.len > 0: tagStack.setLen(tagStack.len - 1)
    of SymbolDef:
      let sym = symName(tok)
      let name = baseName(sym)
      if wanted.len > 0 and not (sym == wanted or sym.startsWith(wanted) or
                                 name == wanted):
        continue
      var node = %*{
        "sym": sym, "name": name,
        "kind": (if tagStack.len > 0: tagStack[^1] else: "")
      }
      addPos(node, tok)
      arr.add node
    else:
      discard
  echo arr
