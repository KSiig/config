# Kasper Siig's Config

This repo contains everything needed to set up my terminal. Linux is the original target. The `macos-restore` branch also rebuilds the Mac.

# Motivation

I tend to work in many various shells. Whether it's because I'm changing PCs, or because I'm working inside a Docker container, I'm always missing that one command, or that one tool.

This project is meant to solve that, so I can always get my shell up'n'running like I'm used to. No matter where I am

# Built With

Here's a comprehensive list of the tools used in this project, and why they're used.

- Ansible - The core of everything. It takes care of setting up the terminal as it should be
- Molecule - Used to test the various roles
- Docker - Used as a driver for Molecule

# macOS restore (`macos-restore`)

The curl install script below clones `main`. That branch does not contain this restore. On a fresh Mac:

```bash
brew install ansible git
git clone -b macos-restore https://github.com/KSiig/config ~/config
cd ~/config
ansible-playbook playbook.yml
```

`ansible-playbook` will ask for a password for some casks. `openai-whisper` pulls PyTorch, so the Homebrew step takes a while. At the end the play prints `roles/macos/files/MANUAL.txt`.

The role installs the Homebrew bundle, CLIs that are not in Homebrew (npm globals, pipx, uv, rustup, Grok, Plannotator, cc-clip, Swiftly, claude-tmux), dotfiles, agent skills, VS Code extensions, and LaunchAgents.

Left out on purpose: WiFiMan, BlueStacks, Autodesk Fusion, Parsec, Raspberry Pi Imager, Google Drive, MiniMax Code, WireGuard.

This repo is public. These are not in git. Put them back before relying on the machine:

- `~/.creds`
- `~/.ssh/` (private keys and the config for `openclaw`, `pi`, and `workbox`)
- `gh auth login` (`~/.config/gh/hosts.yml` is not in git)
- `~/.kube/config`
- Claude login (`~/.claude/.credentials.json` is not in git)
- Grok login (`~/.grok/auth.json` and `mcp_credentials.json` are not in git)
- In `~/.creds`, export `TAILNET_MAGICDNS_SUFFIX` and `TAILSCALE_WORKBOX_IPV4`. The values were removed from `~/.zcustom` and are not stored here. Copy them off the old Mac before wiping.
- `LINEAR_API_KEY` in `~/Library/LaunchAgents/com.claude-tmux.daemon.plist`. The plist is installed without it. The old key lived in that plist in plaintext, so rotate it and put the new value in the plist.

Not installed from Homebrew:

- Xcode, from the App Store (`xcodes` and `mas` are installed)
- Amphetamine, from the App Store
- PDFgear, from the vendor
- Google Docs, Sheets, and Slides (no cask)
- MacPorts. `~/.zprofile` still adds `/opt/local/bin`. The old install could not list its ports.
- AeroSpace comes back as the stable cask. The old `aerospace-dev` cask pointed at a local build zip.

Sign in again to 1Password, Docker, gcloud, az, and the browser.

# Installation

## Install Script

You can install using the script found in the root of this project.

```bash
curl -fsSL https://raw.githubusercontent.com/KSiig/config/main/install.sh | bash
```

## Manual Install

First you need to install Ansible on your machine. This will depend on your OS. Once Ansible is installed, you can run the following.

```bash
git clone https://github.com/KSiig/config
cd config
ansible-playbook -K playbook.yml
```

# Testing

This project uses [Molecule](https://github.com/ansible-community/molecule) to test the roles. In order to test a role, simply go to the root folder of the role (i.e `./roles/tmux/`) and type the following.

```bash
molecule test
```

## Prerequisites

The following should be installed before you're able to run Molecule:

- Molecule | `pip3 install molecule`
- Molecule Docker driver | `pip3 install molecule-docker`
- Pytest | `pip3 install pytest`
