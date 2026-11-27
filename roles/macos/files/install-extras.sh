#!/usr/bin/env bash
# Tools outside the package manager. Failures are printed and collected;
# brew bundle (Apple silicon) or port install (Intel) already ran.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
export PATH="/opt/homebrew/bin:/opt/local/bin:/usr/local/bin:${HOME}/.pyenv/bin:${HOME}/.cargo/bin:${HOME}/.local/bin:${PATH}"
# Release assets are named per CPU: arm64 on Apple silicon, amd64 on Intel.
case "$(uname -m)" in
  arm64) arch=arm64 ;;
  *) arch=amd64 ;;
esac
mkdir -p "${HOME}/.local/bin" "${HOME}/Code"
warnings=()

note() { warnings+=("$1"); echo "WARN: $1" >&2; }

if ! npm install -g \
  pnpm@11.6.0 \
  @earendil-works/pi-coding-agent@1.3.0
then
  note "npm global packages failed"
fi

pipx install --force cairosvg || note "pipx cairosvg failed"
pipx install --force frogmouth || note "pipx frogmouth failed"
pipx install --force "git+https://github.com/googleanalytics/google-analytics-mcp.git" \
  || note "pipx analytics-mcp failed"

uv tool install --force --python 3.12 "crawl4ai==0.9.2" || note "uv tool crawl4ai failed"

if ! command -v rustup >/dev/null 2>&1; then
  rustup-init -y --no-modify-path --default-toolchain stable || note "rustup-init failed"
fi
# shellcheck disable=SC1091
[ -f "${HOME}/.cargo/env" ] && . "${HOME}/.cargo/env"
rustup default stable || note "rustup default stable failed"

# MacPorts has no pyenv port, so Intel Macs get it from its git repository.
if ! command -v pyenv >/dev/null 2>&1 && [ ! -d "${HOME}/.pyenv" ]; then
  git clone --depth 1 https://github.com/pyenv/pyenv.git "${HOME}/.pyenv" \
    || note "pyenv clone failed"
fi
if ! command -v pyenv >/dev/null 2>&1 || ! pyenv versions --bare | grep -qx '3.12.0'; then
  pyenv install -s 3.12.0 || note "pyenv install 3.12.0 failed"
fi

if ! command -v plannotator >/dev/null 2>&1; then
  curl -fsSL https://plannotator.ai/install.sh | bash -s -- --minimal --version v0.25.1 \
    || note "plannotator installer failed"
fi

if ! command -v cc-clip >/dev/null 2>&1; then
  tmp=$(mktemp -d)
  if curl -fsSL -o "${tmp}/cc-clip.tgz" \
    https://github.com/ShunmeiCho/cc-clip/releases/latest/download/cc-clip_0.13.1_darwin_${arch}.tar.gz \
    && tar -xzf "${tmp}/cc-clip.tgz" -C "${tmp}" \
    && install -m 755 "${tmp}/cc-clip" "${HOME}/.local/bin/cc-clip"
  then
    :
  else
    note "cc-clip download failed (asset name is pinned to 0.13.1)"
  fi
  rm -rf "${tmp}"
fi

# Homebrew taps cover cymbal on Apple silicon; MacPorts has no port for it.
if ! command -v cymbal >/dev/null 2>&1; then
  case "${arch}" in amd64) cymbal_arch=x86_64 ;; *) cymbal_arch=arm64 ;; esac
  tmp=$(mktemp -d)
  if curl -fsSL -o "${tmp}/cymbal.tgz" \
    "https://github.com/1broseidon/cymbal/releases/download/v0.18.0/cymbal_v0.18.0_darwin_${cymbal_arch}.tar.gz" \
    && tar -xzf "${tmp}/cymbal.tgz" -C "${tmp}" \
    && install -m 755 "${tmp}/cymbal" "${HOME}/.local/bin/cymbal"
  then
    :
  else
    note "cymbal download failed (asset name is pinned to 0.18.0)"
  fi
  rm -rf "${tmp}"
fi

# Speech server for the Claude Code voice hook (claude/hooks/speak.py). MLX
# needs Apple silicon; Intel Macs speak with the system `say` instead.
if [ "${arch}" = arm64 ] && [ ! -x "${HOME}/.tts-env/bin/mlx_audio.server" ]; then
  if uv venv --python 3.12 "${HOME}/.tts-env" \
    && uv pip install --python "${HOME}/.tts-env/bin/python" \
      "mlx-audio==0.6.7" fastapi uvicorn python-multipart
  then
    :
  else
    note "mlx-audio speech server install failed"
  fi
fi

# STE100 checker skill, linked into ~/.agents/skills by link-config.sh
if [ ! -d "${HOME}/Code/asd-ste100-checker" ]; then
  git clone https://github.com/sourdough-bread/asd-ste100-checker.git "${HOME}/Code/asd-ste100-checker" \
    || note "asd-ste100-checker clone failed"
fi

git lfs install --skip-repo || note "git lfs install failed"

if ! command -v swiftly >/dev/null 2>&1 && [ ! -x "${HOME}/.swiftly/bin/swiftly" ]; then
  if curl -fsSL -o /tmp/swiftly.pkg https://download.swift.org/swiftly/darwin/swiftly.pkg \
    && installer -pkg /tmp/swiftly.pkg -target CurrentUserHomeDirectory
  then
    swiftbin=""
    for candidate in "${HOME}/.swiftly/bin/swiftly" "${HOME}/local/bin/swiftly"; do
      if [ -x "${candidate}" ]; then swiftbin="${candidate}"; break; fi
    done
    if [ -n "${swiftbin}" ]; then
      "${swiftbin}" init --assume-yes --skip-install || note "swiftly init failed"
    else
      note "swiftly pkg installed but the binary was not found"
    fi
  else
    note "swiftly pkg install failed"
  fi
fi

codebin="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
if [ -x "${codebin}" ]; then
  while IFS= read -r ext; do
    [ -z "${ext}" ] && continue
    "${codebin}" --install-extension "${ext}" || note "vscode extension ${ext} failed"
  done < "${HERE}/vscode-extensions.txt"
else
  note "VS Code CLI missing; extensions not installed"
fi

if [ "${#warnings[@]}" -gt 0 ]; then
  echo "install-extras finished with ${#warnings[@]} warning(s)" >&2
else
  echo "install-extras finished"
fi
