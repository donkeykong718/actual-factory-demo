# Bootstrap

Fast-forward a factory to the end state of any walkthrough step, so you can reset between runs or catch up after a step goes wrong.

## Setup

```bash
cp .env.example .env
```

Every value in `.env` has a working default. Read it once and change whatever's wrong for your machine, which is usually nothing.

## Use

```bash
chmod +x bootstrap.sh
./bootstrap.sh 2-install-the-pack
```

That runs the setup for step 2 and every step before it, leaving your factory in the state you would be in having just finished step 2. Valid steps:

- `1-install-gas-city`
- `2-install-the-pack`
- `3-run-the-ascii-art-task`

Step 4 only reads config, so bootstrap to step 3 when you want to work through it.

The mental model is "make my factory look like I just finished this step," not "get me ready to start it."

## What it deletes

The script is destructive by design, and safe to re-run. It prints exactly what it'll delete, then waits for a capital `Y` before touching anything.

**Deleted and rebuilt:** the factory directory (`factory1/` by default) under `DEMO_PATH`.

**Reset inside the rig:** `ascii/`, `.beads/`, and `seed-epics.sh` — the generated output of a previous run.

**Never touched:** the rig repo itself. That's your fork, it holds this script and the walkthrough you're reading, and it may well hold work you care about. Tracked files and git history are left alone.

Switching between steps is safe. The end state depends only on the argument you pass, since every run tears down to the same baseline before rebuilding.

## Dependency checks

The script verifies `gc` 1.3+, `bd` 1.0+, and `dolt` 2.1+, plus the presence of `git`, `gh`, `jq`, and `tmux`, and that `gh` is authenticated. These are **minimum** versions rather than exact pins, so a newer toolchain passes.

Missing something? The [prerequisites in the README](../README.md#prerequisites) cover how to get it.
