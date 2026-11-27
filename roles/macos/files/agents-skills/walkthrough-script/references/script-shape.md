# Script shape

Copy these templates into the walkthrough script. Change names, commands,
and prompts. Do not change the flag set, the dry-run `read` rule, or the
decision prompt vocabulary (`[a]` / `[0]` / comma-separated indexes).

## Skeleton

```bash
#!/usr/bin/env bash
# <path-as-comment>
#
# Walks through <source-id> — <one-line title>.
#
# Usage:
#   <script> --dry-run        # print every command; run nothing
#   <script> --live           # execute every step (default)
#   <script> --from-step=4    # start at step 4 (skip earlier)
#   <script> --to-step=4      # stop after step 4
#
# Required environment (only needed when --live, and only for the
# steps that name them):
#   <VAR>    <purpose>

set -euo pipefail

# ---------- CLI flags ----------
DRY_RUN=false
FROM_STEP=1
TO_STEP=99
for arg in "$@"; do
  case "$arg" in
    --dry-run)         DRY_RUN=true ;;
    --live)            DRY_RUN=false ;;
    --from-step=*)     FROM_STEP="${arg#*=}" ;;
    --to-step=*)       TO_STEP="${arg#*=}" ;;
    --help|-h)
      sed -n '2,30p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown arg: $arg" >&2
      exit 1
      ;;
  esac
done

# ---------- Output helpers ----------
if [ -t 1 ]; then
  RED=$'\033[0;31m'
  GREEN=$'\033[0;32m'
  YELLOW=$'\033[1;33m'
  BLUE=$'\033[0;34m'
  NC=$'\033[0m'
else
  RED=""; GREEN=""; YELLOW=""; BLUE=""; NC=""
fi

step()  { printf "%s▶ %s%s\n" "$BLUE" "$*" "$NC"; }
ok()    { printf "%s✓ %s%s\n" "$GREEN" "$*" "$NC"; }
warn()  { printf "%s⚠ %s%s\n" "$YELLOW" "$*" "$NC"; }
fail()  { printf "%s✗ %s%s\n" "$RED"   "$*" "$NC"; }

# Run or print. In dry-run, prints the command with visible quoting.
run() {
  if $DRY_RUN; then
    printf "%s[DRY-RUN]%s %q " "$YELLOW" "$NC" "$1"
    shift
    for a in "$@"; do printf "%q " "$a"; done
    printf "\n"
  else
    "$@"
  fi
}

# Same as run but for pipelines / shell strings.
runsh() {
  if $DRY_RUN; then
    printf "%s[DRY-RUN]%s sh -c %s\n" "$YELLOW" "$NC" "$(printf '%q' "$1")"
  else
    bash -c "$1"
  fi
}

# Open a URL if possible. Never fail the script when a browser is missing.
open_url() {
  local url="$1"
  echo "Open: $url"
  if $DRY_RUN; then
    echo "[DRY-RUN] would offer to open the URL in a browser"
    return 0
  fi
  if command -v open >/dev/null 2>&1; then
    read -r -p "Open the URL in a browser now? [Y/n] " ans
    case "$ans" in
      n|N|no|No) ;;
      *) open "$url" >/dev/null 2>&1 || warn "could not open a browser" ;;
    esac
  fi
}

# Hidden paste to a dest file (mode 0600). Never echo the value.
# Dry-run prints the dest path and returns — it does not call read.
read_secret_file() {
  local dest="$1"
  local prompt="$2"
  if $DRY_RUN; then
    echo "[DRY-RUN] would prompt (hidden) and write to $dest (mode 0600)"
    return 0
  fi
  local value=""
  read -rsp "$prompt" value
  echo
  if [ -z "$value" ]; then
    fail "empty secret"
    return 1
  fi
  local dest_dir
  dest_dir=$(dirname -- "$dest")
  mkdir -p --mode=0700 "$dest_dir"
  umask 077
  printf '%s\n' "$value" > "$dest"
  chmod 0600 "$dest"
  ok "wrote $dest (mode 0600)"
}

# Hidden paste into a variable name passed by the caller.
# Dry-run does not call read. Never echo the value.
read_secret_var() {
  local varname="$1"
  local prompt="$2"
  if $DRY_RUN; then
    echo "[DRY-RUN] would prompt (hidden) and set $varname"
    printf -v "$varname" '%s' ""
    return 0
  fi
  local value=""
  read -rsp "$prompt" value
  echo
  if [ -z "$value" ]; then
    fail "empty secret"
    return 1
  fi
  printf -v "$varname" '%s' "$value"
}

# ---------- Pre-flight ----------
preflight() {
  step "Pre-flight checks"
  # Check only what this procedure needs: git repo, named CLIs, live auth.
  # Missing optional CLIs: warn and let the step skip later.
  echo
}

# ---------- Steps (one function each) ----------
# step_1_...
# step_2_...

# ---------- Summary ----------
print_summary() {
  echo "============================================================="
  if $DRY_RUN; then
    ok "[DRY-RUN COMPLETE] No commands were actually executed"
    echo
    echo "Review the printed commands above. If everything looks right:"
    echo "  $0 --live"
  else
    ok "Walkthrough complete"
    echo
    echo "Next: confirm the live outputs match the source's expected results."
    echo "Do not mark the Linear issue Done from this script."
  fi
  echo "============================================================="
}

# ---------- Main ----------
main() {
  echo "============================================================="
  echo "<source-id> — <title>"
  echo "============================================================="
  echo "Mode:        $([ "$DRY_RUN" = true ] && echo 'DRY-RUN' || echo 'LIVE')"
  echo "Steps:       $FROM_STEP → $TO_STEP"
  echo "============================================================="
  echo

  preflight

  [ "$FROM_STEP" -le 1 ] && [ "$TO_STEP" -ge 1 ] && step_1_name
  # …one line per step…

  print_summary
}

main "$@"
```

