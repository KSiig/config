#!/usr/bin/env bash
f=$(ls -t ~/workbox-files/ | head -1)
[ -n "$f" ] && realpath ~/workbox-files/"$f" | sed "s|$HOME|~|" | tr -d '\n' | pbcopy
