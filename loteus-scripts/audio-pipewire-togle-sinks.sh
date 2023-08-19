#!/bin/bash
# Author: Jan Keith Darunday <github@jkcdarunday.mozmail.com>
# Description: A shell script that switches to the next available Pulseaudio output device/sink
# Note: This uses pactl instead of pacmd since pacmd is not available in pipewire

SINKS=$(pactl list short sinks | grep -v easyeffects)
SINK_COUNT=$(echo "$SINKS" | wc -l)

DEFAULT_SINK=$(pactl info | sed -En 's/Default Sink: (.*)/\1/p')
DEFAULT_SINK_INDEX=$(echo "$SINKS" | grep -n "$DEFAULT_SINK" | grep -Eo '^[0-9]+')

NEW_SINK_INDEX=$((DEFAULT_SINK_INDEX % $SINK_COUNT + 1))
NEW_SINK=$(echo "$SINKS" | sed "${NEW_SINK_INDEX}q;d" | awk '{ print $2 }')

# Set next sink as the default sink
pactl set-default-sink "$NEW_SINK"

# Forward all playing audio (sink inputs) to the new sink (Uncomment if your system does not automatically do this)
#SINK_INPUTS=($(pactl list short sink-inputs | grep -Eo '^[0-9]+'))
#for SINK_INPUT in ${SINK_INPUTS[*]}; do pactl move-sink-input $SINK_INPUT $NEW_SINK; done
