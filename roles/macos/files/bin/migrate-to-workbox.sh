#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────
# Migrate Mac dev environment to siig-workbox
# Run from Mac. Requires: rsync, ssh access to workbox.
#
# What this does:
#   1. Syncs ~/Code, ~/siig, ~/cloudsim to workbox
#   2. Syncs ~/.claude (conversations, settings, skills)
#   3. Syncs ~/.claude-tmux config
#   4. Syncs ~/.zcustom (secrets)
#   5. Syncs ~/config (including uncommitted changes)
#   6. Renames Claude project dirs for Linux path compatibility
#   7. Builds claude-tmux on the workbox
#   8. Recreates tmux session structure
# ─────────────────────────────────────────────────────────────

SSH_TARGET="workbox"

step() { echo ""; echo "=== $1 ==="; }

# ── Phase 1: Sync directories ──

step "Syncing ~/Code ($(du -sh ~/Code 2>/dev/null | cut -f1))"
rsync -az --progress \
  --exclude '.DS_Store' \
  --exclude 'node_modules' \
  --exclude 'target/debug' \
  --exclude 'target/release' \
  --exclude 'bin/Debug' \
  --exclude 'bin/Release' \
  --exclude 'obj/' \
  --exclude '.git/objects/pack/*.tmp' \
  ~/Code/ "${SSH_TARGET}:~/Code/"

step "Syncing ~/siig ($(du -sh ~/siig 2>/dev/null | cut -f1))"
rsync -az --progress --exclude '.DS_Store' \
  ~/siig/ "${SSH_TARGET}:~/siig/"

step "Syncing ~/cloudsim ($(du -sh ~/cloudsim 2>/dev/null | cut -f1))"
rsync -az --progress --exclude '.DS_Store' --exclude 'node_modules' \
  ~/cloudsim/ "${SSH_TARGET}:~/cloudsim/"

step "Syncing ~/config (including uncommitted changes)"
rsync -az --progress --exclude '.DS_Store' \
  ~/config/ "${SSH_TARGET}:~/config/"

# ── Phase 2: Claude data ──

step "Syncing ~/.claude (conversations, settings, skills)"
rsync -az --progress \
  --exclude '.DS_Store' \
  --exclude 'cache/' \
  --exclude 'plugins/' \
  ~/.claude/ "${SSH_TARGET}:~/.claude/"

step "Syncing ~/.claude-tmux"
rsync -az --progress \
  ~/.claude-tmux/ "${SSH_TARGET}:~/.claude-tmux/"

# ── Phase 3: Secrets & config ──

step "Syncing ~/.zcustom"
rsync -az ~/.zcustom "${SSH_TARGET}:~/.zcustom"

# ── Phase 4: Rename Claude project dirs for Linux paths ──

step "Renaming Claude project directories (-Users-kaspersiig- → -home-kaspersiig-)"
ssh "${SSH_TARGET}" 'cd ~/.claude/projects && for dir in -Users-kaspersiig-*; do
  [ -e "$dir" ] || continue
  newname=$(echo "$dir" | sed "s/-Users-kaspersiig-/-home-kaspersiig-/")
  if [ ! -e "$newname" ]; then
    mv -- "$dir" "$newname"
    echo "  renamed: $dir → $newname"
  else
    echo "  skipped (already exists): $newname"
  fi
done'

# ── Phase 5: Build claude-tmux ──

step "Building claude-tmux on workbox"
ssh "${SSH_TARGET}" 'source ~/.cargo/env && cd ~/Code/claude-tmux && cargo build --release 2>&1 | tail -3 && cp target/release/claude-tmux ~/bin/claude-tmux && echo "claude-tmux installed to ~/bin/"'

# ── Phase 6: Recreate tmux sessions ──

step "Recreating tmux session structure"
ssh "${SSH_TARGET}" 'HOME_DIR="/home/kaspersiig"

create_session() {
  local name="$1" cwd="$2"
  cwd=$(echo "$cwd" | sed "s|/Users/kaspersiig|${HOME_DIR}|")
  [ -d "$cwd" ] || cwd="${HOME_DIR}"
  tmux new-session -d -s "$name" -c "$cwd" 2>/dev/null || true
}

