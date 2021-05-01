if [[ ! -d ~/config ]]
then
  sudo apt update && \
  sudo apt upgrade -y && \
  sudo apt install -y python3 python3-pip ansible && \
  git clone https://github.com/KSiig/config ~/config && \
  cd ~/config && \
  ansible-playbook -K playbook.yml
fi
