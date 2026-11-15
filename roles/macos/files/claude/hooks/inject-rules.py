#!/usr/bin/env python3
import json, sys, re, os
from fnmatch import fnmatch
from pathlib import Path

RULES_DIR = Path(__file__).resolve().parent.parent / "rules"

def load_rules():
    rules = []
    for rule_file in sorted(RULES_DIR.glob("*.md")):
        text = rule_file.read_text()
        parts = text.split("---", 2)
        if len(parts) < 3:
            continue
        frontmatter, body = parts[1], parts[2].strip()
        if not body:
            continue
        globs = re.findall(r'^\s*-\s*"(.+)"', frontmatter, re.MULTILINE)
        if globs:
            rules.append((globs, body))
    return rules

def matches(file_path, globs):
    for glob in globs:
        if fnmatch(file_path, glob):
            return True
    return False

def main():
    inp = json.load(sys.stdin)
    file_path = inp.get("tool_input", {}).get("file_path", "")
    if not file_path:
        return

    context_parts = []
    for globs, body in load_rules():
        if matches(file_path, globs):
            context_parts.append(body)

    if context_parts:
        json.dump({
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "allow",
                "additionalContext": "\n\n".join(context_parts),
            }
        }, sys.stdout)

if __name__ == "__main__":
    main()
