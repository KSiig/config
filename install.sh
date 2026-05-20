#!/usr/bin/env bash
set -e

CONFIG_DIR="${HOME}/config"

install_linux() {
  sudo apt update
  sudo apt upgrade -y
  sudo apt install -y python3 python3-pip git
  pip3 install --user ansible
}

install_macos() {
  if ! command -v brew >/dev/null 2>&1; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
  brew install ansible git
}

if [[ ! -d "${CONFIG_DIR}" ]]; then
  case "$(uname -s)" in
    Darwin) install_macos ;;
    Linux)  install_linux ;;
    *) echo "Unsupported OS: $(uname -s)" >&2; exit 1 ;;
  esac

  git clone https://github.com/KSiig/config "${CONFIG_DIR}"
fi

cd "${CONFIG_DIR}"
if [[ "$(uname -s)" == "Darwin" ]]; then
  ansible-playbook playbook.yml
else
  ansible-playbook -K playbook.yml
fi
