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
link "${HERE}/sketchybar" "${HOME}/.config/sketchybar"
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

link "${HERE}/agents-skills" "${HOME}/.agents/skills"
# The claude role creates ~/.claude/skills as a directory. Point it at the same tree.
if [ -d "${HOME}/.claude/skills" ] && [ ! -L "${HOME}/.claude/skills" ]; then
  rm -rf "${HOME}/.claude/skills"
fi
mkdir -p "${HOME}/.claude"
ln -sfn "${HOME}/.agents/skills" "${HOME}/.claude/skills"

link "${HERE}/claude/settings.json" "${HOME}/.claude/settings.json"
link "${HERE}/claude/statusline.sh" "${HOME}/.claude/statusline.sh"
link "${HERE}/claude/statusline-command.sh" "${HOME}/.claude/statusline-command.sh"
link "${HERE}/claude/RTK.md" "${HOME}/.claude/RTK.md"
link "${HERE}/claude/handoff-prompt.md" "${HOME}/.claude/handoff-prompt.md"
for rule in "${HERE}/claude/rules/"*; do
  link "${rule}" "${HOME}/.claude/rules/$(basename "${rule}")"
done
for hook in "${HERE}/claude/hooks/"*; do
  link "${hook}" "${HOME}/.claude/hooks/$(basename "${hook}")"
done
link "${HERE}/claude/commands/cozempic.md" "${HOME}/.claude/commands/cozempic.md"
link "${HERE}/claude/shared/preferred-docs-structure.md" \
  "${HOME}/.claude/shared/preferred-docs-structure.md"

link "${HERE}/claude-tmux/settings.json" "${HOME}/.claude-tmux/settings.json"
link "${HERE}/claude-tmux/titles.json" "${HOME}/.claude-tmux/titles.json"
link "${HERE}/claude-tmux/hidden-groups.json" "${HOME}/.claude-tmux/hidden-groups.json"
link "${HERE}/claude-tmux/hooks/status.sh" "${HOME}/.claude-tmux/hooks/status.sh"

mkdir -p "${HOME}/Library/LaunchAgents"
uid=$(id -u)
for plist in "${HERE}/launchagents/"*.plist; do
  dest="${HOME}/Library/LaunchAgents/$(basename "${plist}")"
  copy_home "${plist}" "${dest}"
  launchctl bootout "gui/${uid}" "${dest}" 2>/dev/null || true
  launchctl bootstrap "gui/${uid}" "${dest}" || echo "WARN: could not load ${dest}" >&2
done

echo "config linked"
cat "${HERE}/MANUAL.txt"
