# Debugging the DBML VSCode extension locally

This guide walks you through running the extension from source, attaching a
debugger, and inspecting the LSP traffic between the editor and the Go server.

The extension has two halves:

- **Language server** — the Go binary `dbml-tools`, invoked as `dbml-tools lsp`.
  It reads JSON-RPC from stdin and writes responses + diagnostics to stdout.
- **Extension client** — the TypeScript code in `src/extension.ts`, bundled
  to `dist/extension.js` by esbuild. It spawns the server as a child process
  and routes editor requests to it via `vscode-languageclient`.

Each half is debugged independently. The most common failure modes — server
crashes, missing capabilities, wrong positions — are diagnosed by looking at
the **DBML output channel** in VSCode, optionally with `dbml.trace.server`
set to `verbose`.

## Prerequisites

- Go 1.21+ (`go version`)
- Node 18+ (`node --version`)
- VSCode 1.85+
- (Optional) Delve for stepping through the Go server: `go install github.com/go-delve/delve/cmd/dlv@latest`

## 1. Build the Go server binary

From the repository root:

```sh
go build -o ./editors/vscode/server-bin/dev/dbml-tools .
```

The dev binary lives under `server-bin/dev/` so it doesn't conflict with the
per-platform bundles shipped in published `.vsix` files.

Sanity-check it works:

```sh
./editors/vscode/server-bin/dev/dbml-tools --version 2>&1 || true
./editors/vscode/server-bin/dev/dbml-tools check testdata/blog.dbml
```

## 2. Install extension dependencies

```sh
cd editors/vscode
npm install
```

This pulls in `vscode-languageclient`, `esbuild`, `typescript`, and the
grammar-test harness.

## 3. Build the extension bundle

One-shot build:

```sh
npm run build
```

Or, for an auto-rebuilding watcher while you iterate:

```sh
npm run watch
```

This produces `dist/extension.js` (the bundle VSCode actually loads) and a
sourcemap.

## 4. Point the extension at your dev server binary

You have two options:

**Option A — `dbml.path` setting (recommended for development).** Open
VSCode's settings (the *user* or *workspace* scope is fine), search for
`dbml.path`, and set it to the absolute path of the binary you built in
step 1, e.g. `/home/you/projects/dbml-tools/editors/vscode/server-bin/dev/dbml-tools`.

**Option B — symlink on `$PATH`.** Put a `dbml-tools` symlink in `~/.local/bin/`
pointing at the dev binary. Leave `dbml.path` empty; the extension will find
it via `$PATH`.

The resolution order is: `dbml.path` → `$PATH` lookup → bundled binary.

## 5. Launch the Extension Development Host

Open `editors/vscode/` in VSCode (not the repo root — VSCode's debugger
expects the extension folder to be the workspace), then press **F5** or pick
*Run and Debug → Run Extension*.

A second VSCode window appears titled *[Extension Development Host]*. Open
any `.dbml` file in it. You should see:

- syntax highlighting (driven by the TextMate grammar)
- diagnostics (red squiggles for parse/semantic errors)
- completions (Ctrl+Space)
- hover (mouse-over)
- F12 go-to-definition on `Ref` endpoints
- F2 rename anywhere on a table/column/enum name

