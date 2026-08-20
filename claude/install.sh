#!/usr/bin/env bash
# Links this repo's Claude Code config into ~/.claude on a new machine.
# Safe to re-run: it replaces existing links/files with fresh links.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$HOME/.claude"

mkdir -p "$TARGET"

for item in CLAUDE.md settings.json skills hooks; do
  dest="$TARGET/$item"

  # Back up a real file/dir that is not already a link, so nothing is lost.
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    backup="$dest.pre-dotfiles"
    echo "backing up existing $item -> $(basename "$backup")"
    rm -rf "$backup"
    mv "$dest" "$backup"
  fi

  rm -rf "$dest"
  ln -s "$REPO_DIR/$item" "$dest"
  echo "linked $item"
done

echo
echo "Done. Verify:"
ls -la "$TARGET/CLAUDE.md" "$TARGET/settings.json" "$TARGET/skills" "$TARGET/hooks"
