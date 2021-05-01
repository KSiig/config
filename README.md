# Kasper Siig's Config

This repo contains everything needed to set up my Terminal to be exactly how I like it. At the time this is only done for Linux, but at some point will be extended to PowerShell.

# Motivation

I tend to work in many various shells. Whether it's because I'm changing PCs, or because I'm working inside a Docker container, I'm always missing that one command, or that one tool.

This project is meant to solve that, so I can always get my shell up'n'running like I'm used to. No matter where I am

# Built With

Here's a comprehensive list of the tools used in this project, and why they're used.

- Ansible - The core of everything. It takes care of setting up the terminal as it should be
- Molecule - Used to test the various roles
- Docker - Used as a driver for Molecule

# Installation

## Install Script

You can install using the script found in the root of this project.

```bash
curl -fsSL https://raw.githubusercontent.com/KSiig/config/master/install.sh | bash
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
