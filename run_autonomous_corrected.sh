#!/usr/bin/env bash
# run_autonomous.sh – automatic cycle to execute all remaining phases

REPO_ROOT="/home/dominicusin/src/surypus"
GSDSCRIPT="${REPO_ROOT}/.agent/get-shit-done/bin/gsd-tools.cjs"

# Helper to run a gsd-tools subcommand
gsd() {
  node "${GSDSCRIPT}" "$@"
}

# Load current state
gsd state load >/dev/null

# While there are unfinished phases
while true; do
  # Try to start the next phase
  if ! gsd state begin-phase --auto >/dev/null 2>&1; then
    echo "All phases completed."
    break
  fi

  # Execute the plan (discuss → plan → execute) automatically
  gsd state advance-plan --auto >/dev/null

  # Complete the phase
  gsd state complete-phase --auto >/dev/null
done

# Final check and status output
gsd state load
gsd progress --json
