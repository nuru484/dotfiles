#!/usr/bin/env bash
# Sets up this repo's Claude Code and git config on a new machine.
# Safe to re-run: it replaces existing links/files with fresh links.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Replace $2 with a symlink to $1, keeping a backup of any real file there.
link() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    local backup="$dest.pre-dotfiles"
    echo "backing up existing $(basename "$dest") -> $(basename "$backup")"
    rm -rf "$backup"
    mv "$dest" "$backup"
  fi
  rm -rf "$dest"
  ln -s "$src" "$dest"
  echo "linked $dest"
}

# Claude Code: instructions, settings, skills, hook scripts.
for item in CLAUDE.md settings.json skills hooks; do
  link "$REPO_ROOT/claude/$item" "$HOME/.claude/$item"
done

# Git: global hooks and global ignore, plus the config keys that point at them.
link "$REPO_ROOT/git/hooks" "$HOME/.git-hooks"
link "$REPO_ROOT/git/ignore" "$HOME/.config/git/ignore"
git config --global core.hooksPath "$HOME/.git-hooks"
git config --global core.excludesFile "$HOME/.config/git/ignore"

# graphify CLI, which the graphify skill and the post-commit hook call.
# Installed through uv as an isolated tool so it never touches system Python.
if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
fi
uv tool install --force "graphifyy[sql]" -q
echo "installed graphify $(graphify --version 2>/dev/null || echo '(open a new shell: ~/.local/bin is not on PATH yet)')"

echo
echo "Done. Verify:"
ls -la "$HOME/.claude/CLAUDE.md" "$HOME/.claude/settings.json" "$HOME/.claude/skills" "$HOME/.claude/hooks" "$HOME/.git-hooks" "$HOME/.config/git/ignore"
