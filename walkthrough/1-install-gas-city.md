# 1. Install Gas City

« [back to README](../README.md) | [next: 2. Install the pack](./2-install-the-pack.md) »

## What you end up with

A running Gas City called `factory1`, with a supervisor process managing it and a `mayor` agent you can talk to. No project attached yet; that's step 2.

## Before you start

Check your tools first. Version mismatches show up as confusing errors three steps later, so it's worth the thirty seconds:

```bash
gc version      # 1.3 or newer
bd --version    # 1.0 or newer
dolt version    # 2.1 or newer
gh auth status  # must report a logged-in account
tmux -V
```

If `tmux` or `jq` is missing, see [the note in the README](../README.md#about-tmux). The Homebrew install of Gas City pulls both; other install routes don't.

You'll also need your fork of this repo cloned locally. Haven't done that yet?

```bash
gh repo fork actual-software/actual-factory-demo --clone --remote
```

## Pick a working directory

The city and the rig live as siblings. Pick a parent directory you're happy to keep around:

```text
~/factory-demo/
├── factory1/              # the Gas City, created below
└── actual-factory-demo/   # your fork of this repo, which is also the rig
```

Move your fork into place if it's somewhere else, then:

```bash
cd ~/factory-demo
```

## Create the city

```bash
gc init factory1
```

Answer the two interactive prompts:

- Config template: **minimal** (option `1`)
- Provider: **Claude Code**, or whichever agent you actually have installed

That writes `factory1/`, containing a `city.toml` and a `pack.toml`. Both are small enough to read end to end. Step 4 comes back to them.

Now start it:

```bash
cd factory1
export FACTORY_PATH="$(pwd)"
gc start
```

`gc start` registers the city with the supervisor, installs the background service if this is your first city, and brings up the city's Dolt server along with its agents.

**From here on the supervisor owns the Dolt server.** Don't run `bd dolt start` yourself. It starts a second Dolt that grabs a write lock on the same data directory, and then the next restart fails because the supervisor can't bring up its own. It's far and away the most common way a first run goes wrong.

## Confirm it came up

```bash
gc status
gc session list
```

`gc status` should report `Controller: supervisor-managed (PID ...)`, with a `dog` agent scaled and a `mayor` named session. `gc session list` shows one row per live session.

Now run the health check:

```bash
gc doctor
```

`✓` is a pass, `⚠` a warning, `✗` an error. A fresh minimal city usually flags one warning about legacy `[[agent]]` tables in `pack.toml`, because agents get auto-discovered these days and the declaration doesn't do anything anymore. Clear it:

```bash
gc doctor --fix
gc doctor
```

## Meet the mayor

The mayor is the factory's always-on assistant. When you can't tell what your factory is up to, it's what you ask.

```bash
gc session attach mayor
```

A `tmux` session opens with the mayor live in front of you, ready for a question. Ask it something. `What's the status of the factory?` works fine as an opener.

**Detach with `Ctrl+b` then `d`.** Never `Ctrl+c`. That kills the mayor's session outright rather than just leaving it, and then you're restarting the city to get it back.

## Verification

```bash
gc cities                  # factory1 with its absolute path
gc status                  # Controller: supervisor-managed
cat "$FACTORY_PATH/city.toml"   # a [workspace] block naming your provider
```

All three should succeed before you move on. If one doesn't, the troubleshooting below almost certainly covers it, since these are the failures everybody hits on a first run.

## Troubleshooting

**`gc status` says `Controller: stopped`, and `bd` reports "Dolt server unreachable".** You ran `gc init` but never `gc start`, so the city's files exist on disk while nothing is actually running. Run `gc start` from inside `factory1/`. Don't reach for `bd dolt start` to fix it. That just causes the next problem instead.

**`gc start` fails with `dolt server could not start via gc helper`.** Another Dolt process holds the lock. Usually it's a leftover `bd dolt start` from an earlier session, and note that `bd dolt stop` doesn't reliably terminate it. Find it and kill it:

```bash
ps aux | grep "dolt sql-server" | grep -v grep
```

Leave alone any process started with `--config .../.gc/runtime/...`. That one's the supervisor's. Kill the others, then re-run `gc start`.

**`bd` fails with `database "hq" not found`.** The Dolt server's up, but the database wasn't created. From inside `factory1/`:

```bash
gc stop
cd .beads/dolt && dolt sql -q "CREATE DATABASE IF NOT EXISTS hq;" && cd -
gc start
```

`bd` creates its schema on the next connection.

**The scroll wheel walks your shell history inside `tmux`.** That's a terminal setting rather than a Gas City problem. See [troubleshooting/tmux.md](../troubleshooting/tmux.md).

## What's next

So far you've got a factory with no work and no project. [Step 2](./2-install-the-pack.md) attaches this repo as the rig, installs the four-agent workflow, and fills the task queue.

« [back to README](../README.md) | [next: 2. Install the pack](./2-install-the-pack.md) »
