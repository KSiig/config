Claude
======

Sets up `~/.claude/` on a new machine with the agents, skills, and output styles
maintained in this repo. Files under `files/` are symlinked into `~/.claude/`,
so editing in either place updates both and `git pull` propagates new entries.

Layout
------

    files/
      agents/             # individual agent files -> ~/.claude/agents/
      output-styles/      # individual style files -> ~/.claude/output-styles/
      skills/             # one directory per skill -> ~/.claude/skills/<name>

Adding a new agent or output style: drop the `.md` file into the matching
folder. Adding a new skill: create a directory under `files/skills/` containing
at least a `SKILL.md`.
