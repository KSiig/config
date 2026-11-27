#!/usr/bin/env bash
set -e

CONFIG_DIR="${HOME}/config"

install_linux() {
  sudo apt update
  sudo apt upgrade -y
  sudo apt install -y python3 git pipx
  pipx install ansible --include-deps
  pipx ensurepath
}

# Intel Macs use MacPorts (Homebrew no longer supports them). MacPorts has
# no unattended installer, so it must already be there.
install_macos_intel() {
  export PATH="/opt/local/bin:/opt/local/sbin:${PATH}"
  if ! command -v port >/dev/null 2>&1; then
    echo "Install MacPorts first: https://www.macports.org/install.php" >&2
    exit 1
  fi
  sudo port -N install git pipx
  pipx install ansible --include-deps
  pipx ensurepath
  export PATH="${HOME}/.local/bin:${PATH}"
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
    Darwin)
      if [[ "$(uname -m)" == "x86_64" ]]; then install_macos_intel; else install_macos; fi
      ;;
    Linux)  install_linux ;;
    *) echo "Unsupported OS: $(uname -s)" >&2; exit 1 ;;
  esac

  git clone https://github.com/KSiig/config "${CONFIG_DIR}"
fi

cd "${CONFIG_DIR}"
exec < /dev/tty
if [[ "$(uname -s)" == "Darwin" && "$(uname -m)" != "x86_64" ]]; then
  ansible-playbook playbook.yml
else
  ansible-playbook -K playbook.yml
fi
