#!/usr/bin/env bash
# scripts/install-remaining-sudo-casks.sh
#
# Walks through installing the remaining Brewfile casks that need sudo, so
# they cannot be installed from Ansible: dotnet-sdk, teamviewer,
# adobe-acrobat-reader, obs.
#
# Usage:
#   scripts/install-remaining-sudo-casks.sh --dry-run        # print every command; run nothing
#   scripts/install-remaining-sudo-casks.sh --live           # execute every step (default)
#   scripts/install-remaining-sudo-casks.sh --from-step=2    # start at step 2 (skip earlier)
#   scripts/install-remaining-sudo-casks.sh --to-step=2      # stop after step 2
#
# Required environment: none. Homebrew asks for your macOS password
# when an installer needs sudo.

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
      sed -n '2,16p' "$0"
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

# Install a cask unless it is already installed, then verify.
install_cask() {
  local cask="$1"
  if ! $DRY_RUN && brew list --cask "$cask" >/dev/null 2>&1; then
    ok "$cask is already installed"
    return 0
  fi
  if $DRY_RUN; then
    echo "[DRY-RUN] would run:"
  fi
  run env HOMEBREW_NO_AUTO_UPDATE=1 brew install --cask "$cask"
  if ! $DRY_RUN; then
    brew list --cask "$cask" >/dev/null 2>&1 || { fail "$cask did not install"; return 1; }
    ok "$cask installed"
  else
    ok "[DRY-RUN] skipping verify"
  fi
}

# Launch an app and wait while the person finishes its first-run prompts.
# Dry-run does not call read.
first_launch() {
  local app="$1"
  shift
  if $DRY_RUN; then
    echo "[DRY-RUN] would run: open -a \"$app\""
    echo "[DRY-RUN] would wait until the first-run prompts are done"
    return 0
  fi
  open -a "$app" || warn "could not open $app; open it from /Applications"
  echo
  local line
  for line in "$@"; do echo "  - $line"; done
  echo
  read -r -p "Press Enter when $app is set up... "
}

# ---------- Pre-flight ----------
preflight() {
  step "Pre-flight checks"
  if ! command -v brew >/dev/null 2>&1; then
    fail "brew not found; run the playbook's brew role first"
    exit 1
  fi
  ok "brew found"
  warn "Homebrew will ask for your macOS password during these installs"
  echo
}

# ---------- Steps (one function each) ----------
step_1_dotnet_sdk() {
  step "Step 1: Install the .NET SDK"
  install_cask dotnet-sdk
  if ! $DRY_RUN; then
    if /usr/local/share/dotnet/dotnet --version >/dev/null 2>&1; then
      ok "dotnet $(/usr/local/share/dotnet/dotnet --version)"
    else
      warn "dotnet did not answer; open a new shell and run: dotnet --version"
    fi
  fi
  ok "Step 1 done"
  echo
}

step_2_teamviewer() {
  step "Step 2: Install TeamViewer"
  install_cask teamviewer
  first_launch "TeamViewer" \
    "Accept the license agreement" \
    "System Settings > Privacy & Security: allow TeamViewer under Screen Recording and Accessibility"
  ok "Step 2 done"
  echo
}

step_3_adobe_acrobat_reader() {
  step "Step 3: Install Adobe Acrobat Reader"
  install_cask adobe-acrobat-reader
  ok "Step 3 done"
  echo
}

step_4_obs() {
  step "Step 4: Install OBS"
  install_cask obs
  first_launch "OBS" \
    "System Settings > Privacy & Security: allow OBS under Screen Recording, Camera, and Microphone"
  ok "Step 4 done"
  echo
}

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
    echo "Next: rerun ansible-playbook playbook.yml; the Brewfile step will"
    echo "report these casks as already installed."
  fi
  echo "============================================================="
}

# ---------- Main ----------
main() {
  echo "============================================================="
  echo "install-remaining-sudo-casks — .NET SDK, TeamViewer, Acrobat Reader, OBS"
  echo "============================================================="
  echo "Mode:        $([ "$DRY_RUN" = true ] && echo 'DRY-RUN' || echo 'LIVE')"
  echo "Steps:       $FROM_STEP → $TO_STEP"
  echo "============================================================="
  echo

  preflight

  [ "$FROM_STEP" -le 1 ] && [ "$TO_STEP" -ge 1 ] && step_1_dotnet_sdk
  [ "$FROM_STEP" -le 2 ] && [ "$TO_STEP" -ge 2 ] && step_2_teamviewer
  [ "$FROM_STEP" -le 3 ] && [ "$TO_STEP" -ge 3 ] && step_3_adobe_acrobat_reader
  [ "$FROM_STEP" -le 4 ] && [ "$TO_STEP" -ge 4 ] && step_4_obs

  print_summary
}

main "$@"
