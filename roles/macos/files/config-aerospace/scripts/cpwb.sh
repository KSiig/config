#!/usr/bin/env bash
f=$(ls -t ~/working-files/ | head -1)
[ -n "$f" ] && realpath ~/working-files/"$f" | sed "s|$HOME|~|" | tr -d '\n' | pbcopy
