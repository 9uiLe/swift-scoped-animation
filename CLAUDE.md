# CLAUDE.md — instructions for Claude-based coding agents

Follow `AGENTS.md` in full. Read `HANDOFF.md` before changing code; it is the
single source of truth for product scope, public API semantics, and roadmap.

## Put information where it will live longest

- **Code owns How.** Make behavior legible through names, types, and structure.
  Replace comments that narrate execution with clearer code.
- **Tests own What.** Use test names and assertions as the executable statement
  of required behavior.
- **Commit history owns Why.** Record the motivation and change context in the
  commit message, not only a description of edited files.
- **Implementation comments own Why Not.** Keep a comment only when it explains
  a hidden constraint, or why an apparently simpler alternative is unsafe or
  incorrect. Do not use comments to restate what the code does.

DocC comments remain required user-facing API documentation and should describe
the public contract and usage. Long-lived product and API decisions belong in
`HANDOFF.md`.
