#!/bin/bash
# require command: bc, pactl (from pulseaudio tool package), ffmpeg

get_even_number() {
    if [[ $(echo "${1} % 2" | bc) = "0" ]]; then
        echo $1
    else
        let lower_even="${1}-1"
        echo $lower_even
    fi
}

# Run pactl list short sources to find sources ID and put it in the
pactl list short sources

echo "Enter the audio source: Format <ID> or <:ID1.ID2>"
read AUDIO_SRC

RTMP_URL=rtmp://192.168.20.57:1935/live/test
# kodi http://192.168.20.57:8088/dash/test.mpd

echo "Enter output: Hit enter to use $RTMP_URL"
read OUTPUT
if [ ! -z "$OUTPUT" ]; then
    RTMP_URL=$OUTPUT
fi

#SCREEN_SIZE=2880x1800
SCREEN_SIZE=
if [ -z "$SCREEN_SIZE" ]; then
    xrandr | awk '{print $1" "$2}' | grep '*'
    echo "Enter the screen resolution. Hit enter to select capture region. Type w to select a window."
    read SCREEN_SIZE
fi
POS=":0.0"

if [ -z "$SCREEN_SIZE" ]; then
    WIN_INFO=$(import PNG:- | identify PNG:- | perl -ne '/ (\d+x\d+) \d+x\d+([-+]\d+[-+]\d+) / and print "$1$2\n"')
elif [ "$SCREEN_SIZE" = "w" ]; then
    WIN_INFO=$(xwininfo | grep -oP '(?<=-geometry ).*')
else
    WIN_INFO=''
fi

if [ ! -z "$WIN_INFO" ]; then
    SCREEN_SIZE=$(echo $WIN_INFO | cut -f1 -d+)
    _W=$(echo $SCREEN_SIZE | cut -f1 -dx)
    _H=$(echo $SCREEN_SIZE | cut -f2 -dx)
    _X=$(echo $WIN_INFO | cut -f2 -d+)
    _Y=$(echo $WIN_INFO | cut -f3 -d+)
    _W=$(get_even_number $_W)
    _H=$(get_even_number $_H)
    _X=$(get_even_number $_X)
    _Y=$(get_even_number $_Y)
    SCREEN_SIZE="${_W}x${_H}"
    POS="$POS+$_X,$_Y"
fi

# run xrandr to find out sreen size. For window run
# xwininfo | grep -oP '(?<=-geometry ).*' to get the window geometry and then The syntax to record a specific rectangle on screen is: (:0.0 is display)
# -video_size [width]x[height] -i :0.0+[x],[y]
# That xwininfo return something like 1145x662+2021+190 which is usable

echo "SCREEN_SIZE: $SCREEN_SIZE | POS: $POS"

ffmpeg -f pulse -ac 2 -i $AUDIO_SRC -f x11grab -rtbufsize 100M -s $SCREEN_SIZE -framerate 30 -probesize 10M -draw_mouse 1 -i $POS -acodec aac -c:v libx264 -r 30 -preset ultrafast -tune zerolatency -crf 25 -pix_fmt yuv420p -f flv $RTMP_URL

# hw works but see no less cpu usages and a bit worse in quality
#ffmpeg -hwaccel vaapi -hwaccel_device /dev/dri/renderD128 -f pulse -ac 2 -i $AUDIO_SRC -f x11grab -rtbufsize 100M -s $SCREEN_SIZE -framerate 30 -probesize 10M -draw_mouse 1 -i :0.0 -acodec aac -c:v libx264 -r 30 -preset ultrafast -tune zerolatency -crf 25 -pix_fmt yuv420p -f flv $RTMP_URL

#ffmpeg -f pulse -ac 2 -i $AUDIO_SRC  -f kmsgrab -i - -vf 'hwmap=derive_device=vaapi,scale_vaapi=w=1920:h=1080:format=nv12' -c:v h264_vaapi -r 30 -preset ultrafast -tune zerolatency -crf 25 -pix_fmt yuv420p -f flv $RTMP_URL
