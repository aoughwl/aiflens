## `niflens index <file>` — read a module's interface index (`.s.idx.nif`) via
## the real `nifindexes` library and report its contents. See CONTRACT.md for
## the JSON shape:
##   {"checksum": <string|null>,
##    "exports":[{"sym":..,"name":..,"kind":..}, ..],
##    "converters":[["<key>","<sym>"], ..]}
##
## Note on `exports`: the real `NifIndex.exports` surfaces the module's
## re-export directives (`export`/`fromexport`/`exportexcept`), each a
## `(module, NifIndexKind, seq[StrId])` tuple — not a module's own public
## symbols. We report exactly what the library provides (resolving each StrId
## name to text); we do not synthesize symbols the index does not carry.

import std / [os, json, strutils]
include "nifprelude"
import core
import symparser
import nifindexes

proc findChecksum(indexName: string): JsonNode =
  ## The `(checksum "…")` line lives in the (small) index file text; `NifIndex`
  ## has no checksum field, so scan the raw text for it.
  result = newJNull()
  var text: string
  try:
    text = readFile(indexName)
  except CatchableError:
    return result
  const marker = "(checksum \""
  let start = text.find(marker)
  if start < 0: return result
  let vstart = start + marker.len
  let vend = text.find('"', vstart)
  if vend < 0: return result
  result = %text[vstart ..< vend]

proc run*(params: seq[string]): JsonNode =
  if params.len < 1:
    return errNode("usage: niflens index <file>", 1)
  let file = params[0]

  # Derive the `.s.idx.nif` name unless we were handed one directly.
  let indexName =
    if file.endsWith(".s.idx.nif") or file.endsWith(".sc.idx.nif"): file
    else: changeModuleExt(file, ".s.idx.nif")

  if not fileExists(indexName):
    return errNode("no such file: " & indexName, 2)

  let empty = %*{"checksum": newJNull(),
                 "exports": newJArray(), "converters": newJArray()}

  var idx: NifIndex
  try:
    idx = readIndex(indexName)
  except CatchableError, Defect:
    return empty

  let checksum = findChecksum(indexName)

  var exportsArr = newJArray()
  try:
    for (module, kind, names) in idx.exports:
      let kindStr = $kind
      if names.len == 0:
        # A whole-module re-export carries no per-symbol names in the index;
        # represent the module itself faithfully rather than inventing symbols.
        exportsArr.add %*{"sym": module, "name": module, "kind": kindStr}
      else:
        for nm in names:
          let s = pool.strings[nm]
          # Filter names are bare idents, not mangled symIds; `baseName` only
          # demangles the latter, so fall back to the raw ident when it can't.
          let bn = baseName(s)
          let name = if bn.len == 0: s else: bn
          exportsArr.add %*{"sym": s, "name": name, "kind": kindStr}
  except CatchableError, Defect:
    exportsArr = newJArray()

  var convArr = newJArray()
  try:
    for (key, sym) in idx.converters:
      let k = if key == "." : "" else: key
      convArr.add %*[k, sym]
  except CatchableError, Defect:
    convArr = newJArray()

  return %*{"checksum": checksum, "exports": exportsArr, "converters": convArr}

proc cmd*(params: seq[string]) = emit(run(params))
