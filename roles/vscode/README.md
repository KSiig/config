VSCode
======

Symlinks user-config files into the VSCode user-settings directory for the
current host, and installs a list of extensions via the `code` CLI. Detection
is by platform:

- **macOS:** `~/Library/Application Support/Code/User/`
- **WSL on Windows host:** `/mnt/c/Users/{{ vscode_windows_user }}/AppData/Roaming/Code/User/`
- **anything else:** the role logs a skip and does nothing.

Symlinked files: `settings.json`, `keybindings.json`, `tasks.json`.

Variables
---------

- `vscode_windows_user` (default `kaspe`) — the Windows username under
  `/mnt/c/Users/`. Override per machine in `playbook.yml` or via `--extra-vars`.
- `vscode_user_dir` — if pre-set, detection is skipped and this path is used
  directly. Useful for tests.
- `vscode_extensions` — list of extension IDs to install via `code
  --install-extension`. Skipped silently if `code` isn't on PATH.

Pin-selection keybinding
------------------------

`Cmd+Alt+K` runs the "Claude: Pin selection" user task, which sends
`@<relativeFile>#<startLine>-<endLine> ` via `tmux send-keys` to the tmux pane
running `claude`. The target pane is read from the `CLAUDE_TMUX_TARGET`
tmux-server env var, which is set by the `ts`/`ta` wrappers in
`roles/zsh/files/.bash_aliases`.

Requirements:

- The `rioj7.command-variable` extension (auto-installed via `vscode_extensions`).
- `tmux` running and a session started via `ts <name>` or attached via `ta <name>`.

Notes
-----

On WSL the symlinks land on `/mnt/c` (DrvFs / NTFS). Windows VSCode follows
them as normal files. If you ever see "VSCode isn't picking up changes" after
editing the repo, re-run the playbook or check that Developer Mode / symlink
permissions are still enabled on Windows.

`force: true` is used when linking — any pre-existing non-symlink
`keybindings.json` or `tasks.json` in the VSCode user dir will be replaced.
