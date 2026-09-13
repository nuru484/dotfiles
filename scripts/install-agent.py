#!/usr/bin/env python3
"""Link shared and host-specific guidance without discarding local files."""
import argparse
from pathlib import Path
import time
import re

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('agent', choices=['claude', 'codex'])
parser.add_argument('--home', type=Path, default=Path.home())
a = parser.parse_args()
repo = Path(__file__).resolve().parents[1]
home = a.home.resolve()

def backup(path):
    target = path.with_name(path.name + '.pre-dotfiles-' + str(time.time_ns()))
    path.rename(target)
    print(f'Backed up {path} to {target}')
    return target

def link(src, dest):
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.is_symlink() and dest.resolve() == src.resolve():
        return
    if dest.exists() or dest.is_symlink():
        backup(dest)
    dest.symlink_to(src, target_is_directory=src.is_dir())
    print(f'Linked {dest} -> {src}')

shared = {p.name:p for p in (repo/'skills').iterdir() if (p/'SKILL.md').is_file()}
specific = {p.name:p for p in (repo/a.agent/'skills').iterdir() if (p/'SKILL.md').is_file()}
conflicts = shared.keys() & specific.keys()
if conflicts:
    parser.error('Shared and agent-only skill names must be distinct: ' + ', '.join(sorted(conflicts)))
# Validate every selected source before changing the installation.
normalized = {}
for name, src in (shared | specific).items():
    text = (src/'SKILL.md').read_text()
    lines = text.splitlines(keepends=True)
    if not lines or lines[0].strip() != '---':
        parser.error(f'{src}: missing YAML frontmatter')
    end = next((i for i in range(1, len(lines)) if lines[i].strip() == '---'), None)
    if end is None:
        parser.error(f'{src}: unterminated YAML frontmatter')
    fields = {}
    current = None
    for line in lines[1:end]:
        match = re.match(r'^([a-zA-Z][a-zA-Z0-9_-]*):', line)
        if match:
            current = match.group(1)
            if current in fields:
                parser.error(f'{src}: duplicate frontmatter field {current}')
            fields[current] = []
        if current:
            fields[current].append(line)
    if not {'name', 'description'} <= fields.keys():
        parser.error(f'{src}: name and description are required')
    if a.agent == 'codex':
        runtime_fields = {'context', 'agent', 'model', 'hooks'} & fields.keys()
        if runtime_fields:
            parser.error(f'{src}: Claude runtime fields {sorted(runtime_fields)} need a host-specific skill, not silent conversion')
        drop = {'disable-model-invocation', 'argument-hint', 'user-invocable'}
        filtered = ''.join(''.join(value) for key, value in fields.items() if key not in drop)
        normalized[name] = lines[0] + filtered + ''.join(lines[end:])
        if fields.get('disable-model-invocation', [''])[0].split(':', 1)[-1].strip().lower() == 'true':
            policy = src/'agents/openai.yaml'
            if not policy.is_file() or not re.search(r'allow_implicit_invocation:\s*false\b', policy.read_text()):
                parser.error(f'{src}: explicit-only Claude skills need agents/openai.yaml with allow_implicit_invocation: false for Codex')

root = home/('.claude' if a.agent == 'claude' else '.agents')/'skills'
# Older installation linked the whole skills directory. Preserve its entries
# in a real installation directory so future local installs stay out of source.
if root.is_symlink():
    entries = list(root.iterdir()) if root.exists() else []
    sources = [(p.name, p.resolve()) for p in entries]
    backup(root)
    root.mkdir(parents=True)
    for name, src in sources:
        if src.exists():
            (root/name).symlink_to(src, target_is_directory=src.is_dir())
root.mkdir(parents=True, exist_ok=True)
for name, src in sorted((shared | specific).items()):
    if a.agent == 'codex':
        text = (src/'SKILL.md').read_text()
        converted = normalized[name]
        if converted != text:
            generated = home/'.local/share/dotfiles-codex-skills'/name
            generated.mkdir(parents=True, exist_ok=True)
            entrypoint = generated/'SKILL.md'
            if entrypoint.exists() and entrypoint.read_text() != converted:
                backup(entrypoint)
            if not entrypoint.exists():
                entrypoint.write_text(converted)
            for resource in src.iterdir():
                if resource.name != 'SKILL.md':
                    link(resource, generated/resource.name)
            src = generated
    link(src, root/name)
link(repo/'instructions', home/'.config/dotfiles-agent-instructions')
if a.agent == 'claude':
    for name in ['CLAUDE.md', 'settings.json', 'hooks']:
        link(repo/'claude'/name, home/'.claude'/name)
else:
    link(repo/'codex/AGENTS.md', home/'.codex/AGENTS.md')
