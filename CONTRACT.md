# niflens command JSON contracts

Every command reads a NIF file with the real libraries and writes **one JSON
value** to stdout. Columns are **0-based** (idetools convention); the host
normalizes if it wants 1-based. On a usage error, write to stderr and `quit 1`;
on a missing file, `quit 2`. Never crash on malformed input — emit the empty
shape.

Shared helpers live in `niflenspkg/core.nim`: `loadBuf(path): TokenBuf`,
`tagName(tok)`, `symName(tok)`, `baseName(sym)`, `addPos(node, tok)`. Each
command module also `include "nifprelude"` for the raw API and `import core`.

## `decls <file.s.nif> [symbol]`  (implemented)

```json
[{"sym":"add.0.mod","name":"add","kind":"proc","file":"m.nim","line":1,"col":5}]
```

## `render <file.nif> [needle]`

Render node(s) as compact pseudo-Nim (proc/type/var/let/call/if/… mapped to
Nim-like syntax; `sym.NN.mod` demangled to `sym` via `baseName`). With `needle`,
only top-level decls whose symId/kind/name matches; without it, all top-level
decls of the file.

```json
{"nodes":[{"sym":"add.0.mod","name":"add","kind":"proc","render":"proc add(a: int, b: int): int = ..."}]}
```

Each `render` is one node's pseudo-Nim (may be multi-line). Keep it bounded
(~40 lines/node); append ` ...` when truncated.

## `index <file>`

`file` is a `.s.idx.nif` (or a `.s.nif`/module path from which the `.s.idx.nif`
is derived by `changeModuleExt(f, ".s.idx.nif")`). Read it via
`nifindexes.readIndex(indexName): NifIndex` and report its contents.

```json
{"checksum":"A39433...","exports":[{"sym":"add.0.mod","name":"add","kind":"proc"}],"converters":[["fromKey.0.mod","toSym.0.mod"]]}
```

`checksum` is `null` when absent. `exports` are the public symbols the index
lists (kind = the decl tag if resolvable, else `""`). `converters` mirrors the
index's converter section as `[key, sym]` pairs (empty key -> `""`).

## `outline <file>`

Top-level named nodes — the direct children of the root `(stmts …)` that are
declarations, name only, no bodies.

```json
{"tags":[{"tag":"proc","name":"add","sym":"add.0.mod","line":1,"col":5}]}
```

## `query <file> <needle>`

Subtrees whose head tag OR contained SymbolDef matches `needle` (substring on
the tag string or the symId). `snippet` is the canonical NIF text of the matched
subtree via `nifcursors.toString(cursor)`, truncated to ~40 lines with a
trailing ` ...`.

```json
{"matches":[{"tag":"proc","name":"add","snippet":"(proc :add.0.mod ...)"}]}
```
