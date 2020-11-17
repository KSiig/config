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

# Alias - Docker
alias docker='sudo docker'
alias docker-compose='sudo docker-compose'
alias dcp='docker-compose'
alias dud='docker-compose down && docker-compose up'
alias dcp_service_name="cat docker-compose.yml | yq .services | jq -r 'keys[] as \$k | \"\(\$k)\"'"
alias dex='docker-compose exec $(dcp_service_name) bash'
alias dux='dud && dex'

# Alias - Git
alias gu='git fetch origin $1 && git pull origin $1'

# Only enable things if the needed commands exist
if hash brew &> /dev/null 
then
  alias ctags="`brew --prefix`/bin/ctags"
fi

if hash kubectl &> /dev/null 
then
  alias helm='sudo helm'
  alias kw='watch -n 0.5 "kubectl config current-context; echo ''; kubectl config view | grep namespace; echo ''; 
            kubectl get namespace,node,ingress,pod,svc,job,cronjob,deployment,rs,pv,pvc,secret,ep -o wide"'
fi

if hash tmux &> /dev/null 
then
  alias tmux='tmux -f $HOME/.tmux.conf'
  alias tmuxs='tmux-session save'
  alias tmuxr='tmux-session restore'
fi
