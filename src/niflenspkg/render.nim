## `niflens render <file.nif> [needle]` — render NIF node(s) as compact
## pseudo-Nim. See CONTRACT.md for the JSON shape. Mirrors the heuristic
## pretty-printer in mcp/server.py (`_render_node`): map decl/expr tags to
## Nim-like syntax and demangle `sym.NN.mod` -> `sym`.

import std / [os, json, strutils, tables]
include "nifprelude"
import core

type
  RNode = ref object
    ## A tiny in-memory tree built from the token buffer.
    isAtom: bool
    tag: string          # tag string for ParLe nodes
    atom: string         # rendered raw atom (still mangled) for atoms
    isSymDef: bool       # true if this atom came from a SymbolDef token
    sym: string          # full symId for SymbolDef atoms
    children: seq[RNode]

const maxLines = 40

# --------------------------------------------------------------------------
# Atom / symbol helpers
# --------------------------------------------------------------------------

proc atomStr(tok: PackedToken): string =
  ## Best-effort textual form of a leaf token (still mangled; demangled later).
  case tok.kind
  of DotToken: "."
  of Ident: pool.strings[tok.litId]
  of Symbol, SymbolDef: symName(tok)
  of StringLit: "\"" & pool.strings[tok.litId] & "\""
  of CharLit: "'" & tok.charLit & "'"
  of IntLit: $pool.integers[tok.intId]
  of UIntLit: $pool.uintegers[tok.uintId]
  of FloatLit: $pool.floats[tok.floatId]
  else: ""

proc demangle(s: string): string =
  ## Render a NIF atom as Nim-ish: dot -> "", strip sym.NN.mod -> sym.
  if s.len == 0: return ""
  if s == ".": return ""
  if s[0] == '"': return s
  if s[0] in IdentStartChars:
    var i = 1
    while i < s.len and s[i] in IdentChars: inc i
    if i < s.len and s[i] == '.' and i + 1 < s.len and s[i+1] in {'0'..'9'}:
      let name = s[0 ..< i]
      var j = i + 1
      while j < s.len and s[j] in {'0'..'9'}: inc j
      let rest = s[j .. ^1]
      if rest.len == 0 or rest[0] == '.':
        return name
  return s

# --------------------------------------------------------------------------
# Buffer -> tree
# --------------------------------------------------------------------------

proc parseNode(buf: TokenBuf; i: var int): RNode =
  ## Recursive-descent build of one subtree starting at buf[i].
  if i >= buf.len:
    return RNode(isAtom: true, atom: "")
  let tok = buf[i]
  case tok.kind
  of ParLe:
    result = RNode(isAtom: false, tag: tagName(tok))
    inc i
    while i < buf.len and buf[i].kind != ParRi:
      result.children.add parseNode(buf, i)
    if i < buf.len: inc i          # consume ParRi
  of ParRi:
    inc i                          # malformed: stray ')'
    result = RNode(isAtom: true, atom: "")
  of SymbolDef:
    result = RNode(isAtom: true, atom: atomStr(tok),
                   isSymDef: true, sym: symName(tok))
    inc i
  else:
    result = RNode(isAtom: true, atom: atomStr(tok))
    inc i

# --------------------------------------------------------------------------
# Tree -> pseudo-Nim  (mirror of _render_node)
# --------------------------------------------------------------------------

const BinOp = {
  "add": "+", "sub": "-", "mul": "*", "div": "div", "mod": "mod",
  "shl": "shl", "shr": "shr", "bitand": "and", "bitor": "or",
  "bitxor": "xor", "eq": "==", "neq": "!=", "lt": "<", "le": "<=",
  "gt": ">", "ge": ">=", "and": "and", "or": "or", "xor": "xor"}.toTable

proc renderNode(n: RNode): string

proc rr(n: RNode): string =
  if n.isAtom: demangle(n.atom) else: renderNode(n)

proc nonempty(cs: seq[RNode]): seq[string] =
  for c in cs:
    let r = rr(c)
    if r.len > 0: result.add r

proc childNodes(cs: seq[RNode]; tag: string): seq[RNode] =
  for c in cs:
    if not c.isAtom and c.tag == tag: result.add c

proc indent(s: string): string =
  var parts: seq[string]
  for l in s.splitLines: parts.add "  " & l
  parts.join("\n")

