## niflens — a NIF lens for tooling.
##
## A thin CLI over Nimony's own NIF libraries (nifreader/nifstreams/nifcursors/
## nifindexes). It reads `nimcache/*.nif` artifacts with the *real* parser — not
## a regex reimplementation — and emits compact JSON for a host tool (the
## `nim-code` Claude Code plugin) to consume. Because it links the compiler's
## libraries, its line-info decoding, symbol handling and tag vocabulary always
## match the toolchain that produced the file, and track NIF format bumps.
##
## Usage:
##   niflens decls  <file.s.nif> [symbol]   # declaration sites -> JSON
##   niflens version
##
## Subcommands are added as the plugin migrates operations off its Python
## fallback parser. See README.

import std / [os, json, strutils]

include "nifprelude"
import symparser

const Version = "0.1.0"

proc loadBuf(path: string): TokenBuf =
  ## Read a whole NIF file into a token buffer via the real streaming reader.
  var s = nifstreams.open(path)
  discard processDirectives(s.r)
  result = fromStream(s)
  close s

proc basenameOf(sym: string): string =
  var isGlobal = false
  result = extractBasename(sym, isGlobal)

proc cmdDecls(path: string; wanted: string) =
  ## Emit one JSON object per SymbolDef (a declaration) in the file:
  ## {sym, name, kind, file, line, col}. `kind` is the enclosing NIF tag.
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
      tagStack.add pool.tags[tok.tagId]
    of ParRi:
      if tagStack.len > 0: tagStack.setLen(tagStack.len - 1)
    of SymbolDef:
      let sym = pool.syms[tok.symId]
      let name = basenameOf(sym)
      if wanted.len > 0 and not (sym == wanted or sym.startsWith(wanted) or
                                 name == wanted):
        continue
      let info = unpack(pool.man, tok.info)
      var node = %*{
        "sym": sym,
        "name": name,
        "kind": (if tagStack.len > 0: tagStack[^1] else: "")
      }
      if info.file.isValid:
        node["file"] = %pool.files[info.file]
        node["line"] = %info.line
        node["col"] = %info.col
      arr.add node
    else:
      discard
  echo arr

proc main =
  if paramCount() < 1:
    stderr.writeLine "usage: niflens <decls|version> [args]"
    quit 1
  case paramStr(1)
  of "version", "--version", "-v":
    echo "niflens " & Version
  of "decls":
    if paramCount() < 2:
      stderr.writeLine "usage: niflens decls <file.s.nif> [symbol]"
      quit 1
    cmdDecls(paramStr(2), (if paramCount() >= 3: paramStr(3) else: ""))
  else:
    stderr.writeLine "niflens: unknown subcommand: " & paramStr(1)
    quit 1

main()
