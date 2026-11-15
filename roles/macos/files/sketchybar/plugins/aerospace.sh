#!/usr/bin/env bash

if [ "$1" = "$FOCUSED_WORKSPACE" ]; then
    sketchybar --set "$NAME" label.color=0xffF74F4F
else
    sketchybar --set "$NAME" label.color=0xffCFC2B0
fi
