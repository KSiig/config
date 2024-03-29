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
alias docker='sudo docker'
alias docker-compose='sudo docker-compose -f $DCP_FILENAME'
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
function gro {
  ORIGIN_URL=$(git remote get-url --push origin)
  if [[ "$ORIGIN_URL" == *"visualstudio"* || "$ORIGIN_URL" == *"azure"* ]]; then
    SUFFIX=$(echo $ORIGIN_URL | sed 's/^[^\/]*\///g')
    URL_PT1=$(echo $SUFFIX | sed 's![^/]*$!!')
    URL_PT2=$(echo $SUFFIX | sed 's@.*/@@')
    URL="https://dev.azure.com/${URL_PT1}_git/$URL_PT2"
    wslview $URL
  elif [[ "$ORIGIN_URL" == *"git@github"* ]]; then
    REPO_URL=$(echo $ORIGIN_URL | sed 's@.*:@@')
    URL="https://github.com/$REPO_URL"
    wslview $URL
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
    # alias helm='sudo helm'
    alias kw='watch -n 0.5 "kubectl config current-context; echo ''; kubectl config view | grep namespace; echo ''; 
                  kubectl get namespace,node,ingress,pod,svc,job,cronjob,deployment,rs,pv,pvc,secret,ep -o wide"'
fi

if hash tmux &> /dev/null 
then
    alias tmux='tmux -f $HOME/.tmux.conf'
    alias tmuxs='tmux-session save'
    alias tmuxr='tmux-session restore'
fi

if hash terraform &> /dev/null 
then
    alias tf='terraform'
fi

# Environment Variables
export PATH=$PATH:$GOPATH/bin

# Powerline
GOPATH=$HOME/go
function _update_ps1() {
  PS1="$($GOPATH/bin/powerline-go -error $?)"
}
if [ "$TERM" != "linux"  ] && [ -f "$GOPATH/bin/powerline-go"  ]; then
  PROMPT_COMMAND="_update_ps1; $PROMPT_COMMAND"
fi
