#!/bin/sh
cd /mnt/us/weather || exit 1
LOG="/mnt/us/weather/var/log/display.log"

# Load config
. etc/weather_config.sh

log() { echo "$(date): $1" >> "$LOG"; }

log "Starting weather download"
bin/download_weather.py ${METRIC:+"--metric"} --template usr/share/weather/weather_template.svg -- ${ZIP:+"$ZIP"} ${LAT:+"$LAT"} ${LON:+"$LON"} ${LOCATION:+"$LOCATION"} ${CITY_ID:+"$CITY_ID"} > var/cache/weather/weather_out.svg 2>/dev/null

SVG_SIZE=$(wc -c < var/cache/weather/weather_out.svg)
log "SVG size: ${SVG_SIZE} bytes"

log "Converting SVG to PNG"
bin/rsvg-convert --background-color=white -o var/cache/weather/weather_out.png var/cache/weather/weather_out.svg 2>>"$LOG"

if [ -s var/cache/weather/weather_out.png ]; then
    mkdir -p /mnt/us/screensaver
    cp var/cache/weather/weather_out.png /mnt/us/screensaver/weather.png
    log "Copied to screensaver folder OK"
else
    log "PNG empty, not copying"
fi
