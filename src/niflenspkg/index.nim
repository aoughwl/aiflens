## `niflens index <file>` — read a module's interface index (`.s.idx.nif`) via
## nifindexes. See CONTRACT.md for the JSON shape. STUB — implemented separately.

import std / [json]
include "nifprelude"
import core

proc cmd*(params: seq[string]) =
  ## STUB: emits the empty contract shape so the dispatcher builds.
  echo %*{"checksum": newJNull(), "exports": newJArray(),
          "converters": newJArray()}
