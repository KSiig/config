#
# Defines environment variables.
#
# Authors:
#   Sorin Ionescu <sorin.ionescu@gmail.com>
#

# Ensure that a non-login, non-interactive shell has a defined environment.
if [[ ( "$SHLVL" -eq 1 && ! -o LOGIN ) && -s "${ZDOTDIR:-$HOME}/.zprofile" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprofile"
fi
#export SPACESHIP_PROMPT_ORDER=(dir git docker venv pyenv kubecontext exec_time line_sep vi_mode exit_code char)
export SPACESHIP_PROMPT_ORDER=()
export SPACESHIP_USER_SHOW=always
