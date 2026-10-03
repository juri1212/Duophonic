#!/usr/bin/env bash
#
# Checks end to end that the running Duophonic app sends audio to both outputs.
#
# Setup:
#   brew install sox blackhole-2ch blackhole-16ch
#   In Duophonic, pick "BlackHole 2ch" and "BlackHole 16ch" as outputs and enable it.
#
# Usage: scripts/verify-routing.sh [--any-output]
#
# The script plays a test tone to the default output (the Duophonic aggregate while it is
# enabled) and records what BlackHole loops back from each device.

set -euo pipefail

DEVICES=("BlackHole 2ch" "BlackHole 16ch")
FREQUENCY=997
# The tone is played at 0.25 peak, so a sine arriving intact has an RMS of about 0.18.
MIN_RMS=0.05

command -v sox >/dev/null || { echo "sox is missing: brew install sox" >&2; exit 2; }

default_output=$(system_profiler SPAudioDataType 2>/dev/null \
  | awk '/^ {8}[^ ].*:$/ { name = $0 } /Default Output Device: Yes/ { sub(/^ +/, "", name); sub(/:$/, "", name); print name }')
echo "Default output: $default_output"
if [[ "$default_output" != *Duophonic* && "${1:-}" != "--any-output" ]]; then
  echo "Duophonic doesn't seem to be enabled. Enable it, or pass --any-output to test anyway." >&2
  exit 2
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

pids=()
for i in "${!DEVICES[@]}"; do
  # Skip the first half second, which overlaps with the tone starting up.
  sox -q -t coreaudio "${DEVICES[$i]}" -n remix 1 trim 0.5 1.5 stat 2>"$tmp/$i" &
  pids+=($!)
done
sleep 0.2
sox -q -n -t coreaudio default synth 2.5 sine "$FREQUENCY" vol 0.25
wait "${pids[@]}"

failed=0
silent=0
for i in "${!DEVICES[@]}"; do
  rms=$(awk '/RMS +amplitude/ { print $3 }' "$tmp/$i")
  frequency=$(awk '/Rough +frequency/ { print $3 }' "$tmp/$i")
  if awk -v rms="${rms:-0}" -v min="$MIN_RMS" 'BEGIN { exit !(rms >= min) }'; then
    printf '✔ %-15s RMS %s, ~%s Hz\n' "${DEVICES[$i]}" "$rms" "$frequency"
  else
    printf '✘ %-15s RMS %s, tone missing\n' "${DEVICES[$i]}" "${rms:-?}"
    failed=1
    [[ "${rms:-0}" == "0.000000" ]] && silent=$((silent + 1))
  fi
done

if ((silent == ${#DEVICES[@]})); then
  echo "Both recordings are digital silence. If your terminal has no microphone access, macOS" \
    "records silence: System Settings → Privacy & Security → Microphone." >&2
fi
exit "$failed"
