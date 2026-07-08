# niflens

A **NIF lens for tooling** — a thin CLI over
[Nimony](https://github.com/nim-lang/nimony)'s own NIF libraries
(`nifreader` / `nifstreams` / `nifcursors` / `nifindexes`). It reads
`nimcache/*.nif` artifacts with the **real parser** and emits compact JSON for a
host tool to consume.

## Why

Tools that inspect NIF (an LSP, the [`nim-code`](https://github.com/aoughwl/nim-code)
Claude Code plugin, a formatter) otherwise re-implement a NIF reader — usually a
regex/hand-rolled scanner — and inherit a class of bugs: approximate line-info
decoding, mishandled escapes, a stale tag vocabulary, no real index reading.
Because niflens *links the compiler's libraries*, its output always matches the
toolchain that produced the file, and it tracks NIF format bumps (`nif26` →
`nif27` → …) for free.

Concretely, versus a regex reimplementation, `niflens decls` returns the **name**
glyph position (not the enclosing keyword), the **full module-qualified symId**
(`add.0.<module>`, not a truncated `add.0.`), and the complete symbol table
(params, results, fields, compiler-synthesised hooks), all with the compiler's
own line info.

## Design

niflens is the CLI/daemon frontend of a shared NIF core intended to back **both**
the `nim-code` plugin and a Nimony LSP. The host (e.g. the plugin's Python MCP
server) shells out to niflens for NIF parsing — the same subprocess pattern it
already uses for `nimony` / `nimsem` — and falls back to its own reader when the
binary is absent. Subprocess (not FFI) keeps crash isolation, avoids an ABI/GC
boundary, and needs no per-platform shared library.

## Build

niflens links Nimony's `src/lib` NIF modules — a **source** dependency, not a
nimble package. Point `NIMONY_SRC` at a Nimony checkout (defaults to
`/home/savant/nimony`):

```
NIMONY_SRC=/path/to/nimony nimble build      # -> bin/niflens
```

## Usage

```
niflens decls <file.s.nif> [symbol]   # declaration sites -> JSON array
niflens version
```

`decls` emits one object per `SymbolDef` (a `:`-prefixed token is a declaration
in NIF): `{sym, name, kind, file, line, col}`, where `kind` is the enclosing NIF
tag and `col` is 0-based (idetools convention). An optional `symbol` filters by
full symId (exact / prefix) or human base name.

```json
[{"sym":"addup.0.mwsmvs","name":"addup","kind":"proc","file":"m.nim","line":1,"col":5}]
```

## Roadmap

Commands are added as the plugin migrates operations off its fallback parser,
roughly in order of correctness upside: `decls` (done) → index reads via
`nifindexes` (`.s.idx.nif`) → `render` (semantic pseudo-Nim) → `outline` /
`query` → a persistent `serve` (stdio) daemon holding parsed indexes in memory,
shared with the LSP.

## License

MIT.
