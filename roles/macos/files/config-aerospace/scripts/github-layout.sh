#!/usr/bin/env bash
# Arrange the GitHub web app windows (Edge PWA, Safari web app) in workspace 5:
#   left column  = the two oldest GitHub windows, stacked (pull requests, issues)
#   right column = every other window, as a vertical accordion
# The PWA hides window titles from AeroSpace, so "oldest" (lowest window id) is
# how the two pinned windows are recognised. Open them first.
PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
ws=5

sleep 0.3 # let on-window-detected finish moving the new window here

ids=($(aerospace list-windows --workspace "$ws" --format '%{window-id}|%{app-name}' | awk -F'|' '$2 == "GitHub" {print $1}' | sort -n))
(( ${#ids[@]} >= 2 )) || exit 0
pr=${ids[0]} issues=${ids[1]} others=("${ids[@]:2}")

to_right_edge() {
    for _ in {1..20}; do
        aerospace move --window-id "$1" --boundaries workspace --boundaries-action fail right 2>/dev/null || break
    done
}

aerospace flatten-workspace-tree --workspace "$ws"
aerospace layout --window-id "$pr" h_tiles
for id in "${ids[@]}"; do to_right_edge "$id"; done # order = oldest first
aerospace join-with --window-id "$issues" left
aerospace layout --window-id "$pr" v_tiles

if (( ${#others[@]} >= 2 )); then
    aerospace join-with --window-id "${others[1]}" left
    for id in "${others[@]:2}"; do
        aerospace move --window-id "$id" left
    done
    aerospace layout --window-id "${others[0]}" v_accordion
fi

aerospace balance-sizes --workspace "$ws"
