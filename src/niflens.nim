## niflens — a NIF lens for tooling.
##
## A thin CLI over Nimony's own NIF libraries (nifreader/nifstreams/nifcursors/
## nifindexes). It reads `nimcache/*.nif` artifacts with the *real* parser and
## emits compact JSON for a host tool (the `nim-code` Claude Code plugin) to
## consume. Because it links the compiler's libraries, its line-info decoding,
## symbol handling and tag vocabulary always match the toolchain that produced
## the file, and track NIF format bumps.
##
## Subcommands (see CONTRACT.md for the JSON shapes):
##   decls   <file.s.nif> [symbol]   declaration sites
##   render  <file.nif>   [needle]    pseudo-Nim rendering
##   index   <file>                   interface index (.s.idx.nif) contents
##   outline <file>                   top-level named nodes
##   query   <file> <needle>          matching subtrees
##   version

import std / os
import niflenspkg / [decls, render, index, outline]

const Version = "0.2.0"

proc usage() =
  stderr.writeLine "usage: niflens <decls|render|index|outline|query|version> [args]"

proc main =
  if paramCount() < 1:
    usage(); quit 1
  let rest = commandLineParams()[1 .. ^1]
  case paramStr(1)
  of "version", "--version", "-v":
    echo "niflens " & Version
  of "decls": decls.cmd(rest)
  of "render": render.cmd(rest)
  of "index": index.cmd(rest)
  of "outline": outline.cmd(rest)
  of "query": outline.cmdQuery(rest)
  else:
    stderr.writeLine "niflens: unknown subcommand: " & paramStr(1)
    usage(); quit 1

main()
