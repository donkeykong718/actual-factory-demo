# 2. Install the pack

« [previous: 1. Install Gas City](./1-install-gas-city.md) | [next: 3. Run the ASCII art task](./3-run-the-ascii-art-task.md) »

## What you end up with

Your fork registered as the factory's rig, a four-agent workflow installed, and a queue full of real work for the agents to claim.

## Before you start

You'll want [step 1](./1-install-gas-city.md) finished, which means `factory1` running, `$FACTORY_PATH` exported, and `gc status` reporting a supervisor-managed controller. It's worth the thirty seconds, honestly.

You also need `jq` on your PATH, since the formulas shell out to it constantly and will fail in confusing ways without it. `jq --version` should answer.

## The four agents

A **pack** is just how Gas City ships agents, formulas, and config as a single installable unit. This demo installs three small ones, and together they give you four agents:

| Agent | Scope | Role |
| --- | --- | --- |
| `mayor` | City | Dispatches work and answers your questions about the factory |
| `dog` | City | Background housekeeping, scaled automatically |
| `polecat` | Rig | Claims a task, writes the code, opens a branch |
| `refinery` | Rig | Reviews the polecat's diff, approves or rejects, publishes the pull request |

The interesting pair is `polecat` and `refinery`. The polecat never merges its own work, and the refinery isn't a passive fast-forward machine. It reads the diff, and it can bounce a task back to the pool. That gate is the whole point of the demo.

Why three packs and not one? Gas City resolves patches per scope. So `setup` supplies the polecat and refinery, `pr-gate-city` patches the city-scoped mayor, and `pr-gate-rig` patches the rig-scoped refinery while adding the formulas that put a pull request in the middle of the loop.

## Register this repo as the rig

The rig is the project the factory works on. That's this repo: your fork, already cloned next to `factory1/`.

```bash
cd "$FACTORY_PATH"
export RIG_PATH="$(cd ../actual-factory-demo && pwd)"
gc rig add "$RIG_PATH" ascii-art
```

The rig is named `ascii-art` because that's the work it holds. The directory keeps its own name, and the two don't have to match.

Confirm it registered:

```bash
gc rig list
```

You should see `ascii-art` listed, with its absolute path and an initialized beads database.

## Install the packs

Copy all three into the city's pack directory. Keep them side by side, because `pr-gate-rig` imports `setup` by relative path and composition fails if they're separated:

```bash
cd "$FACTORY_PATH"
export ARTIFACTS_PATH="$RIG_PATH/artifacts"

cp -r "$ARTIFACTS_PATH/packs/setup"         .gc/system/packs/setup
cp -r "$ARTIFACTS_PATH/packs/pr-gate-city"  .gc/system/packs/pr-gate-city
cp -r "$ARTIFACTS_PATH/packs/pr-gate-rig"   .gc/system/packs/pr-gate-rig
chmod +x .gc/system/packs/setup/assets/scripts/worktree-setup.sh
```

Now register them as imports. Scope matters, and getting it backwards is the single most common way this step fails: `pr-gate-city` patches the city-scoped mayor and takes no `--rig` flag, while `pr-gate-rig` patches the rig-scoped refinery and has to be bound to the rig.

```bash
gc import add .gc/system/packs/pr-gate-city
gc import add --rig ascii-art .gc/system/packs/pr-gate-rig
```

`pr-gate-rig` pulls `setup` in transitively, so importing `setup` directly would hand composition two candidates for the same agent. Just leave it out.

Now hand the mayor over to the pack. The minimal city template shipped a mayor of its own, but the pack's version is the one that actually knows about the pull-request flow:

```bash
rm -rf "$FACTORY_PATH/agents/mayor"
```

Then drop the now-orphaned `[[named_session]]` block from the city's `pack.toml`, so the city stops declaring a mayor it no longer defines. Open the file and delete the block:

```toml
[[named_session]]
template = "mayor"
mode = "always"
```

Restart, so the new packs, patches, and formulas take effect:

```bash
gc restart
```

## Seed the task queue

The agents read work from **beads**, a task queue backed by Dolt. Right now yours is empty. The seed script opens 12 epics and 126 child tasks, one per letter and number the ADR describes:

```bash
cd "$RIG_PATH"
cp artifacts/beads/seed-epics.sh ./seed-epics.sh
chmod +x ./seed-epics.sh
./seed-epics.sh
```

Expect `epics opened: 12`, `tasks opened: 126`, `total beads: 138`. The script refuses to run twice. Re-run it freely if you're unsure whether the first one took, because the idempotency guard will simply refuse and tell you so rather than double-seeding the queue.

Each task carries a `metadata.target_file` pointing at the file it owns. That's how the polecat knows where to write without parsing its own title.

## Verification

```bash
cd "$FACTORY_PATH"
gc import list                 # pr-gate-city at city scope
gc import list --rig ascii-art # pr-gate-rig at rig scope
gc formula list | grep -E "mol-polecat-pr|mol-refinery-pr-patrol"
```

That last command should print both formula names. Now confirm the queue actually filled:

```bash
cd "$RIG_PATH"
bd list --type=epic
```

Twelve epics, the first of them `Letters a–m`.

## Troubleshooting

**`gc formula list` shows neither formula.** The `pr-gate-rig` pack didn't load. Check `gc import list --rig ascii-art`, and if it's missing, re-run the `gc import add --rig ascii-art` command and restart.

**`gc restart` errors with `agent "mayor" not found in pack`, or the same for `refinery`.** A pack went in at the wrong scope. `pr-gate-city` takes no `--rig` flag; `pr-gate-rig` requires one. Run `gc import remove` for the misplaced pack and re-add it correctly.

**Composition fails with `agent "refinery" not found in pack`.** The `setup` pack is missing from `.gc/system/packs/`, or it's been moved somewhere `pr-gate-rig`'s relative `../setup` import can't reach. All three packs live side by side.

**`./seed-epics.sh` reports "No issues found" afterwards.** You ran it outside the rig directory, so the beads landed in a different database. Run `pwd`, `cd "$RIG_PATH"`, and re-run.

**`bd` errors with `failed to open database`.** Run `gc stop && gc start` first. That's the supported knob. Don't enable `dolt.auto-start` or run `bd dolt start`; see [step 1's troubleshooting](./1-install-gas-city.md#troubleshooting).

## What's next

The factory's built and the queue is full. [Step 3](./3-run-the-ascii-art-task.md) hands it a task and watches a pull request come out the other end.

« [previous: 1. Install Gas City](./1-install-gas-city.md) | [next: 3. Run the ASCII art task](./3-run-the-ascii-art-task.md) »
