version       = "0.1.0"
author        = "aoughwl"
description   = "A NIF lens: a thin CLI over Nimony's own NIF libraries that emits compact JSON for tooling."
license       = "MIT"
srcDir        = "src"
bin           = @["niflens"]
binDir        = "bin"

requires "nim >= 2.0.0"

# niflens links Nimony's src/lib NIF modules (a source dependency, not a nimble
# package). Point NIMONY_SRC at a Nimony checkout; config.nims adds the paths.
