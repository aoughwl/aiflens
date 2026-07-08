# niflens

A **NIF lens for tooling** — a thin CLI over
[Nimony](https://github.com/nim-lang/nimony)'s own NIF libraries. It reads
`nimcache/*.nif` artifacts with the **real parser** and emits compact JSON, so
tools don't reimplement a NIF reader (and inherit its bugs).

**📖 Full docs → [aoughwl.github.io/docs/niflens](https://aoughwl.github.io/docs/niflens)**

```
NIMONY_SRC=/path/to/nimony nimble build      # -> bin/niflens
niflens decls <file.s.nif> [symbol]          # declaration sites -> JSON
```

Commands: `decls`, `render`, `index`, `outline`, `query`, `serve` (stdio daemon).
Because it links the compiler's libraries, output always matches the toolchain and
tracks NIF format bumps for free.
