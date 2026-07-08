## `niflens outline <file>` — top-level named nodes.
## `niflens query <file> <needle>` — subtrees whose head tag/symbol matches.
## See CONTRACT.md for the JSON shapes. STUB — implemented separately.

import std / [json]
include "nifprelude"
import core

proc cmd*(params: seq[string]) =
  ## STUB (outline): emits the empty contract shape.
  echo %*{"tags": newJArray()}

proc cmdQuery*(params: seq[string]) =
  ## STUB (query): emits the empty contract shape.
  echo %*{"matches": newJArray()}
