#!/usr/bin/env bash
#
# bootstrap.sh — fast-forward a factory to the end state of a walkthrough step.
#
#   ./bootstrap.sh <step>
#
# Runs the setup for the step you name and every step before it, leaving you
# in the post-step state. `./bootstrap.sh 2-install-the-pack` answers "make my
# factory look like I just finished step 2", not "get me ready to start it".
#
# WHAT IT DELETES: the factory directory ($FACTORY_DIR_NAME, default factory1)
# under $DEMO_PATH, and the generated output inside the rig (ascii/, .beads/,
# seed-epics.sh). It NEVER deletes the rig repo itself — that is your fork, it
# holds this script, and it may hold work you care about. Tracked files in the
# rig are left alone.

set -uo pipefail

# ── argument ──────────────────────────────────────────────────────────────────

STEP="${1:-}"
VALID_STEPS="1-install-gas-city 2-install-the-pack 3-run-the-ascii-art-task"

if [ -z "$STEP" ]; then
  echo "Usage: ./bootstrap.sh <step>"
  echo ""
  echo "Steps:"
  for s in $VALID_STEPS; do echo "  $s"; done
  echo ""
  echo "Step 4 (walk the configs) changes nothing, so bootstrap to step 3 for it."
  exit 1
fi

STEP="${STEP%.md}"

if ! echo " $VALID_STEPS " | grep -q " $STEP "; then
  echo "error: '$STEP' is not a valid step." >&2
  echo "Valid steps: $VALID_STEPS" >&2
  exit 1
fi

# ── config ────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RIG_PATH="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ ! -f "$SCRIPT_DIR/.env" ]; then
  echo "error: no .env in $SCRIPT_DIR" >&2
  echo "Run: cp $SCRIPT_DIR/.env.example $SCRIPT_DIR/.env, then edit it." >&2
  exit 1
fi

# shellcheck disable=SC1091
source "$SCRIPT_DIR/.env"

DEMO_PATH="${DEMO_PATH:-$(cd "$RIG_PATH/.." && pwd)}"
DEMO_PATH="${DEMO_PATH/#\~/$HOME}"
FACTORY_DIR_NAME="${FACTORY_DIR_NAME:-factory1}"
RIG_NAME="${RIG_NAME:-ascii-art}"
MODEL_PROVIDER="${MODEL_PROVIDER:-claude}"
FACTORY_PATH="$DEMO_PATH/$FACTORY_DIR_NAME"

if ! echo "claude codex gemini" | grep -qw "$MODEL_PROVIDER"; then
  echo "error: MODEL_PROVIDER must be claude, codex, or gemini (got '$MODEL_PROVIDER')" >&2
  exit 1
fi

# ── dependency checks ─────────────────────────────────────────────────────────
#
# Minimum versions, not exact pins. The upstream tutorial pinned exact
# versions and broke every time a tool released.

