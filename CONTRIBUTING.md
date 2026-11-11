# Contributing

## Requirements

- Node.js 22.13 or newer (the plugin uses `node:sqlite` without flags);
- opencode 2.0.18, the version this plugin is tested with;
- PowerShell 7+ (Windows) or bash (macOS/Linux) to run the repository scripts.

## Local test loop

1. `npm install` in the repository root (installs `@opencode/plugin` for editor and type support).
2. Prepare a scratch opencode project (an `opencode.json` and, optionally, `.opencode/`).
3. Install this checkout into it:
   - Windows: `./install.ps1 <path-to-scratch-project>`
   - macOS/Linux: `./install.sh <path-to-scratch-project>`

   Or copy the runtime files manually into `<scratch-project>/.opencode/plugins/noit` and run `npm install` there.
4. Start opencode in the scratch project and exercise the plugin: `/noit-status`, `/noit-backfill`, `/noit-export`, `/noit-check`.
5. Inspect the scratch project's `.noit/` directory: `ai-log.jsonl` (live capture), `raw/sessions/` (session dumps), `export/AI/` (the deliverable package).

## Coding conventions

- The plugin source is loaded directly by opencode with Node.js type stripping, so only erasable TypeScript syntax is allowed: no enums, no namespaces, no parameter properties, no `import =`/`export =`.
- Use `import type` for type-only imports and keep relative imports with explicit `.ts` extensions.
- ESM only (`"type": "module"`); import Node built-ins with the `node:` prefix and use `node:sqlite` for database access.
- Do not add runtime dependencies beyond `@opencode/plugin`.
- All files are UTF-8 without BOM; the sync scripts verify this after every copy.
- The plugin must not make network requests; capture data stays in `.noit/`.
- The checker must stay conservative: a false FAIL is acceptable, a false PASS is not.

## Running the checker

- In an opencode session with the plugin loaded, run `/noit-check` (or ask the model to call the `noit_check` tool).
- It rewrites `.noit/export/AI/checklist.md`. On a fresh project, expect failures for `manual-fields` and for the Section A date/signature fields until a human fills them in — see the README for the full checklist.
- Always export first (`/noit-export`), then check.

## Syncing from the upstream source

This repository is a distributable copy of the plugin. After the upstream plugin changes, re-sync it with a single command:

- Windows: `./sync.ps1` (optionally `-Source <path-to-plugin-folder>`)
- macOS/Linux: `./sync.sh` (optionally pass the source path as the first argument)

Default source: `../Raptor/.opencode/plugins/noit` relative to this repository. Sync copies the plugin source files (`index.ts`, `config.ts`, `types.ts`, `backfill.ts`, `db.ts`, `export.ts`, `check.ts`, `redact.ts`, `config.template.json`, `config.local.template.json`) byte-for-byte and regenerates `package.json` from the source `version`/`dependencies` plus the fixed repository metadata. It never touches `README.md`, `LICENSE`, `CONTRIBUTING.md` or `.gitignore`.
