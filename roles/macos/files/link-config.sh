#!/usr/bin/env bash
# Symlink tracked config into the home directory. Real files only where launchd
# or a tool writes beside the file.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)

link() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "${dest}")"
  if [ -e "${dest}" ] && [ ! -L "${dest}" ]; then
    rm -rf "${dest}"
  fi
  ln -sfn "${src}" "${dest}"
}

copy_home() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "${dest}")"
  rm -f "${dest}"
  sed "s#__HOME__#${HOME}#g" "${src}" > "${dest}"
}

link "${HERE}/zcustom" "${HOME}/.zcustom"
link "${HERE}/gitconfig" "${HOME}/.gitconfig"
link "${HERE}/git/ignore" "${HOME}/.config/git/ignore"
link "${HERE}/gh/config.yml" "${HOME}/.config/gh/config.yml"
link "${HERE}/wakeup" "${HOME}/.wakeup"
link "${HERE}/ghostty/config" "${HOME}/.config/ghostty/config"
link "${HERE}/hammerspoon/init.lua" "${HOME}/.hammerspoon/init.lua"
link "${HERE}/aerospace" "${HOME}/.aerospace"
link "${HERE}/aerospace/.aerospace.toml" "${HOME}/.aerospace.toml"
link "${HERE}/config-aerospace" "${HOME}/.config/aerospace"
link "${HERE}/karabiner/karabiner.json" "${HOME}/.config/karabiner/karabiner.json"
link "${HERE}/karabiner/assets/complex_modifications/swap-delete.json" \
  "${HOME}/.config/karabiner/assets/complex_modifications/swap-delete.json"
link "${HERE}/karabiner/assets/complex_modifications/swap-tab.json" \
  "${HOME}/.config/karabiner/assets/complex_modifications/swap-tab.json"
link "${HERE}/tmuxy/tmuxy.conf" "${HOME}/.config/tmuxy/tmuxy.conf"
link "${HERE}/grok/config.toml" "${HOME}/.grok/config.toml"

mkdir -p "${HOME}/bin" "${HOME}/.local/bin"
for script in "${HERE}/bin/"*; do
  link "${script}" "${HOME}/bin/$(basename "${script}")"
done
for script in "${HERE}/local-bin/"*; do
  link "${script}" "${HOME}/.local/bin/$(basename "${script}")"
done

# ~/.agents/skills is a real folder: this repo's skills are linked in one by
# one, and skills installed by other tools (Claude desktop sync, skill
# installers) live there without landing in git.
skills="${HOME}/.agents/skills"
if [ -L "${skills}" ]; then
  rm "${skills}"
fi
mkdir -p "${skills}"
for skill in "${HERE}/agents-skills/"*/; do
  skill="${skill%/}"
  link "${skill}" "${skills}/$(basename "${skill}")"
done
# Drop links to skills that were removed from this repo.
for entry in "${skills}/"*; do
  if [ -L "${entry}" ] && [ ! -e "${entry}" ]; then
    rm "${entry}"
  fi
done
if [ -d "${HOME}/Code/asd-ste100-checker/skill" ]; then
  link "${HOME}/Code/asd-ste100-checker/skill" "${skills}/ste100-check"
fi
# The claude role creates ~/.claude/skills as a directory. Point it at the same tree.
if [ -d "${HOME}/.claude/skills" ] && [ ! -L "${HOME}/.claude/skills" ]; then
  rm -rf "${HOME}/.claude/skills"
fi
mkdir -p "${HOME}/.claude"
ln -sfn "${skills}" "${HOME}/.claude/skills"

copy_home "${HERE}/claude/settings.json" "${HOME}/.claude/settings.json"
link "${HERE}/claude/statusline.sh" "${HOME}/.claude/statusline.sh"
link "${HERE}/claude/statusline-command.sh" "${HOME}/.claude/statusline-command.sh"
link "${HERE}/claude/RTK.md" "${HOME}/.claude/RTK.md"
for rule in "${HERE}/claude/rules/"*; do
  link "${rule}" "${HOME}/.claude/rules/$(basename "${rule}")"
done
for hook in "${HERE}/claude/hooks/"*; do
  link "${hook}" "${HOME}/.claude/hooks/$(basename "${hook}")"
done
# Drop links to rules and hooks that were removed from this repo.
for entry in "${HOME}/.claude/rules/"* "${HOME}/.claude/hooks/"*; do
  if [ -L "${entry}" ] && [ ! -e "${entry}" ]; then
    rm "${entry}"
  fi
done
link "${HERE}/claude/commands/cozempic.md" "${HOME}/.claude/commands/cozempic.md"
link "${HERE}/claude/shared/preferred-docs-structure.md" \
  "${HOME}/.claude/shared/preferred-docs-structure.md"


# Private overlay: a separate private repo for files this public repo must not
# hold. Everything below is skipped when it is not cloned.
OVERLAY="${CONFIG_PRIVATE:-${HOME}/config-private}"
if [ -d "${OVERLAY}" ]; then
  for rule in "${OVERLAY}/claude/rules/"*; do
    [ -e "${rule}" ] && link "${rule}" "${HOME}/.claude/rules/$(basename "${rule}")"
  done
  [ -d "${OVERLAY}/agents/brands" ] && link "${OVERLAY}/agents/brands" "${HOME}/.agents/brands"
  [ -f "${OVERLAY}/zcustom.local" ] && link "${OVERLAY}/zcustom.local" "${HOME}/.zcustom.local"
  # File by file: ~/voices also holds recordings that are not in the overlay.
  for voice in "${OVERLAY}/voices/"*; do
    [ -e "${voice}" ] && link "${voice}" "${HOME}/voices/$(basename "${voice}")"
  done
  # Merge the overlay's settings into ~/.claude/settings.json: objects merge,
  # lists are appended.
  if [ -f "${OVERLAY}/claude/settings.overlay.json" ] && command -v jq >/dev/null 2>&1; then
    merged=$(mktemp)
    jq -s 'def m($a; $b): if ($a|type) == "object" and ($b|type) == "object"
             then reduce ($b|keys_unsorted[]) as $k ($a; .[$k] = m($a[$k]; $b[$k]))
           elif ($a|type) == "array" and ($b|type) == "array" then $a + $b
           else $b end;
           m(.[0]; .[1])' \
      "${HOME}/.claude/settings.json" "${OVERLAY}/claude/settings.overlay.json" > "${merged}"
    sed "s#__HOME__#${HOME}#g" "${merged}" > "${HOME}/.claude/settings.json"
    rm -f "${merged}"
  fi
fi

mkdir -p "${HOME}/Library/LaunchAgents"
uid=$(id -u)
for plist in "${HERE}/launchagents/"*.plist; do
  # The speech server runs on MLX, which needs Apple silicon.
  if [ "$(basename "${plist}")" = "com.user.mlx-audio.plist" ] && [ "$(uname -m)" != "arm64" ]; then
    continue
  fi
  dest="${HOME}/Library/LaunchAgents/$(basename "${plist}")"
  copy_home "${plist}" "${dest}"
  launchctl bootout "gui/${uid}" "${dest}" 2>/dev/null || true
  launchctl bootstrap "gui/${uid}" "${dest}" || echo "WARN: could not load ${dest}" >&2
done

echo "config linked"
cat "${HERE}/MANUAL.txt"
