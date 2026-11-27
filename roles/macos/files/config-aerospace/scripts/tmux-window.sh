#!/usr/bin/env bash
# F13 c <N>: select tmux window N in the session of the most recently active client
tmux=/opt/homebrew/bin/tmux
client=$($tmux list-clients -F '#{client_activity} #{client_name}' | sort -rn | head -1 | cut -d' ' -f2)
[ -n "$client" ] || exit 0
session=$($tmux display-message -p -c "$client" '#{client_session}')
$tmux select-window -t "$session:=$1"
