# Host integration

The graphify CLI and graph format are shared. Slash commands in the main
skill describe Claude invocation; in Codex invoke `$graphify` followed by
the same task, or run the documented graphify CLI command.

## Claude

Use `references/hooks.md` only for an explicitly requested Claude integration.
`graphify claude install` configures Claude; it does not configure Codex.

## Codex

Use the installed skill and CLI. Do not run Claude setup commands or modify
CLAUDE.md to configure Codex. Put any requested project guidance in AGENTS.md.
Use available subagent tools only when delegation is authorized, with bounded
independent work. Otherwise perform semantic extraction inline as described in
the main skill. Do not assume Claude tool names, credentials, or memory exist.
MCP exports require separate host configuration; the Claude Desktop JSON example
in exports.md is not Codex configuration.
