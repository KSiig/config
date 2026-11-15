Before pushing to any existing branch that had (or may have had) a PR:

1. Run `gh pr list --state all --head <branch-name>` to find the PR.
2. If a PR exists, check its state with `gh pr view <number> --json state`.
3. If the PR is **merged** or **closed**: do NOT push to that branch. Instead:
   - Pull latest main, create a fresh branch from main, and open a new PR.
4. If no PR exists or the PR is **open**: safe to push.

This check is mandatory every time — even if you just pushed to the branch minutes ago. PRs get merged between pushes.
