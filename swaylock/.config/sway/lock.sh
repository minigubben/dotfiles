#!/bin/sh

if command -v hyprlock >/dev/null 2>&1; then
  output="$(hyprlock 2>&1)"
  status=$?
  if [ "$status" -eq 0 ]; then
    exit 0
  fi

  logger -t swaylock-lock "hyprlock failed with exit status $status: $output"
fi

if swaylock --help 2>&1 | grep -q -- '--screenshots'; then
  output="$(swaylock -f \
    --screenshots \
    --clock \
    --indicator \
    --indicator-radius 100 \
    --indicator-thickness 7 \
    --effect-blur 22x12 \
    --effect-vignette 0.9:0.9 \
    --fade-in 0.2 \
    --ring-color bb00cc \
    --key-hl-color 880033 \
    --line-color 00000000 \
    --inside-color 00000088 \
    --separator-color 00000000 \
    --text-color ffffff 2>&1)"
  status=$?
  if [ "$status" -eq 0 ]; then
    exit 0
  fi

  logger -t swaylock-lock "swaylock-effects failed with exit status $status: $output"
fi

output="$(swaylock -f \
  --color 000000 \
  --indicator-radius 100 \
  --indicator-thickness 7 \
  --ring-color bb00cc \
  --key-hl-color 880033 \
  --line-color 00000000 \
  --inside-color 00000088 \
  --separator-color 00000000 \
  --text-color ffffff 2>&1)"
status=$?
if [ "$status" -eq 0 ]; then
  exit 0
fi

logger -t swaylock-lock "swaylock fallback failed with exit status $status: $output"
exit "$status"
