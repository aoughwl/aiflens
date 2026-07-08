## `niflens serve` — a line-oriented stdio daemon.
##
## One request JSON per line: `{"cmd": "<name>", "args": ["file", ...]}`.
## One response JSON per line: the command's normal result, or
## `{"error": <msg>, "code": <int>}`. EOF on stdin exits.
##
## Keeping one process alive across requests amortizes process-spawn + Nim
## runtime init, and lets the interned `pool` (symbol/string/file tables)
## persist — the basis for the shared NIF daemon that can back both the plugin
## and a Nimony LSP.

import std / [json, strutils]
import decls, render, index, outline

proc dispatch*(cmd: string; args: seq[string]): JsonNode =
  case cmd
  of "decls": decls.run(args)
  of "render": render.run(args)
  of "index": index.run(args)
  of "outline": outline.run(args)
  of "query": outline.runQuery(args)
  else: %*{"error": "unknown cmd: " & cmd, "code": 1}

proc serve*() =
  var line: string
  while stdin.readLine(line):
    if line.strip().len == 0:
      continue
    var resp: JsonNode
    try:
      let req = parseJson(line)
      let cmd = req{"cmd"}.getStr("")
      var args: seq[string]
      if req.hasKey("args"):
        for a in req["args"]:
          args.add a.getStr
      resp = dispatch(cmd, args)
    except CatchableError as e:
      resp = %*{"error": e.msg, "code": 1}
    stdout.writeLine($resp)
    stdout.flushFile()