add_window() {
  local session="$1" name="$2" cwd="$3"
  cwd=$(echo "$cwd" | sed "s|/Users/kaspersiig|${HOME_DIR}|")
  [ -d "$cwd" ] || cwd="${HOME_DIR}"
  tmux new-window -t "$session" -n "$name" -c "$cwd" 2>/dev/null || true
}

split_pane() {
  local target="$1" cwd="$2"
  cwd=$(echo "$cwd" | sed "s|/Users/kaspersiig|${HOME_DIR}|")
  [ -d "$cwd" ] || cwd="${HOME_DIR}"
  tmux split-window -t "$target" -c "$cwd" 2>/dev/null || true
}

# Kill default session if it exists
tmux kill-session -t 0 2>/dev/null || true

create_session "ADHOC-M0-VEL-423" "/home/kaspersiig/Code/velatir-coordination"
add_window "ADHOC-M0-VEL-423" "zsh" "/home/kaspersiig/Code/workspaces/adhoc-m0-vel-423/velatir-infrastructure"

create_session "ADHOC-orc" "/home/kaspersiig/Code/velatir-coordination"

create_session "SD-M2-VEL-869" "/home/kaspersiig/Code/velatir-coordination"

create_session "SD-M2-VEL-870-scrape" "/home/kaspersiig/Code/velatir-infrastructure"
split_pane "SD-M2-VEL-870-scrape:1" "/home/kaspersiig/Code/toolify-scraper-poc/data"
add_window "SD-M2-VEL-870-scrape" "zsh" "/home/kaspersiig/Code/toolify-scraper-poc/data"

create_session "SD-M2a-orc" "/home/kaspersiig/Code/velatir-coordination"
add_window "SD-M2a-orc" "zsh" "/home/kaspersiig/Code/velatir-coordination"

create_session "SD-M3-orc" "/home/kaspersiig/Code/velatir-coordination"
add_window "SD-M3-orc" "zsh" "/home/kaspersiig/Code/velatir-coordination"

create_session "claude-memory" "/home/kaspersiig/Code/velatir-coordination"
add_window "claude-memory" "claude" "/home/kaspersiig/Code/velatir-coordination"

create_session "claude-memory-cozempic" "/home/kaspersiig/Code/velatir-coordination"

create_session "cloudsim-ga4" "/home/kaspersiig/cloudsim/cloudsim-coordination"
add_window "cloudsim-ga4" "zsh" "/home/kaspersiig/cloudsim/cloudsim-coordination"
add_window "cloudsim-ga4" "zsh" "/home/kaspersiig/cloudsim/cloudsim-coordination"

create_session "siig-etilbudsavis" "/home/kaspersiig/Code/velatir-coordination"
add_window "siig-etilbudsavis" "zsh" "/home/kaspersiig/Code/velatir-coordination"
add_window "siig-etilbudsavis" "zsh" "/home/kaspersiig/Code/velatir-coordination"

create_session "skills" "/home/kaspersiig/Code/velatir-coordination"

create_session "skills-flush" "/home/kaspersiig/Code/velatir-coordination"
add_window "skills-flush" "zsh" "/home/kaspersiig/Code/velatir-coordination"

create_session "tool-obsidian" "/home/kaspersiig/Code/velatir-coordination"
add_window "tool-obsidian" "zsh" "/home/kaspersiig/Code/velatir-coordination"

create_session "tool-release-please" "/home/kaspersiig/Code/velatir-coordination"

create_session "tool-yanta" "/home/kaspersiig/Code/velatir-coordination"
add_window "tool-yanta" "zsh" "/home/kaspersiig/Code/velatir-coordination"

echo "Created $(tmux list-sessions | wc -l) tmux sessions"
tmux list-sessions
'

step "Migration complete!"
echo ""
echo "Next steps:"
echo "  1. ssh ${SSH_TARGET}"
echo "  2. claude login"
echo "  3. Install mutagen on Mac: brew install mutagen-io/mutagen/mutagen"
echo "  4. Set up Obsidian sync (see below)"
echo ""
echo "Mutagen bidirectional sync (run from Mac):"
echo "  mutagen sync create ~/Code/ai ${SSH_TARGET}:~/Code/ai \\"
echo "    --name obsidian-sync \\"
echo "    --sync-mode two-way-resolved \\"
echo "    --ignore '.DS_Store'"
