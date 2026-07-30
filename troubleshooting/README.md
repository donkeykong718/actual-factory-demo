# Troubleshooting

Topic-scoped guides for problems that come up while working through the walkthrough. Each is organized `Symptom → Cause → Fix`, so you can jump straight to a heading and see what to do.

## Guides

| Topic | When to read it |
| --- | --- |
| [CLI coding agents](cli-coding-agents.md) | Problems interacting with Claude Code or another CLI agent, including slash commands. |
| [tmux](tmux.md) | Terminal and session issues, most often the scroll wheel walking your shell history. |
| [gc import add](gc-import-add.md) | Packs that do not show up after an import. |

Each walkthrough step also carries its own troubleshooting section covering the failures specific to that step. Start there, since it's usually the faster path.

## The one that catches everyone

If `bd` reports `Dolt server unreachable` or `failed to open database`, run `gc stop && gc start` first. The supervisor owns Dolt's lifecycle and that is the intended knob.

Do **not** enable `dolt.auto-start`, switch Dolt to embedded mode, or run `bd dolt start` while a city is running. Each one starts a second Dolt that takes a write lock on the same data directory, and the resulting conflict is harder to undo than whatever you were trying to fix.