## Command step

Execute under `--live`. No extra confirm. Verify when the source names
an expected output. Idempotent create-vs-update when the source says so.

```bash
step_N_title() {
  step "Step N: <title from source>"

  if $DRY_RUN; then
    echo "[DRY-RUN] would run:"
  fi

  run <exact command from the source, argv-split>

  if ! $DRY_RUN; then
    # Optional verify from the source, e.g. gcloud describe / test -f
    ok "Step N done"
  else
    ok "[DRY-RUN] skipping verify"
  fi
  echo
}
```

Use `runsh` only when the source is a pipeline or needs shell
interpolation (`$(...)`, pipes, env expansion).

## Command + decision step

Always show the current options, even in dry-run. Dry-run prints the
prompt shape and returns. Live mode prompts until the input is valid.

Vocabulary (keep these tokens):

- `[a]` — all
- `[0]` — skip / none
- `[1]`, `[2]`, … — one item
- `1,3` — several items

```bash
step_N_title() {
  step "Step N: <title> — interactive"

  # Show current state (table / list) so the person can see the options.
  run <list-command from the source>

  if $DRY_RUN; then
    echo
    echo "[DRY-RUN] interactive prompt would show:"
    echo "   [a]  Apply to all"
    echo "   [0]  Skip"
    echo "   [1]  <item>"
    echo "   [n]  <item>"
    echo
    echo "[DRY-RUN] would then run: <mutating command> <chosen-id>"
    return 0
  fi

  # Capture ids (and labels if the source has them) into arrays.
  local -a LABELS=() IDS=()
  # …fill from the list command…

  local COUNT=${#IDS[@]}
  if [ "$COUNT" -eq 0 ]; then
    warn "No matching items. Skip step N"
    return 0
  fi

  step "Found $COUNT matching item(s) — select which to update:"
  echo
  local i
  for i in "${!IDS[@]}"; do
    printf "  [%d]  %s  %s\n" "$((i+1))" "${LABELS[$i]}" "${IDS[$i]}"
  done
  echo "  [a]  Apply to ALL $COUNT"
  echo "  [0]  Skip (none)"
  echo

  local -a TARGETS=()
  while true; do
    read -r -p "Select (e.g. '1,3' / 'a' / '0'): " SELECTION
    SELECTION=$(echo "$SELECTION" | tr -d ' ')
    case "$SELECTION" in
      0|"")
        echo "Skipped."
        return 0
        ;;
      a|A|all)
        TARGETS=("${IDS[@]}")
        break
        ;;
      *)
        local VALID=true
        local -a NUMS=()
        IFS=',' read -ra NUMS <<< "$SELECTION"
        for n in "${NUMS[@]}"; do
          if ! [[ "$n" =~ ^[0-9]+$ ]]; then
            warn "Invalid input: '$n' is not a number"; VALID=false; break
          fi
          if [ "$n" -lt 1 ] || [ "$n" -gt "$COUNT" ]; then
            warn "Out of range: '$n' (valid 1-$COUNT)"; VALID=false; break
          fi
          TARGETS+=("${IDS[$((n-1))]}")
        done
        if $VALID; then break; fi
        ;;
    esac
  done

  echo
  step "Applying to ${#TARGETS[@]} item(s)"
  local id
  for id in "${TARGETS[@]}"; do
    run <mutating command> "$id"
  done
  ok "Step N done"
  echo
}
```

If there is one match, still prompt. `[a]` and `[1]` both apply. `[0]`
skips.

## Out-of-terminal step

Print the exact action and URL from the source. Wait. If the step
produces a secret, hidden-paste it into the dest the source names
(file or env). Then run any terminal-side verify from the source.

Dry-run must not call `read` (including the `open_url` confirm). Use
the helpers above; they already no-op `read` in dry-run.

```bash
step_N_title() {
  step "Step N: <title from source>"

  echo "<exact action — one verb, one object>"
  echo "Use: <account / email / options from the source>"
  echo "When done you should have: <output the source names>"
  echo

  open_url "<url from the source>"

  if $DRY_RUN; then
    echo "[DRY-RUN] would wait until the action is done"
    echo "[DRY-RUN] would then hidden-paste into <dest>"
    echo "[DRY-RUN] would then run: <verify command>"
    return 0
  fi

  read -r -p "Press Enter when this step is done in the browser/console... "

  # Secret output → file (preferred when the source names a path):
  #   read_secret_file "$HOME/.config/example/key" "Paste the key (hidden): "
  # Secret output → env for a later command in this same function:
  #   local KEY=""
  #   read_secret_var KEY "Paste the key (hidden): "
  #   runsh "printf '%s' \"\$KEY\" | some-cli --stdin"
  #
  # Never printf '%s\n' "$KEY". Never log it.

  run <verify command from the source, if any>
  # Example verifies: test -f, stat -c '%a', a status CLI.
  # Do not print secret contents as part of verify.

  ok "Step N done"
  echo
}
```

When one Linear step is "get a key from a portal, then run a CLI", keep
both halves in this function: pause/paste first, then the `run`/`runsh`
command. That is still one step in `--from-step` numbering.

## Dry-run rule for `read`

`--dry-run` must return from every function without blocking. Allowed
`read` calls live only behind `if $DRY_RUN; then … return 0; fi` or
inside helpers that no-op when `DRY_RUN=true` (`open_url`,
`read_secret_file`, `read_secret_var`, the decision loop).

A `read -p` at the top of a step, unguarded, is a bug.
