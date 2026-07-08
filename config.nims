# Build config for niflens.
#
# niflens links Nimony's own NIF libraries (src/lib). Point NIMONY_SRC at a
# Nimony checkout; defaults to the common local path. This is a *source*
# dependency (the libs are not nimble-installed), resolved at compile time.

import std / os

const nimonySrc = getEnv("NIMONY_SRC", "/home/savant/nimony")

switch("path", nimonySrc & "/src/lib")
switch("path", nimonySrc & "/src")
switch("warning", "UnusedImport:off")
