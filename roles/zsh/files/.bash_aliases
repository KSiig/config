# Alias - File navigation
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."
alias ......="cd ../../../../.."
alias l='ls -l'
alias ll='ls -la'

# Alias - Utilities
alias weather='curl wttr.in'
alias showip='curl ifconfig.io'
alias watch='watch -n 0.5 '
alias sb='source ~/.bash_aliases'

# Alias - Docker
export DCP_FILENAME='docker-compose.yml'
#alias docker='sudo docker'
#alias docker-compose='sudo docker-compose -f $DCP_FILENAME'
alias dcp_service_name="cat $DCP_FILENAME | yq -r .services | jq -r 'keys[] as \$k | \"\(\$k)\"'"
alias dcp='docker-compose'
alias ddown='docker stop $(cat $DCP_FILENAME | yq -r .services.$(dcp_service_name).container_name) && docker rm $(cat $DCP_FILENAME | yq -r .services.$(dcp_service_name).container_name)'
alias dud='(ddown || docker-compose down) && docker-compose up'
alias dex='docker-compose exec $(dcp_service_name) bash'
alias dux='dud -d && dex'

# Alias - Morningscore

alias mssvcup='cd $MS_ENV_DIR && ./bin/up'
alias mssvcdown='cd $MS_ENV_DIR && ./bin/down'
alias mssvccup='cd $MS_ENV_DIR && ./bin/up && ./bin/up-crawler'
alias mssvcrs='cd $MS_ENV_DIR && ./bin/restart'
alias mssvcrb='cd $MS_ENV_DIR && ./bin/down && ./bin/up'
alias mssvccrb='cd $MS_ENV_DIR && ./bin/down && ./bin/up && ./bin/up-crawler'
alias mslogsc='cd $MS_ENV_DIR && ./bin/logs-crawler'
alias mscsta='cd $MS_ENV_DIR && node ../../services/tester/onsite/crawl-start.js'
alias mscsto='cd $MS_ENV_DIR && node ../../services/tester/onsite/crawl-stop.js'
alias mssshgitlab='_ cp ~/.ssh/gitlab ~/.ssh/id_rsa && _ cp ~/.ssh/gitlab.pub ~/.ssh/id_rsa.pub'
alias mssshksi='_ cp ~/.ssh/id_rsa.bak ~/.ssh/id_rsa && _ cp ~/.ssh/id_rsa.pub.bak ~/.ssh/id_rsa.pub'

# Alias - Git
alias gu='git fetch origin $1 && git pull origin $1'

# Open URL with the platform's default opener (wslview on WSL, open on macOS, xdg-open on Linux)
function _open_url {
  if command -v wslview >/dev/null 2>&1; then
    wslview "$1"
  elif command -v open >/dev/null 2>&1; then
    open "$1"
  elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$1"
  else
    echo "No URL opener found: $1"
  fi
}

function gro {
  ORIGIN_URL=$(git remote get-url --push origin)
  if [[ "$ORIGIN_URL" == *"visualstudio"* || "$ORIGIN_URL" == *"azure"* ]]; then
    SUFFIX=$(echo $ORIGIN_URL | sed 's/^[^\/]*\///g')
    URL_PT1=$(echo $SUFFIX | sed 's![^/]*$!!')
    URL_PT2=$(echo $SUFFIX | sed 's@.*/@@')
    URL="https://dev.azure.com/${URL_PT1}_git/$URL_PT2"
    _open_url "$URL"
  elif [[ "$ORIGIN_URL" == *"git@github"* ]]; then
    REPO_URL=$(echo $ORIGIN_URL | sed 's@.*:@@')
    URL="https://github.com/$REPO_URL"
    _open_url "$URL"
  else
    echo "Unknown origin"
  fi
}


# Only enable things if the needed commands exist
if hash brew &> /dev/null 
then
    alias ctags="`brew --prefix`/bin/ctags"
fi

if hash kubectl &> /dev/null 
then
    alias helm='sudo helm'
fi

if hash tmux &> /dev/null
then
    alias tmux='tmux -f $HOME/.tmux.conf'
    alias tmuxs='tmux-session save'
    alias tmuxr='tmux-session restore'

    # Override oh-my-zsh tmux plugin's ts/ta to track the active session
    # in the tmux server env. VS Code "Claude: Pin selection" keybinding
    # reads CLAUDE_TMUX_TARGET via `tmux show-env -g` to know which pane
    # to send `@file#start-end` references to.
    ts() {
      local name="$1"
      if [[ -z "$name" || "${name:0:1}" == '-' ]]; then
        tmux new-session "$@"
        return
      fi
      if tmux has-session -t "$name" 2>/dev/null; then
        print -u2 "duplicate session: $name"
        return 1
      fi
      tmux new-session -d -s "$name"
      tmux setenv -g CLAUDE_TMUX_TARGET "$name"
      tmux attach -t "$name"
    }

    ta() {
      local name="$1"
      if [[ -z "$name" || "${name:0:1}" == '-' ]]; then
        tmux attach "$@"
        return
      fi
      tmux setenv -g CLAUDE_TMUX_TARGET "$name" 2>/dev/null
      tmux attach -t "$name"
    }
fi

if hash terraform &> /dev/null 
then
    alias tf='terraform'
fi

# Environment Variables
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin
export PATH=$PATH:/usr/local/go/bin

# Powerline
function _update_ps1() {
  PS1="$($GOPATH/bin/powerline-go -error $?)"
}
if [ "$TERM" != "linux"  ] && [ -f "$GOPATH/bin/powerline-go"  ]; then
  PROMPT_COMMAND="_update_ps1; $PROMPT_COMMAND"
fi

# CloudSim
alias flux_rec="flux reconcile source git flux-system -n flux-system && flux reconcile kustomization loki -n flux-system"
alias kx="k config current-context"
alias k3s_proxy="az connectedk8s proxy -n k3s -g cloudsim-aks"

# kubectl-watch the same resource as a previous `kubectl get`. Pass the last
# command via history expansion, e.g. `kw !!` after running `kgksall`. Accepts
# either an alias name (expanded to its definition) or a full command line.
kwch() {
  local cmd="$*"
  local def
  def=$(alias "$cmd" 2>/dev/null) && {
    cmd=${def#*=}   # drop the "alias name=" / "name=" prefix
    cmd=${cmd#\'}   # strip surrounding single quotes
    cmd=${cmd%\'}
  }
  cmd=${cmd/kubectl get/kubectl-watch}
  cmd=${cmd/#k get/kubectl-watch}
  eval "$cmd"
}

kubectx() {
  command kubectx "$@" && tmux refresh-client -S 2>/dev/null || true
}

kubens() {
  command kubens "$@" && tmux refresh-client -S 2>/dev/null || true
}

# Misc.
alias cdtmp="cd $(mktemp -d)"

if [[ -a $HOME/.bash_aliases.local ]]; then . $HOME/.bash_aliases.local; fi

