#!/usr/bin/env bash
# Agent-independent checks for Node repositories before a push.
set -euo pipefail
root="$(git rev-parse --show-toplevel)"
cd "$root"
[ -f package.json ] || exit 0
command -v node >/dev/null || { echo "Push blocked: node is required" >&2; exit 1; }
manager=$(node -p 'JSON.parse(require("fs").readFileSync("package.json", "utf8")).packageManager?.split("@")[0] || ""')
if [ -z "$manager" ]; then
  if [ -f pnpm-lock.yaml ]; then manager=pnpm
  elif [ -f yarn.lock ]; then manager=yarn
  elif [ -f bun.lock ] || [ -f bun.lockb ]; then manager=bun
  else manager=npm
  fi
fi
case "$manager" in npm|pnpm|yarn|bun) ;; *) echo "Unsupported package manager: $manager" >&2; exit 1 ;; esac
for gate in lint typecheck test; do
  if node -e 'const p=JSON.parse(require("fs").readFileSync("package.json", "utf8")); process.exit(typeof p.scripts?.[process.argv[1]] === "string" ? 0 : 1)' "$gate"; then
    echo "Push check: $manager run $gate"
    CI=true "$manager" run "$gate" || { echo "Push blocked: $gate failed" >&2; exit 1; }
  fi
done
