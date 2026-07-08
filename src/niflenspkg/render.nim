## `niflens render <file.nif> [needle]` — render NIF node(s) as compact
## pseudo-Nim. See CONTRACT.md for the JSON shape. STUB — implemented separately.

import std / [json]
include "nifprelude"
import core

proc cmd*(params: seq[string]) =
  ## STUB: emits the empty contract shape so the dispatcher builds.
  echo %*{"nodes": newJArray()}