If anything is missing, jump to [§7 troubleshooting](#7-troubleshooting).

## 6. Read the LSP traffic

Open the **Output panel** in the Extension Development Host (View → Output)
and pick **DBML** from the dropdown. This shows everything the client
prints, including:

- spawned binary path and arguments
- startup banner and capabilities returned by `initialize`
- protocol errors

For a full request/response trace, change a setting in the dev host:

```jsonc
// settings.json
{
  "dbml.trace.server": "verbose"
}
```

Now every `textDocument/hover`, `completion`, `rename` round-trip is logged
verbatim, including the JSON bodies. This is the single most useful tool for
diagnosing "completions don't show up" or "hover is empty" symptoms — you
see exactly what the client asked for and what the server returned.

For server-side logs, also set:

```jsonc
{
  "dbml.log.path": "/tmp/dbml-lsp.log"
}
```

Restart the language server via the **DBML: Restart language server**
command (Cmd/Ctrl+Shift+P → search "DBML"). The server will now append
log lines to that file. `tail -f /tmp/dbml-lsp.log` while you edit DBML
files to watch handler dispatch in real time.

## 7. Troubleshooting

### "dbml-tools binary not found"

The extension activated but couldn't find the server. Either:

- `dbml.path` is unset and there's no `dbml-tools` on the host's `$PATH`, or
- the path is wrong (typo, relative path, file deleted)

Fix: set `dbml.path` to an absolute path that exists. Use the integrated
terminal in the dev host to verify: `ls -l "$(code --status 2>/dev/null; echo)"`.

### Highlighting works but nothing else does

The grammar ships as static JSON and works without the server. If
diagnostics/hover/completions are absent, the server failed to start or the
client failed to attach. Check the **DBML** output channel — there should be
a line like:

```
[Trace - HH:MM:SS] Sending request 'initialize - (0)'.
[Trace - HH:MM:SS] Received response 'initialize - (0)' in N ms.
```

If `initialize` never gets a response, the binary probably crashed on
startup. Confirm by running it directly:

```sh
echo '' | ./editors/vscode/server-bin/dev/dbml-tools lsp
```

It should just hang (waiting for input) rather than print an error.

### Server starts but completions/hover return nothing for a specific token

Set `dbml.trace.server` to `verbose` and reproduce the action. In the output
channel, find the request and inspect the `position` field — line/column are
zero-based and `character` is UTF-16 code units, not bytes. If the position
points somewhere unexpected (e.g. mid-emoji), the conversion in
`lsp/conv.go` may have a bug. Capture the input and file an issue.

### "Cannot rename: …"

`prepareRename` rejects renames on keywords (`Table`, `Enum`, …), builtin
types (`int`, `varchar`, …), and unresolved references. This is intentional.
If you're trying to rename a column and getting rejected, double-check the
cursor is on the column *name* identifier, not on its type.

### Edits land in the wrong place

The server returns rune-offset ranges; the client converts them to LSP
UTF-16 positions per the `Document`'s line/column table. Mismatches usually
mean the document the server has and the document VSCode has have drifted
out of sync. Save the file (or restart the server) to force a fresh
`didOpen`/`didChange`.

### Grammar test failures (`npm run test:grammar`)

The TextMate grammar tests live under `test/grammar/`. Each `.dbml` file
contains inline assertions in `// ^^^ scope.name` comments. The `^` columns
must literally line up with the source characters of the previous line. If
you change the grammar:

```sh
npm run test:grammar              # run all
npm run test:snap                 # regenerate snapshot baseline
```

## 8. Debugging the Go server with Delve

If you suspect a bug in the analyzer or handlers, attach Delve. The trick
is that the server is normally launched as a child process by the
extension, so you have to launch it manually and tell the extension to
connect to a running instance instead.

`vscode-languageclient` doesn't natively support "connect to existing
server", so the simplest approach is to add a one-line print at the top of
the handler you're investigating, recompile, and rebuild the extension
host:

```sh
# in repo root
go build -o ./editors/vscode/server-bin/dev/dbml-tools .
```

then run **DBML: Restart language server** in the dev host. There's no need
to restart the dev host itself.

For genuine step-through debugging, set a delve breakpoint via a CLI
attach:

```sh
dlv exec ./editors/vscode/server-bin/dev/dbml-tools -- lsp
```

then have the extension connect to a TCP-mode delve. This is a larger
setup — for routine work, recompile-restart is faster.

## 9. Rebuilding after Go changes

After editing any Go file under `analysis/`, `lsp/`, or the parser/lexer:

```sh
go build -o ./editors/vscode/server-bin/dev/dbml-tools .
```

then in the dev host: **DBML: Restart language server**. No need to reload
the dev window or rerun esbuild.

## 10. Rebuilding after TypeScript changes

If `npm run watch` is running, the bundle is rebuilt automatically. In the
dev host, run the **Developer: Reload Window** command — this picks up the
new `dist/extension.js` and re-activates the extension. The server child
process is restarted as a side-effect.

If you're not running watch, do `npm run build` first.

## 11. Packaging a `.vsix` to test the published flow

```sh
npm install -g @vscode/vsce
vsce package
# produces dbml-tools-0.1.0.vsix
code --install-extension dbml-tools-0.1.0.vsix
```

This installs the extension into your normal VSCode. Note that without
bundled per-platform binaries under `server-bin/<platform>-<arch>/`, the
extension will fall back to `dbml.path` / `$PATH` lookup — same as in dev.

## 12. Common workflow recap

| You changed…           | Run this                              | Then this                                       |
| ---------------------- | ------------------------------------- | ----------------------------------------------- |
| Go server code         | `go build -o .../server-bin/dev/...`  | DBML: Restart language server                   |
| Grammar JSON           | (none — VSCode hot-reloads grammars)  | Reload Window (occasionally)                    |
| `src/extension.ts`     | `npm run build` (or watch)            | Developer: Reload Window                        |
| Tests (Go)             | `go test ./...`                       |                                                 |
| Tests (grammar)        | `npm run test:grammar`                |                                                 |
| Grammar test fixtures  | edit `test/grammar/*.dbml`            | `npm run test:grammar`                          |
