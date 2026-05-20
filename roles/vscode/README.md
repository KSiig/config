VSCode
======

Symlinks `files/settings.json` into the VSCode user-settings directory for the
current host. Detection is by platform:

- **macOS:** `~/Library/Application Support/Code/User/settings.json`
- **WSL on Windows host:** `/mnt/c/Users/{{ vscode_windows_user }}/AppData/Roaming/Code/User/settings.json`
- **anything else:** the role logs a skip and does nothing.

Variables
---------

- `vscode_windows_user` (default `kaspe`) — the Windows username under
  `/mnt/c/Users/`. Override per machine in `playbook.yml` or via `--extra-vars`.
- `vscode_user_dir` — if pre-set, detection is skipped and this path is used
  directly. Useful for tests.

Notes
-----

On WSL the symlink lands on `/mnt/c` (DrvFs / NTFS). Windows VSCode follows it
as a normal file. If you ever see "VSCode isn't picking up changes" after
editing the repo, re-run the playbook or check that Developer Mode / symlink
permissions are still enabled on Windows.
