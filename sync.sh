#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE="${1:-$SCRIPT_DIR/../Raptor/.opencode/plugins/noit}"

FILES=(
  index.ts
  config.ts
  types.ts
  backfill.ts
  db.ts
  export.ts
  check.ts
  redact.ts
  config.template.json
  config.local.template.json
)

if [ ! -d "$SOURCE" ]; then
  echo "error: source plugin folder not found: $SOURCE" >&2
  exit 1
fi
SOURCE="$(cd "$SOURCE" && pwd)"

for name in "${FILES[@]}" package.json; do
  if [ ! -f "$SOURCE/$name" ]; then
    echo "error: missing source file: $SOURCE/$name" >&2
    exit 1
  fi
done

if ! command -v node >/dev/null 2>&1; then
  echo "error: node is required to rebuild package.json (Node.js 22.13+)" >&2
  exit 1
fi

changed=0
unchanged=0

echo "sync: $SOURCE -> $SCRIPT_DIR"

for name in "${FILES[@]}"; do
  if [ -f "$SCRIPT_DIR/$name" ] && cmp -s "$SOURCE/$name" "$SCRIPT_DIR/$name"; then
    unchanged=$((unchanged + 1))
    continue
  fi
  if [ -f "$SCRIPT_DIR/$name" ]; then
    echo "updated $name"
  else
    echo "added $name"
  fi
  cp -f "$SOURCE/$name" "$SCRIPT_DIR/$name"
  changed=$((changed + 1))
done

PKG_JS='
let d = ""
process.stdin.setEncoding("utf8")
process.stdin.on("data", (c) => (d += c))
process.stdin.on("end", () => {
  const base = JSON.parse(d)
  const out = {
    name: "noit-ai-declaration",
    version: base.version,
    description: "opencode plugin that generates the Bulgarian НОИТ declaration «ДЕКЛАРАЦИЯ за използване на средства с изкуствен интелект (ИИ)» (Приложение 5) from real opencode session logs.",
    license: "MIT",
    type: base.type || "module",
    main: "index.ts",
    exports: base.exports || "./index.ts",
    files: [
      "index.ts",
      "config.ts",
      "types.ts",
      "backfill.ts",
      "db.ts",
      "export.ts",
      "check.ts",
      "redact.ts",
      "config.template.json",
      "config.local.template.json",
      "README.md",
      "LICENSE",
      "CONTRIBUTING.md"
    ],
    dependencies: base.dependencies || {},
    repository: { type: "git", url: "https://github.com/InfiniteFightingGhost/noit-ai-declaration.git" },
    author: "InfiniteFightingGhost"
  }
  process.stdout.write(JSON.stringify(out, null, 2) + "\n")
})
'

version="$(node -e 'const fs=require("node:fs");const m=/"version"\s*:\s*"([^"]+)"/.exec(fs.readFileSync(process.argv[1],"utf8"));process.stdout.write(m?m[1]:"")' "$SOURCE/package.json")"
merged="$(node -e "$PKG_JS" < "$SOURCE/package.json")"

if [ -f "$SCRIPT_DIR/package.json" ] && [ "$(cat "$SCRIPT_DIR/package.json")" = "$merged" ]; then
  unchanged=$((unchanged + 1))
else
  echo "updated package.json (version $version)"
  printf '%s\n' "$merged" > "$SCRIPT_DIR/package.json"
  changed=$((changed + 1))
fi

for name in "${FILES[@]}" package.json; do
  node -e '
const fs = require("node:fs")
const p = process.argv[1]
let b
try { b = fs.readFileSync(p) } catch { console.error("error: cannot read " + p); process.exit(1) }
if (b.length >= 3 && b[0] === 0xEF && b[1] === 0xBB && b[2] === 0xBF) { console.error("error: UTF-8 BOM in " + p); process.exit(1) }
try { new TextDecoder("utf-8", { fatal: true }).decode(b) } catch { console.error("error: invalid UTF-8 in " + p); process.exit(1) }
' "$SCRIPT_DIR/$name"
done

total=$(( ${#FILES[@]} + 1 ))
echo "$total files checked, $changed changed, $unchanged unchanged"
