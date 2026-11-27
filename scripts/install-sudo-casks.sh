#!/usr/bin/env bash
# scripts/install-sudo-casks.sh
#
# Walks through installing the Brewfile casks that need sudo, so they
# cannot be installed from Ansible: docker-desktop, karabiner-elements,
# protonvpn.
#
# Usage:
#   scripts/install-sudo-casks.sh --dry-run        # print every command; run nothing
#   scripts/install-sudo-casks.sh --live           # execute every step (default)
#   scripts/install-sudo-casks.sh --from-step=2    # start at step 2 (skip earlier)
#   scripts/install-sudo-casks.sh --to-step=2      # stop after step 2
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
step_1_docker_desktop() {
  step "Step 1: Install Docker Desktop"
  install_cask docker-desktop
  first_launch "Docker" \
    "Accept the Docker subscription agreement" \
    "Allow the privileged helper when macOS asks for your password" \
    "Sign in to Docker (optional)"
  if ! $DRY_RUN; then
    if docker info >/dev/null 2>&1; then
      ok "Docker engine is running"
    else
      warn "Docker engine is not up yet; it can take a minute after first launch"
    fi
  fi
  ok "Step 1 done"
  echo
}

step_2_karabiner_elements() {
  step "Step 2: Install Karabiner-Elements"
  install_cask karabiner-elements
  first_launch "Karabiner-Elements" \
    "System Settings > General > Login Items & Extensions > Driver Extensions: turn on Karabiner" \
    "System Settings > Privacy & Security > Input Monitoring: allow karabiner_grabber and karabiner_observer" \
    "Your rules load from ~/.config/karabiner/karabiner.json, already linked by link-config.sh"
  ok "Step 2 done"
  echo
}

step_3_protonvpn() {
  step "Step 3: Install Proton VPN"
  install_cask protonvpn
  first_launch "ProtonVPN" \
    "Sign in to your Proton account" \
    "Allow the VPN configuration when macOS asks"
  ok "Step 3 done"
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
    echo "report these three casks as already installed."
  fi
  echo "============================================================="
}

# ---------- Main ----------
main() {
  echo "============================================================="
  echo "install-sudo-casks — Docker Desktop, Karabiner-Elements, Proton VPN"
  echo "============================================================="
  echo "Mode:        $([ "$DRY_RUN" = true ] && echo 'DRY-RUN' || echo 'LIVE')"
  echo "Steps:       $FROM_STEP → $TO_STEP"
  echo "============================================================="
  echo

  preflight

  [ "$FROM_STEP" -le 1 ] && [ "$TO_STEP" -ge 1 ] && step_1_docker_desktop
  [ "$FROM_STEP" -le 2 ] && [ "$TO_STEP" -ge 2 ] && step_2_karabiner_elements
  [ "$FROM_STEP" -le 3 ] && [ "$TO_STEP" -ge 3 ] && step_3_protonvpn

  print_summary
}

main "$@"
