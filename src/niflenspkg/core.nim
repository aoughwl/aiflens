## Shared helpers for niflens command modules. Each command module also does
## `include "nifprelude"` for the raw NIF types/API; this module adds the small
## conveniences on top (loading, positions, names) so the commands stay short.

import std / [os, json]
include "nifprelude"
import symparser

proc loadBuf*(path: string): TokenBuf =
  ## Read a whole NIF file into a token buffer via the real streaming reader.
  var s = nifstreams.open(path)
  discard processDirectives(s.r)
  result = fromStream(s)
  close s

proc tagName*(tok: PackedToken): string = pool.tags[tok.tagId]
proc symName*(tok: PackedToken): string = pool.syms[tok.symId]

proc baseName*(sym: string): string =
  ## Human basename of a mangled symId (`add.0.mod` -> `add`).
  var isGlobal = false
  result = extractBasename(sym, isGlobal)

proc addPos*(node: JsonNode; tok: PackedToken) =
  ## Attach {file,line,col} (col 0-based, idetools convention) if the token
  ## carries valid line info.
  let i = unpack(pool.man, tok.info)
  if i.file.isValid:
    node["file"] = %pool.files[i.file]
    node["line"] = %i.line.int
    node["col"] = %i.col.int

proc errNode*(msg: string; code = 1): JsonNode =
  ## The error shape a `run` returns instead of quitting (so `serve` can keep
  ## running). `code` becomes the CLI exit code via `emit`.
  %*{"error": msg, "code": code}

proc emit*(r: JsonNode) =
  ## CLI wrapper for a command's `run` result: on an error node, write the
  ## message to stderr and quit with its code; otherwise print the JSON.
  if r.kind == JObject and r.hasKey("error"):
    stderr.writeLine r["error"].getStr
    quit r{"code"}.getInt(1)
  echo r
