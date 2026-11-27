#!/usr/bin/env bash
# Arrange the Claude artifact windows (Edge PWA) in workspace 7:
#   left column   = the artifacts gallery (claude.ai/code/artifacts), pinned
#   middle column = the artifact being read
#   right column  = every other artifact, oldest first, as v_tiles so each title bar shows
# Usage: artifact-layout.sh [new]
#   new  -> the newest window becomes the middle one (on-window-detected)
#   none -> the focused window becomes the middle one (the swap key)
# AeroSpace can't read the PWA's window titles, so the gallery is found by asking
# Edge for each window's URL and matching it to a window id by its frame. If that
# fails, the oldest window is taken as the gallery.
PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
ws=7
app_id=com.microsoft.edgemac.app.fmpnliohjhemenmnlpbfagaolkdacoja
state="${TMPDIR:-/tmp}/aerospace-artifact-main"
gallery_pct=24 main_pct=44

sleep 0.3 # let on-window-detected finish moving the new window here

ids=($(aerospace list-windows --workspace "$ws" --app-bundle-id "$app_id" --format '%{window-id}' | sort -n))
(( ${#ids[@]} >= 2 )) || exit 0
has() { [[ " ${ids[*]} " == *" $1 "* ]]; }

aerospace flatten-workspace-tree --workspace "$ws"
sleep 0.2 # frames settle into plain tiles, one distinct frame per window

# Prints "<gallery window id> <width of its screen>"
read -r gallery screen_w < <(osascript -l JavaScript - "${ids[@]}" <<'EOF' 2>/dev/null
ObjC.import('CoreGraphics'); ObjC.import('AppKit');
function run(ids) {
  const cg = ObjC.deepUnwrap(ObjC.castRefToObject($.CGWindowListCopyWindowInfo($.kCGWindowListOptionAll, 0)))
    .filter(c => ids.includes(String(c.kCGWindowNumber)));
  const w = Application('Microsoft Edge').windows().find(w => w.activeTab.url().includes('claude.ai/code/artifacts'));
  if (!w) return '';
  const b = w.bounds();
  const m = cg.find(c => c.kCGWindowBounds.X === b.x && c.kCGWindowBounds.Y === b.y
                    && c.kCGWindowBounds.Width === b.width && c.kCGWindowBounds.Height === b.height);
  if (!m) return '';
  const ss = $.NSScreen.screens;
  for (let i = 0; i < ss.count; i++) {
    const f = ss.objectAtIndex(i).visibleFrame;
    if (b.x >= f.origin.x && b.x < f.origin.x + f.size.width) return `${m.kCGWindowNumber} ${f.size.width}`;
  }
  return `${m.kCGWindowNumber}`;
}
EOF
)
has "$gallery" || gallery=${ids[0]}
artifacts=()
for id in "${ids[@]}"; do [[ $id == "$gallery" ]] || artifacts+=("$id"); done

focused=$(aerospace list-windows --focused --format '%{window-id}' 2>/dev/null)
saved=$(cat "$state" 2>/dev/null)
if [[ $1 == new ]]; then main=${artifacts[${#artifacts[@]}-1]}
elif has "$focused" && [[ $focused != "$gallery" ]]; then main=$focused
elif has "$saved" && [[ $saved != "$gallery" ]]; then main=$saved
else main=${artifacts[${#artifacts[@]}-1]}
fi
echo "$main" >"$state"
others=()
for id in "${artifacts[@]}"; do [[ $id == "$main" ]] || others+=("$id"); done

to_right_edge() {
    for _ in {1..20}; do
        aerospace move --window-id "$1" --boundaries workspace --boundaries-action fail right 2>/dev/null || break
    done
}

aerospace layout --window-id "$gallery" h_tiles
for id in "$gallery" "$main" "${others[@]}"; do to_right_edge "$id"; done

if (( ${#others[@]} >= 2 )); then
    aerospace join-with --window-id "${others[1]}" left
    for id in "${others[@]:2}"; do
        aerospace move --window-id "$id" left
    done
    aerospace layout --window-id "${others[0]}" v_tiles
fi

aerospace balance-sizes --workspace "$ws"
if [[ -n $screen_w ]]; then
    # each resize takes from both neighbours, so size the middle one first
    (( ${#others[@]} )) && aerospace resize --window-id "$main" width $(( screen_w * main_pct / 100 ))
    aerospace resize --window-id "$gallery" width $(( screen_w * gallery_pct / 100 ))
fi
aerospace focus --window-id "$main"
