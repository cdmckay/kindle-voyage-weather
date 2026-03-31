# Kindle Voyage Weather Display

Turn a jailbroken Kindle Voyage into a standalone e-ink weather station that automatically wakes up, fetches weather data, displays it, and goes back to sleep.

![Kindle Voyage showing weather](https://raw.githubusercontent.com/cdmckay/kindle-voyage-weather/main/screenshot.png)

## How it works

1. The Kindle stops its GUI and takes over the display
2. It connects to WiFi and fetches weather data from the [World Meteorological Organization](https://worldweather.wmo.int/) (or Weather.gov/AccuWeather)
3. An SVG template is filled with the forecast and rendered to a PNG
4. The image is displayed on the e-ink screen using [FBInk](https://github.com/NiLuJe/FBInk) with a full GC16 refresh
5. WiFi is disabled and the Kindle enters suspend-to-RAM via `rtcwake`
6. After 6 hours, the RTC alarm wakes the device and the cycle repeats

Battery life is approximately 3-4 weeks on a single charge with 6-hour update intervals.

## Prerequisites

- **Kindle Voyage** (7th gen) with firmware 5.13.x - 5.16.2.1.1
- **Jailbreak** via [WinterBreak](https://kindlemodding.org/jailbreaking/WinterBreak/)
- **KUAL** and **MRPI** installed ([guide](https://kindlemodding.org/jailbreaking/post-jailbreak/installing-kual-mrpi/))
- **Python 3** installed via [NiLuJe's snapshots](https://www.mobileread.com/forums/showthread.php?t=225030)
- **FBInk** available (bundled with [USBNetwork](https://www.mobileread.com/forums/showthread.php?t=225030))
- A **2.4 GHz WiFi network** (the Voyage does not support 5 GHz)

## Installation

### 1. Copy files to Kindle

Connect your Kindle via USB and copy the directories:

```
kindle/bin/          -> /mnt/us/weather/bin/
kindle/etc/          -> /mnt/us/weather/etc/
kindle/lib/          -> /mnt/us/weather/lib/
kindle/usr/          -> /mnt/us/weather/usr/
kindle/var/          -> /mnt/us/weather/var/
extensions/weather/  -> /mnt/us/extensions/weather/
```

### 2. Configure your location

Copy the example config and edit it:

```sh
cp /mnt/us/weather/etc/weather_config.sh.example /mnt/us/weather/etc/weather_config.sh
```

Edit `weather_config.sh` to set your location. Options:

- **US (ZIP code):** Set `ZIP="10001"`
- **US (coordinates):** Set `LAT` and `LON`
- **Worldwide (WMO):** Set `CITY_ID` from [the WMO city list](https://worldweather.wmo.int/en/json/full_city_list.txt)
- **Worldwide (AccuWeather):** Set `KEY` and `LOCATION` (requires free API key)

For Celsius, uncomment `METRIC="1"`.

### 3. Make scripts executable

Via SSH or terminal:

```sh
chmod +x /mnt/us/weather/bin/*.sh
chmod +x /mnt/us/weather/bin/*.py
chmod +x /mnt/us/weather/bin/rsvg-convert
chmod +x /mnt/us/weather/bin/pngcrush
chmod +x /mnt/us/extensions/weather/bin/*.sh
```

### 4. Create screensaver directory

```sh
mkdir -p /mnt/us/screensaver
```

## Usage

### Start Weather Display

Open **KUAL > Weather > Start Weather Display**

The Kindle will:
- Stop the GUI
- Connect to WiFi
- Download and display the weather
- Go to sleep for 6 hours
- Wake up and repeat

### Stop Weather Display

Hold the power button for **20-30 seconds** to force a reboot. The Kindle will boot back to its normal ereader mode.

### Update interval

Edit `INTERVAL` in `kindle/bin/weather_display.sh` (value in seconds, default 21600 = 6 hours).

## Architecture

```
kindle/
  bin/
    weather_display.sh    # Main loop: WiFi -> update -> display -> sleep
    update_screensaver.sh # Downloads weather and renders PNG
    update_weather.sh     # Alternative updater (used by KOReader screensaver)
    download_weather.py   # Fetches weather data, fills SVG template
    rsvg-convert          # SVG to PNG converter (ARM binary)
    pngcrush              # PNG optimizer (ARM binary, unused but included)
  etc/
    weather_config.sh     # Your location config
    ssl/certs/            # CA certificates for HTTPS
  lib/
    python3.7/            # Bundled Python packages (docopt)
    *.so                  # Shared libraries for rsvg-convert
  usr/share/weather/
    weather_template.svg  # SVG template for the forecast display
    error.png             # Error image
  var/
    cache/weather/        # Cached SVG and PNG files
    log/                  # Log files

extensions/weather/       # KUAL extension
  menu.json               # KUAL menu entries
  config.xml              # Extension metadata
```

## How the sleep/wake cycle works

This project uses the same proven approach as [kindle-clock](https://github.com/mattzzw/kindle-clock) and [kindle-kt3_weatherdisplay](https://github.com/nicoh88/kindle-kt3_weatherdisplay_battery-optimized):

1. `stop lab126_gui` — stops the Kindle's GUI layer (NOT `framework` or `powerd`, which are needed for WiFi and battery)
2. `lipc-set-prop com.lab126.powerd preventScreenSaver 1` — prevents the screensaver from overwriting our display
3. `rtcwake -d /dev/rtc1 -m no -s $INTERVAL` — sets the RTC alarm
4. `echo "mem" > /sys/power/state` — suspends to RAM
5. The RTC alarm wakes the device, and the loop continues

The script is launched from KUAL using `setsid` to detach it from KUAL's process tree, so it survives the GUI shutdown.

## KOReader screensaver mode

If you prefer to use the Kindle as an ereader with weather as the sleep screen:

1. Configure KOReader's screensaver to show a random image from `/mnt/us/screensaver/`
2. Use **KUAL > Weather > Update Screensaver Once** to manually refresh the weather image
3. The weather will show whenever KOReader goes to sleep

## Credits

- Weather data: [World Meteorological Organization](https://worldweather.wmo.int/)
- SVG template and `download_weather.py`: Based on [weather_kindle](https://github.com/scolby33/weather_kindle) by scolby33, which is based on [kindle-weather-display](https://github.com/mpetroff/kindle-weather-display) by Matthew Petroff
- Sleep/wake approach: Inspired by [kindle-clock](https://github.com/mattzzw/kindle-clock) and [kindle-kt3_weatherdisplay](https://github.com/nicoh88/kindle-kt3_weatherdisplay_battery-optimized)
- Display rendering: [FBInk](https://github.com/NiLuJe/FBInk) by NiLuJe

## License

Scripts are MIT licensed. `download_weather.py` and SVG template retain their original licenses from [weather_kindle](https://github.com/scolby33/weather_kindle). ARM binaries (`rsvg-convert`, `pngcrush`) and shared libraries retain their respective upstream licenses.
