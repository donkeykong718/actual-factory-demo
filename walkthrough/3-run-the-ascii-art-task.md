# 3. Run the ASCII art task

« [previous: 2. Install the pack](./2-install-the-pack.md) | [next: 4. Walk the configs](./4-walk-the-configs.md) »

## What you end up with

One task carried from the queue to an open pull request on your fork, without you writing a line of the code.

## Before you start

You'll want [step 2](./2-install-the-pack.md) finished: rig registered, three packs imported, 138 tasks seeded, and both `$FACTORY_PATH` and `$RIG_PATH` exported.

`gh auth status` needs to report a logged-in account that can open pull requests against your fork. If it can't, the refinery gets all the way to the end and then fails on the last step.

## In a hurry?

This step takes a few minutes of real agent time. If you're watching a demo rather than running one, the [`ascii-art-complete`](https://github.com/actual-software/actual-factory-demo/tree/ascii-art-complete) branch already holds the finished output and [pull request #1](https://github.com/actual-software/actual-factory-demo/pull/1) shows it as a diff. Skip ahead now, and come back to this later.

## Pick a task

Let's list the first few letter tasks, then grab whichever one you like:

```bash
cd "$RIG_PATH"
bd list --type=task --status=open --limit 0 | grep "Implement [a-c]\.md"
```

Take `Implement a.md` and capture its id, since you'll reference it repeatedly:

```bash
export BEAD_ID=$(bd list --type=task --status=open --limit 0 | grep -E "Implement a\.md$" | awk '{print $2}')
bd show "$BEAD_ID"
```

Note the `metadata.target_file: ascii/a.md`. That's what the polecat reads to figure out where to write, which means you can retarget a task by editing its metadata rather than its title.

## Hand it to the factory

```bash
cd "$FACTORY_PATH"
gc sling ascii-art/pr-gate-rig.polecat "$BEAD_ID" --on mol-polecat-pr
```

`gc sling` is how work reaches an agent, and all three parts of that command carry weight:

- `ascii-art/pr-gate-rig.polecat` names the target as `<rig>/<pack>.<agent>`
- `$BEAD_ID` is the task
- `--on mol-polecat-pr` picks the formula, the recipe the agent follows

The formula is the load-bearing part here. `mol-polecat-pr` stamps `merge_strategy=pr` onto the task, and that single key is what later tells the refinery to publish a pull request rather than merging the branch itself. Sling with the stock `mol-polecat-work` instead? Then the refinery fast-forwards straight onto `main`. No gate at all.

## Watch it work

```bash
gc session list
```

A `polecat` session should appear within a few seconds. To watch it live:

```bash
gc session attach <polecat-session>
```

Remember: **`Ctrl+b` then `d` to detach.** `Ctrl+c` kills the session.

If nothing seems to be happening after a minute or two, don't attach. Nudge it instead:

```bash
gc session nudge <polecat-session> "Check for any assigned work"
```

Meanwhile, watch the task's metadata change:

```bash
watch -n 5 "bd show $BEAD_ID"
```

macOS doesn't ship `watch`. Either `brew install watch`, or just loop it yourself:

```bash
while true; do clear; bd show "$BEAD_ID"; sleep 5; done
```

Here's the sequence you're looking for:

1. Status flips `open → in_progress` and an `assignee` appears — the polecat claimed it
2. `branch` and `work_dir` get stamped — it made a worktree and started writing
3. Status returns to `open` with `gc.routed_to: ascii-art/refinery` — the polecat handed off
4. `refinery_approved: true` appears — the gate cleared
5. `pr_url` and `pr_number` get set — the pull request is live

Step 4 is the one worth pausing on. The refinery rebased the branch, ran whatever checks the rig defines, read the actual diff, and then made a call. Had it rejected the work, you'd see `refinery_approved: false` with a `blocked_reason`, and the task would land back in the pool rather than becoming somebody else's cleanup job.

## Look at the result

```bash
cd "$RIG_PATH"
export PR=$(bd show "$BEAD_ID" --json | jq -r '.[0].metadata.pr_number')
gh pr view "$PR"
gh pr view "$PR" --web
```

The diff should be one new file at `ascii/a.md`: an H1 with the letter, a fenced code block holding the art, and a two-line rhyme. Those constraints come from [ADR 0001](../docs/decision-records/0001.ADR.ASCII.md), which the agents read as part of their context.

Merge it when you're happy:

```bash
gh pr merge "$PR" --merge
```

## Run another

The loop is the same. Two more letters is plenty:

```bash
cd "$RIG_PATH"
export BEAD_ID=$(bd list --type=task --status=open --limit 0 | grep -E "Implement b\.md$" | awk '{print $2}')
cd "$FACTORY_PATH" && gc sling ascii-art/pr-gate-rig.polecat "$BEAD_ID" --on mol-polecat-pr
```

Resist working through the whole epic. You want clean state to compare against later, and honestly the interesting part has already happened.

## Verification

```bash
cd "$RIG_PATH"
git fetch origin && git pull
ls ascii/                      # the letters you ran
gh pr list --state=merged      # one merged PR per letter
git worktree list              # only the main checkout remains
```

That last check matters. The polecat cleans up its own worktree when it finishes, so leftovers mean a session died mid-run.

## Troubleshooting

**The polecat never claims the task.** Confirm the agent is running with `gc session list`, then `bd show "$BEAD_ID"`. If `assignee` is still blank after a few seconds, the sling didn't dispatch — re-run it and read the output for an error.

**The refinery rebases but `pr_url` never appears.** The approval step errored. Check the refinery's session for the diff it was reading; an empty diff means the polecat never wrote the file, which is a polecat problem rather than a refinery one.

**`refinery_approved: false` on a clean letter.** Read `metadata.blocked_reason` — the refinery is telling you which check failed. Usually the polecat wrote an empty file, or wrote to `a.md` instead of `ascii/a.md`. Re-sling once. Twice in a row means something drifted in the polecat's prompt.

**The pull request opened on the wrong repository.** Run `git remote -v` in the rig. `origin` must point at your fork. If you cloned this repo directly instead of forking it, you don't have push rights, and the refinery's `gh pr create` fails.

**The refinery refuses to merge because checks fail.** This rig defines no test suite, so the refinery should take its "no checks configured" path. If it fails anyway, its session log names the check it tried to run.

## What's next

You watched it happen. [Step 4](./4-walk-the-configs.md) opens the files that made it happen.

« [previous: 2. Install the pack](./2-install-the-pack.md) | [next: 4. Walk the configs](./4-walk-the-configs.md) »
