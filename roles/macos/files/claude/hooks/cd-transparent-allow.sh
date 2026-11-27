#!/usr/bin/env bash
# PreToolUse hook: make `cd <project-dir>` transparent for permission checks.
#
# When a Bash command starts with `cd` into a project directory followed by
# chained commands (&&), this hook checks whether every subsequent subcommand
# matches a whitelisted prefix. If all match, the command is allowed without
# a permission prompt.
#
# Allowed prefixes are maintained in the ALLOWED_PREFIXES array below.
# Add new entries as needed.

set -euo pipefail

ALLOWED_DIR_PATTERN="^cd ${HOME}/Code/[^ ]+ && "

ALLOWED_PREFIXES=(
  "git "
  "gh "
  "make "
  "ls "
  "ls$"
  "pwd"
  "echo "
  "cat "
  "dotnet "
  "npm "
  "terraform "
)

cmd=$(jq -r '.tool_input.command')

# Only process commands that start with cd to a project directory
if ! [[ "$cmd" =~ $ALLOWED_DIR_PATTERN ]]; then
  exit 0
fi

# Strip the leading `cd <dir> && ` to get the remaining commands
remainder="${cmd#*Code/}"
remainder="${remainder#* && }"

# Split on ' && ' and check each subcommand
while IFS= read -r subcmd; do
  [ -z "$subcmd" ] && continue
  # Trim leading/trailing whitespace
  subcmd="${subcmd#"${subcmd%%[![:space:]]*}"}"
  subcmd="${subcmd%"${subcmd##*[![:space:]]}"}"

  matched=false
  for prefix in "${ALLOWED_PREFIXES[@]}"; do
    if [[ "$subcmd" =~ $prefix ]]; then
      matched=true
      break
    fi
  done

  if [ "$matched" = false ]; then
    # Unrecognized subcommand — fall through to normal permission check
    exit 0
  fi
done <<< "$(echo "$remainder" | awk -v RS=' && ' '{print}')"

printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"cd to project dir + all subcommands whitelisted"}}\n'
