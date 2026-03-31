#!/bin/sh
LOG="/mnt/us/weather/var/log/display.log"
INTERVAL=21600
UPDATE_SCRIPT="/mnt/us/weather/bin/update_screensaver.sh"

log() { echo "$(date): $1" >> "$LOG"; }

log "=== Weather Display Mode ==="

# Stop GUI layer (NOT framework, NOT powerd, NOT lab126)
stop lab126_gui       > /dev/null 2>&1
stop otaupd           > /dev/null 2>&1
stop phd              > /dev/null 2>&1
stop tmd              > /dev/null 2>&1
stop x                > /dev/null 2>&1
stop todo             > /dev/null 2>&1
stop mcsd             > /dev/null 2>&1
sleep 2

log "Services stopped"

# Prevent screensaver, power save
lipc-set-prop com.lab126.powerd preventScreenSaver 1
echo powersave > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null

# Disable WiFi probe file
touch /mnt/us/WIFI_NO_NET_PROBE

log "Entering main loop"

while true; do
    # Enable WiFi
    log "Enabling WiFi"
    lipc-set-prop com.lab126.cmd wirelessEnable 1 2>/dev/null
    sleep 2

    # Wait for WiFi with escalating reconnect
    i=0
    while [ $i -lt 60 ]; do
        STATE=$(lipc-get-prop com.lab126.wifid cmState 2>/dev/null)
        if echo "$STATE" | grep -q CONNECTED; then
            break
        fi
        if [ $i -eq 0 ]; then
            wpa_cli -i wlan0 reassociate > /dev/null 2>&1
        fi
        if [ $i -eq 10 ]; then
            wpa_cli -i wlan0 disconnect > /dev/null 2>&1
            sleep 1
            wpa_cli -i wlan0 reconnect > /dev/null 2>&1
        fi
        if [ $i -eq 30 ]; then
            lipc-set-prop com.lab126.wifid enable 0 2>/dev/null
            sleep 2
            lipc-set-prop com.lab126.wifid enable 1 2>/dev/null
        fi
        sleep 1
        i=$((i + 1))
    done

    log "WiFi: $STATE (waited ${i}s)"

    # Update weather
    if echo "$STATE" | grep -q CONNECTED; then
        sh "$UPDATE_SCRIPT" 2>/dev/null
        log "Update complete"
    else
        log "No WiFi, using cached image"
        fbink -m -y 28 "No WiFi - showing cached weather"
    fi

    # Display weather
    if [ -s /mnt/us/screensaver/weather.png ]; then
        fbink -k -f -W GC16 -w && fbink -g file=/mnt/us/screensaver/weather.png,w=-2,h=-2 -f -W GC16
        log "Displayed"
    fi

    # Disable WiFi to save power
    lipc-set-prop com.lab126.cmd wirelessEnable 0 2>/dev/null

    # Schedule wake and suspend
    log "Sleeping ${INTERVAL}s"
    rtcwake -d /dev/rtc1 -m no -s $INTERVAL 2>/dev/null
    echo "mem" > /sys/power/state

    log "Woke up"
done
