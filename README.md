# DBML Tools — VSCode extension

Language support for [DBML](https://dbml.dbdiagram.io) (Database Markup
Language) files in Visual Studio Code.

This extension is the editor frontend for
[`dbml-tools`](https://github.com/mevdschee/dbml-tools) — a Go CLI that
ships an LSP server alongside its `tosql`, `todot`, `migrate`, and
`check` subcommands.

## Features

- **Syntax highlighting** for tables, enums, refs, table groups, project
  settings, attributes, builtin types, strings, comments, color literals,
  and relationship operators.
- **Live diagnostics** — parse and semantic errors are surfaced as red
  squiggles as you type.
- **Hover** over a table, column, enum, alias, builtin type, or attribute
  to see its definition and constraints.
- **Completions** that adapt to context: top-level keywords, builtin types
  and declared enums in column-type position, attribute names inside
  `[ … ]`, table names in `Ref` endpoints, column names after `table.`,
  inline-ref targets, `TableGroup` body, and `Project { database_type: … }`
  values.
- **Go-to-definition** (F12) on a ref endpoint, alias, or enum-as-type
  jumps to the underlying declaration.
- **Find all references** (Shift+F12) from any symbol.
- **Rename** (F2) across the whole file — tables, columns, enums, aliases,
  ref names, table groups. Names that need quoting are wrapped in `"…"`
  automatically.
- **Document outline** — the file's tables and enums show up in VSCode's
  outline view and breadcrumb bar.
- **Snippets** for common shapes: `table`, `tablefk`, `ref`, `enum`,
  `proj`, `tg`.

## Installation

### 1. Install the `dbml-tools` binary

The extension talks to the Go binary via LSP. Install it with:

```sh
go install github.com/mevdschee/dbml-tools@latest
```

…or download a prebuilt binary from the
[releases page](https://github.com/mevdschee/dbml-tools/releases) and put
it on your `$PATH`. Verify with:

```sh
dbml-tools lsp --help 2>&1 | head -3
```

### 2. Install the extension

From the Marketplace:

> Extensions panel → search **"DBML Tools"** → Install.

Or from a `.vsix`:

```sh
code --install-extension dbml-tools-0.1.0.vsix
```

The extension activates the first time you open a `.dbml` file.

## Configuration

All settings live under the `dbml.*` namespace.

| Setting              | Default | What it does                                                                                  |
| -------------------- | ------- | --------------------------------------------------------------------------------------------- |
| `dbml.path`          | `""`   | Absolute path to the `dbml-tools` binary. Leave empty to use the binary on `$PATH`.            |
| `dbml.trace.server`  | `off`   | LSP protocol tracing: `off`, `messages`, or `verbose`. Output goes to the **DBML** channel.    |
| `dbml.log.path`      | `""`   | If set, the server writes detailed logs to this file. Useful for filing bug reports.           |

Binary resolution order: `dbml.path` → `$PATH` lookup → bundled
per-platform binary.

## Commands

| Command                          | Default keybinding |
| -------------------------------- | ------------------ |
| `DBML: Restart language server`  | —                  |

Run via Cmd/Ctrl+Shift+P.

## Quick start

Create `schema.dbml` and start typing:

```dbml
Project myapp {
  database_type: 'PostgreSQL'
}

Table users as u {
  id int [pk, increment]
  email varchar(255) [not null, unique]
  status order_status
}

Enum order_status {
  pending
  shipped
  cancelled
}

Ref: orders.user_id > u.id
```

Try:

- Hover over `order_status` on the `status` column — you'll see the enum's
  values.
- F12 on `u.id` in the `Ref` line — you'll jump to the `users` table.
- F2 on `users` — rename it everywhere in the file in one go.
- Inside `[ … ]`, press Ctrl+Space — you'll see `pk`, `unique`, `not null`,
  `default`, `note`, `ref`, etc.

## Troubleshooting

The most useful tool is the **DBML** output channel (View → Output →
DBML). Set `dbml.trace.server` to `verbose` to see every request and
response.

Common symptoms:

- **"dbml-tools binary not found"** — set `dbml.path` to an absolute
  path, or put `dbml-tools` on your `$PATH`.
- **Highlighting works but nothing else does** — the grammar runs without
  the server. If you see no diagnostics/hover/completions, the server
  failed to start. Check the DBML output channel for errors, and confirm
  the binary runs directly: `dbml-tools check schema.dbml`.
- **Wrong positions / off-by-one** — LSP positions are zero-based and
  measured in UTF-16 code units. If positions look badly wrong with
  non-ASCII identifiers, please file a bug with `dbml.trace.server` set
  to `verbose` and the captured trace attached.

For step-by-step development and debugging instructions, see
[DEBUG.md](DEBUG.md).

## Development

```sh
git clone git@github.com:mevdschee/dbml-tools-vscode.git
cd dbml-tools-vscode
npm install
npm run build         # one-shot
npm run watch         # auto-rebuild
```

Then press **F5** in VSCode to launch an Extension Development Host with
the extension loaded. See [DEBUG.md](DEBUG.md) for the full workflow,
including how to point the extension at a locally built `dbml-tools`
binary.

Run the grammar tests:

```sh
npm run test:grammar
```

The grammar test files live under `test/grammar/` and use the
`vscode-tmgrammar-test` inline-assertion format.

## Project layout

```
.
├── package.json                    Manifest + scripts
├── language-configuration.json     Brackets, comments, auto-close
├── syntaxes/dbml.tmLanguage.json   TextMate grammar
├── snippets/dbml.code-snippets     Static snippets
├── src/extension.ts                LSP client wiring
├── esbuild.config.js               Bundler config
├── test/grammar/*.dbml             Grammar tokenization tests
├── server-bin/                     Per-platform `dbml-tools` binaries (CI fills)
└── DEBUG.md                        Local debugging guide
```

## License

MIT.

## See also

- [`dbml-tools`](https://github.com/mevdschee/dbml-tools) — the CLI &
  language server.
- [DBML specification](https://dbml.dbdiagram.io/docs) — the language
  this extension supports.
- [Holistics/dbml](https://github.com/holistics/dbml) — the upstream DBML
  project.
