#!/bin/bash

PLAYER="termusic"
BAR_LEN=5

POS=$(playerctl -p "$PLAYER" metadata --format '{{ position }}' 2>/dev/null)
LEN=$(playerctl -p "$PLAYER" metadata mpris:length 2>/dev/null)

# se não tiver música
if [[ -z "$POS" || -z "$LEN" || "$LEN" -eq 0 ]]; then
  echo ""
  exit 0
fi

# POS vem em segundos (float)
# LEN vem em microssegundos (int)

PERCENT=$((POS * 100 / LEN))

FILLED=$((PERCENT * BAR_LEN / 100))
EMPTY=$((BAR_LEN - FILLED))

BAR="$(printf "%${FILLED}s" | tr ' ' '#')"
BAR+="$(printf "%${EMPTY}s" | tr ' ' '=')"

echo "[$BAR] $PERCENT%"
