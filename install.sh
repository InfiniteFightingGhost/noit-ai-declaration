#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: install.sh <target-project-path>" >&2
  exit 1
fi

TARGET="$1"
if [ ! -d "$TARGET" ]; then
  echo "error: target project folder not found: $TARGET" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$(cd "$TARGET" && pwd)"
PLUGIN_DIR="$TARGET/.opencode/plugins/noit"

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
  package.json
  README.md
  LICENSE
  CONTRIBUTING.md
)

for name in "${FILES[@]}"; do
  if [ ! -f "$SCRIPT_DIR/$name" ]; then
    echo "error: missing file in this repository: $name (run sync.sh first)" >&2
    exit 1
  fi
done

mkdir -p "$PLUGIN_DIR"
echo "installing noit.ai-declaration into $PLUGIN_DIR"

copied=0
kept=0
for name in "${FILES[@]}"; do
  if [ -f "$PLUGIN_DIR/$name" ] && cmp -s "$SCRIPT_DIR/$name" "$PLUGIN_DIR/$name"; then
    kept=$((kept + 1))
    continue
  fi
  if [ -f "$PLUGIN_DIR/$name" ]; then
    echo "updated $name"
  else
    echo "added $name"
  fi
  cp -f "$SCRIPT_DIR/$name" "$PLUGIN_DIR/$name"
  copied=$((copied + 1))
done

if ! command -v npm >/dev/null 2>&1; then
  echo "error: npm is required (Node.js 22.13+ with npm)" >&2
  exit 1
fi
echo "running npm install in $PLUGIN_DIR"
(
  cd "$PLUGIN_DIR"
  npm install
)

if [ -f "$TARGET/.noit/config.json" ]; then
  echo "existing .noit/config.json preserved (not modified)"
fi

echo "$copied files changed, $kept unchanged"

if [ -f "$TARGET/opencode.json" ] && grep -Fq './.opencode/plugins/noit' "$TARGET/opencode.json"; then
  echo "opencode.json already references ./.opencode/plugins/noit"
else
  echo ""
  echo "Add this to $TARGET/opencode.json (merge the plugins array if the file already exists):"
  echo '{'
  echo '  "$schema": "https://opencode.ai/config.json",'
  echo '  "plugins": ['
  echo '    {'
  echo '      "package": "./.opencode/plugins/noit",'
  echo '      "options": {'
  echo '        "backfill": {'
  echo '          "scope": "project"'
  echo '        }'
  echo '      }'
  echo '    }'
  echo '  ]'
  echo '}'
fi

echo ""
echo "Next: restart opencode in $TARGET, then verify with /noit-status."