proc renderNode(n: RNode): string =
  if n.isAtom: return demangle(n.atom)
  let tag = n.tag
  let ch = n.children

  if tag == "stmts":
    var lines: seq[string]
    for c in ch:
      let r = rr(c)
      if r.len > 0: lines.add r
    return lines.join("\n")

  if tag in ["proc", "func", "method", "macro", "template", "iterator",
             "converter"]:
    let name = if ch.len > 0: rr(ch[0]) else: ""
    let params = childNodes(ch, "params")
    let paramStr = if params.len > 0: renderNode(params[0]) else: ""
    let body = childNodes(ch, "stmts")
    var ret = ""
    var seenParams = false
    for c in (if ch.len > 1: ch[1 .. ^1] else: @[]):
      if not c.isAtom and c.tag == "params":
        seenParams = true
        continue
      if seenParams:
        let r = rr(c)
        if r.len > 0 and not (not c.isAtom and c.tag == "stmts"):
          ret = r
          break
    var head = tag & " " & name & "(" & paramStr & ")"
    if ret.len > 0: head = head & ": " & ret
    if body.len > 0:
      return head & " =\n" & indent(renderNode(body[0]))
    return head

  if tag == "params":
    var ps: seq[string]
    for c in ch:
      if not c.isAtom and c.tag in ["param", "fld"]: ps.add rr(c)
    return ps.join(", ")

  if tag in ["param", "fld"]:
    let name = if ch.len > 0: rr(ch[0]) else: ""
    var typ = ""
    for c in (if ch.len > 1: ch[1 .. ^1] else: @[]):
      let r = rr(c)
      if r.len > 0:
        typ = r
        break
    return if typ.len > 0: name & ": " & typ else: name

  if tag in ["let", "var", "const", "glet", "gvar", "tvar", "cursor"]:
    let kw = if tag in ["var", "gvar", "tvar"]: "var"
             elif tag == "const": "const" else: "let"
    let name = if ch.len > 0: rr(ch[0]) else: ""
    let rest = nonempty(if ch.len > 1: ch[1 .. ^1] else: @[])
    if rest.len >= 2: return kw & " " & name & ": " & rest[0] & " = " & rest[^1]
    if rest.len == 1: return kw & " " & name & " = " & rest[0]
    return kw & " " & name

  if tag in ["call", "cmd"]:
    if ch.len == 0: return tag & "()"
    let callee = rr(ch[0])
    var args: seq[string]
    for c in ch[1 .. ^1]:
      let a = rr(c)
      if a.len > 0: args.add a
    return callee & "(" & args.join(", ") & ")"

  if tag == "infix":
    if ch.len >= 3: return rr(ch[1]) & " " & rr(ch[0]) & " " & rr(ch[2])
    var ps: seq[string]
    for c in ch: ps.add rr(c)
    return ps.join(" ")

  if BinOp.hasKey(tag) and ch.len >= 3:
    return rr(ch[^2]) & " " & BinOp[tag] & " " & rr(ch[^1])

  if tag == "asgn" and ch.len >= 2:
    return rr(ch[0]) & " = " & rr(ch[1])

  if tag == "ret":
    let inner = nonempty(ch)
    return "return " & (if inner.len > 0: inner[0] else: "")

  if tag == "result":
    return ""

  if tag in ["if", "when"]:
    var parts: seq[string]
    for c in ch:
      if c.isAtom: continue
      let cc = c.children
      if c.tag == "elif" and cc.len >= 2:
        parts.add tag & " " & rr(cc[0]) & ": " & rr(cc[1])
      elif c.tag == "else" and cc.len > 0:
        parts.add "else: " & rr(cc[0])
    return if parts.len > 0: parts.join("\n") else: tag

  if tag == "type":
    let name = if ch.len > 0: rr(ch[0]) else: ""
    var body = ""
    for c in (if ch.len > 1: ch[1 .. ^1] else: @[]):
      let r = rr(c)
      if r.len > 0: body = r
    return if body.len > 0: "type " & name & " = " & body else: "type " & name

  if tag == "object":
    let flds = childNodes(ch, "fld")
    if flds.len > 0:
      var lines: seq[string]
      for f in flds: lines.add "  " & renderNode(f)
      return "object\n" & lines.join("\n")
    return "object"

  if tag in ["i", "u"]: return if tag == "i": "int" else: "uint"
  if tag == "f": return "float"

  if tag == "suf": return if ch.len > 0: rr(ch[0]) else: ""

  if tag in ["par", "conv"]:
    let inner = nonempty(ch)
    return if inner.len > 0: inner[^1] else: ""

  # Unknown tag -> compact raw s-expr fallback.
  var parts = @[tag]
  for c in ch:
    let r = rr(c)
    if r.len > 0: parts.add r
  return "(" & parts.join(" ") & ")"

proc truncate(s: string): string =
  let lines = s.splitLines
  if lines.len > maxLines:
    return lines[0 ..< maxLines].join("\n") & " ..."
  return s

# --------------------------------------------------------------------------
# Command entry point
# --------------------------------------------------------------------------

proc cmd*(params: seq[string]) =
  if params.len < 1:
    stderr.writeLine "usage: niflens render <file.nif> [needle]"
    quit 1
  let path = params[0]
  let needle = if params.len >= 2: params[1] else: ""
  if not fileExists(path):
    stderr.writeLine "niflens: no such file: " & path
    quit 2

  var arr = newJArray()
  try:
    var buf = loadBuf(path)
    var i = 0
    let root = parseNode(buf, i)
    if root != nil and not root.isAtom:
      for c in root.children:
        if c.isAtom or c.children.len == 0: continue
        if not c.children[0].isSymDef: continue
        let sym = c.children[0].sym
        let name = baseName(sym)
        let kind = c.tag
        if needle.len > 0 and not (sym == needle or sym.startsWith(needle) or
                                   kind == needle or name == needle):
          continue
        arr.add %*{
          "sym": sym, "name": name, "kind": kind,
          "render": truncate(renderNode(c))
        }
  except CatchableError:
    arr = newJArray()

  echo %*{"nodes": arr}
