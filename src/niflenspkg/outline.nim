## `niflens outline <file>` — top-level named nodes: the direct children of the
## root `(stmts …)` that are declarations (first child is a SymbolDef). Names
## only, no bodies.
## `niflens query <file> <needle>` — every subtree whose head tag string
## contains `needle`, or that declares a SymbolDef whose symId contains
## `needle`. `snippet` is the canonical NIF text of the subtree, truncated.
## See CONTRACT.md for the JSON shapes.

import std / [os, json, strutils]
include "nifprelude"
import core

const
  MaxMatches = 200      ## upper bound on query matches
  MaxLines = 40         ## snippet truncation threshold (lines)

proc truncateSnippet(s: string): string =
  ## Keep at most `MaxLines` lines; append " ..." when the text was longer.
  let lines = s.splitLines()
  if lines.len <= MaxLines:
    result = s
  else:
    result = lines[0 ..< MaxLines].join("\n") & "\n ..."

proc run*(params: seq[string]): JsonNode =
  ## outline: top-level declarations of the root `(stmts …)`.
  if params.len < 1:
    return errNode("usage: niflens outline <file>", 1)
  let path = params[0]
  if not fileExists(path):
    return errNode("no such file: " & path, 2)
  var arr = newJArray()
  try:
    var buf = loadBuf(path)
    var c = beginRead(buf)
    if c.kind == ParLe:
      inc c                      # descend into the root's first child
      while c.kind != ParRi and c.kind != EofToken:
        if c.kind == ParLe:
          let declTok = c.load
          var son = firstSon(c)
          # A decl's name is its first child: SymbolDef/Symbol post-sem
          # (`.s.nif`), or a plain Ident pre-sem (`.p.nif`).
          if son.kind in {SymbolDef, Symbol, Ident}:
            let symTok = son.load
            var sym, name: string
            if son.kind == Ident:
              sym = pool.strings[symTok.litId]
              name = sym
            else:
              sym = symName(symTok)
              name = baseName(sym)
              if name.len == 0: name = sym
            var node = %*{
              "tag": tagName(declTok), "name": name, "sym": sym
            }
            addPos(node, symTok)
            arr.add node
          skip c                 # advance to the next sibling
        else:
          inc c
    endRead buf
  except CatchableError:
    arr = newJArray()
  return %*{"tags": arr}

proc cmd*(params: seq[string]) = emit(run(params))

proc runQuery*(params: seq[string]): JsonNode =
  ## query: subtrees whose head tag OR contained SymbolDef matches `needle`.
  if params.len < 2:
    return errNode("usage: niflens query <file> <needle>", 1)
  let path = params[0]
  let needle = params[1]
  if not fileExists(path):
    return errNode("no such file: " & path, 2)
  var arr = newJArray()
  try:
    var buf = loadBuf(path)
    var c = beginRead(buf)
    var depth = 0
    while arr.len < MaxMatches:
      let k = c.kind
      if k == EofToken:
        break
      elif k == ParRi:
        dec depth
        inc c
        if depth <= 0: break
        continue
      elif k == ParLe:
        inc depth
        let tag = tagName(c.load)
        var name = ""
        var matched = needle.len > 0 and needle in tag
        # A decl carries its SymbolDef as the first son.
        var son = firstSon(c)
        if son.kind == SymbolDef:
          let sym = symName(son.load)
          name = baseName(sym)
          if not matched and needle.len > 0 and needle in sym:
            matched = true
        if matched:
          var sub = c
          let snippet = truncateSnippet(toString(sub, false))
          arr.add %*{"tag": tag, "name": name, "snippet": snippet}
      inc c
    endRead buf
  except CatchableError:
    arr = newJArray()
  return %*{"matches": arr}

proc cmdQuery*(params: seq[string]) = emit(runQuery(params))
