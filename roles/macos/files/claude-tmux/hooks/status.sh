#!/bin/bash
[ -z "$TMUX_PANE" ] && exit 0
mkdir -p /tmp/claude-tmux-hooks
printf '%s %s\n' "$1" "$(date +%s)" > "/tmp/claude-tmux-hooks/$TMUX_PANE"