# version_at_least <found> <minimum> — true when found >= minimum.
version_at_least() {
  [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" = "$2" ]
}

check_tool() {
  local tool="$1" min="$2" found
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "error: '$tool' not found on PATH." >&2
    return 1
  fi
  [ -z "$min" ] && return 0
  found=$("$tool" version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  if [ -z "$found" ]; then
    echo "warn: could not parse a version from '$tool version'; continuing." >&2
    return 0
  fi
  if ! version_at_least "$found" "$min"; then
    echo "error: $tool $found is older than the required $min." >&2
    return 1
  fi
  echo "  $tool $found (>= $min)"
}

echo "==> Checking dependencies"
deps_ok=0
check_tool gc 1.3.0   || deps_ok=1
check_tool bd 1.0.0   || deps_ok=1
check_tool dolt 2.1.0 || deps_ok=1
for t in git gh jq tmux; do
  command -v "$t" >/dev/null 2>&1 || { echo "error: '$t' not found on PATH." >&2; deps_ok=1; }
done
if ! gh auth status >/dev/null 2>&1; then
  echo "error: gh is not authenticated. Run: gh auth login" >&2
  deps_ok=1
fi
[ "$deps_ok" -ne 0 ] && exit 1

# ── confirmation ──────────────────────────────────────────────────────────────

cat <<EOF

==> About to bootstrap to: $STEP

    Factory (will be DELETED and rebuilt) : $FACTORY_PATH
    Rig     (kept; generated files reset) : $RIG_PATH
    Rig name                              : $RIG_NAME
    Provider                              : $MODEL_PROVIDER

    Deleted in the rig: ascii/, .beads/, seed-epics.sh
    Your tracked files and git history are not touched.

EOF

read -r -p "Continue? (Y/n) " confirm
if [ "$confirm" != "Y" ]; then
  echo "==> Aborted. Nothing has been deleted."
  exit 1
fi

# ── teardown ──────────────────────────────────────────────────────────────────

echo "==> Tearing down"

if gc cities 2>/dev/null | grep -q "$FACTORY_PATH"; then
  (cd "$FACTORY_PATH" 2>/dev/null && gc stop) || true
fi

if [ -n "$FACTORY_DIR_NAME" ] && [ -d "$FACTORY_PATH" ]; then
  rm -rf "$FACTORY_PATH"
fi

# Reset only generated files in the rig. Never the rig itself.
rm -rf "$RIG_PATH/ascii" "$RIG_PATH/.beads" "$RIG_PATH/seed-epics.sh"
mkdir -p "$RIG_PATH/ascii"

# ── step 1: install gas city ──────────────────────────────────────────────────

echo "==> Step 1: creating $FACTORY_DIR_NAME"

mkdir -p "$DEMO_PATH"
cd "$DEMO_PATH" || exit 1
gc init "$FACTORY_DIR_NAME" --provider "$MODEL_PROVIDER" || exit 1
cd "$FACTORY_PATH" || exit 1

if [ "$STEP" = "1-install-gas-city" ]; then
  gc start
  echo ""
  echo "==> Bootstrapped to 1-install-gas-city."
  echo "    export FACTORY_PATH=\"$FACTORY_PATH\""
  exit 0
fi

# ── step 2: install the pack ──────────────────────────────────────────────────

echo "==> Step 2: registering the rig, installing packs, seeding the queue"

gc rig add "$RIG_PATH" "$RIG_NAME" || exit 1

ARTIFACTS_PATH="$RIG_PATH/artifacts"
cp -r "$ARTIFACTS_PATH/packs/setup"        "$FACTORY_PATH/.gc/system/packs/setup"
cp -r "$ARTIFACTS_PATH/packs/pr-gate-city" "$FACTORY_PATH/.gc/system/packs/pr-gate-city"
cp -r "$ARTIFACTS_PATH/packs/pr-gate-rig"  "$FACTORY_PATH/.gc/system/packs/pr-gate-rig"
chmod +x "$FACTORY_PATH/.gc/system/packs/setup/assets/scripts/worktree-setup.sh"

gc import add .gc/system/packs/pr-gate-city || exit 1
gc import add --rig "$RIG_NAME" .gc/system/packs/pr-gate-rig || exit 1

# Hand the mayor to the pack: drop the city's own mayor and its named_session.
rm -rf "$FACTORY_PATH/agents/mayor"
if [[ "$(uname -s)" == "Darwin" ]]; then SED_I=(-i ''); else SED_I=(-i); fi
sed "${SED_I[@]}" '/\[\[named_session\]\]/,/^$/d' "$FACTORY_PATH/pack.toml"

gc restart || true

# Seed the queue from inside the rig.
cd "$RIG_PATH" || exit 1
cp "$ARTIFACTS_PATH/beads/seed-epics.sh" ./seed-epics.sh
chmod +x ./seed-epics.sh
./seed-epics.sh || exit 1

# The rig's beads export writes a JSONL that only creates git noise here.
bd config set export.auto false >/dev/null 2>&1 || true
rm -f "$RIG_PATH/.beads/issues.jsonl"

if [ "$STEP" = "2-install-the-pack" ]; then
  cd "$FACTORY_PATH" || exit 1
  gc start
  echo ""
  echo "==> Bootstrapped to 2-install-the-pack."
  echo "    export FACTORY_PATH=\"$FACTORY_PATH\""
  echo "    export RIG_PATH=\"$RIG_PATH\""
  exit 0
fi

# ── step 3: ready to run the task ─────────────────────────────────────────────
#
# Step 3 is the live agent run, which this script deliberately does not perform
# for you — watching it is the point. This leaves the factory ready to sling.

cd "$FACTORY_PATH" || exit 1
gc start

cat <<EOF

==> Bootstrapped to 3-run-the-ascii-art-task (ready to sling).

    export FACTORY_PATH="$FACTORY_PATH"
    export RIG_PATH="$RIG_PATH"

    Then, from the rig:
      export BEAD_ID=\$(bd list --type=task --status=open --limit 0 | grep -E "Implement a\.md\$" | awk '{print \$2}')

    And from the factory:
      gc sling $RIG_NAME/pr-gate-rig.polecat "\$BEAD_ID" --on mol-polecat-pr

EOF

cat <<'EOF'
==> If beads or Dolt misbehave

    1. Try `gc stop && gc start` first. The supervisor owns Dolt's lifecycle
       and this is the intended knob.
    2. Do NOT enable dolt.auto-start, switch to embedded mode, or run
       `bd dolt start` while a city is running. Each one causes a lock
       conflict that is harder to undo than the problem you started with.

EOF
