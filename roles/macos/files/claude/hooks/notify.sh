#!/usr/bin/env bash
# Claude Code Notification hook — emit BEL into the pane's tty so tmux flags
# the window. Verbose logging to ~/.claude/hooks/notify.log for debugging.

log_file="$HOME/.claude/hooks/notify.log"
log() { printf '%s\n' "$*" >> "$log_file" 2>/dev/null; }

log "---"
log "fired at $(date -Iseconds 2>/dev/null || date)"
log "TMUX=$TMUX"
log "TMUX_PANE=$TMUX_PANE"
log "PWD=$PWD"

if [ -n "$TMUX_PANE" ] && command -v tmux >/dev/null 2>&1; then
  pane_tty=$(tmux display-message -p -t "$TMUX_PANE" '#{pane_tty}' 2>&1)
  log "pane_tty='$pane_tty'"
  if [ -n "$pane_tty" ] && [ -e "$pane_tty" ]; then
    log "pane_tty perms: $(ls -l "$pane_tty" 2>&1)"
    if printf '\a' > "$pane_tty" 2>>"$log_file"; then
      log "wrote BEL to pane_tty OK"
      exit 0
    else
      log "wrote BEL to pane_tty FAILED (exit $?)"
    fi
  else
    log "pane_tty empty or does not exist"
  fi
fi

if printf '\a' > /dev/tty 2>>"$log_file"; then
  log "wrote BEL to /dev/tty OK"
else
  log "wrote BEL to /dev/tty FAILED (exit $?)"
fi
