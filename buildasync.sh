#!/bin/sh

logfile="$3"
[ -n "$logfile" ] || logfile="./async.log"

{ echo; date; echo; } >> "$logfile" 2>&1
nohup ./build.sh "$1" "$2" >> "$logfile" 2>&1 &
