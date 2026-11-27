#!/usr/bin/env bash
input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
EFFORT=$(echo "$input" | jq -r '.effort.level // empty')
FIVE_H=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
SEVEN_D=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
CYAN='\033[36m'
DIM='\033[2m'
RESET='\033[0m'

# --- Effort level ---
EFFORT_STR=""
if [ -n "$EFFORT" ]; then
  case "$EFFORT" in
    low)    EFFORT_STR="${DIM}⚡${RESET}" ;;
    medium) EFFORT_STR="⚡" ;;
    high)   EFFORT_STR="⚡⚡" ;;
    xhigh)  EFFORT_STR="⚡⚡⚡" ;;
    max)    EFFORT_STR="${YELLOW}⚡⚡⚡⚡${RESET}" ;;
    ultra)  EFFORT_STR="${RED}⚡⚡⚡⚡⚡${RESET}" ;;
  esac
fi

# --- Context bar ---
if [ "$PCT" -ge 90 ]; then BAR_COLOR="$RED"
elif [ "$PCT" -ge 70 ]; then BAR_COLOR="$YELLOW"
else BAR_COLOR="$GREEN"; fi

FILLED=$((PCT / 10)); EMPTY=$((10 - FILLED))
BAR=""
[ "$FILLED" -gt 0 ] && printf -v FILL "%${FILLED}s" && BAR="${FILL// /█}"
[ "$EMPTY" -gt 0 ] && printf -v PAD "%${EMPTY}s" && BAR="${BAR}${PAD// /░}"


# --- Rate limits ---
LIMITS=""
if [ -n "$FIVE_H" ]; then
  FH=$(printf '%.0f' "$FIVE_H")
  if [ "$FH" -ge 80 ]; then   LIMITS="${RED}5h:${FH}%${RESET}"
  elif [ "$FH" -ge 50 ]; then LIMITS="${YELLOW}5h:${FH}%${RESET}"
  else                         LIMITS="${GREEN}5h:${FH}%${RESET}"
  fi
fi
if [ -n "$SEVEN_D" ]; then
  SD=$(printf '%.0f' "$SEVEN_D")
  if [ "$SD" -ge 80 ]; then   LIMITS="${LIMITS:+$LIMITS }${RED}7d:${SD}%${RESET}"
  elif [ "$SD" -ge 50 ]; then LIMITS="${LIMITS:+$LIMITS }${YELLOW}7d:${SD}%${RESET}"
  else                         LIMITS="${LIMITS:+$LIMITS }${GREEN}7d:${SD}%${RESET}"
  fi
fi

# --- Single line: critter bar pct | model effort | rate limits ---
LINE="${BAR_COLOR}${BAR}${RESET} ${PCT}% | ${MODEL}"
[ -n "$EFFORT_STR" ] && LINE="${LINE} ${EFFORT_STR}"
[ -n "$LIMITS" ] && LINE="${LINE} | ${LIMITS}"

echo -e "$LINE"
