import json
import math
import os
import re
import subprocess
import sys
import time
import urllib.request


def read_token():
    token_file = os.environ["TOKEN_FILE"]
    with open(token_file) as f:
        return f.read().strip()


def get_lux(ha_url, sensor_entity_id, token):
    url = f"{ha_url}/api/states/{sensor_entity_id}"
    req = urllib.request.Request(url)
    req.add_header("Authorization", f"Bearer {token}")
    req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, timeout=10) as resp:
        data = json.loads(resp.read())
    return float(data["state"])


def log_map(lux, lux_min, lux_max, bright_min, bright_max):
    lux = max(lux_min, min(lux_max, lux))
    log_min = math.log(lux_min)
    log_max = math.log(lux_max)
    log_lux = math.log(lux)
    t = (log_lux - log_min) / (log_max - log_min)
    return int(round(bright_min + t * (bright_max - bright_min)))


def detect_displays():
    try:
        result = subprocess.run(
            ["ddcutil", "detect"],
            capture_output=True, text=True, timeout=15,
        )
        return re.findall(r"Display\s+(\d+)", result.stdout)
    except Exception as e:
        print(f"Error detecting displays: {e}", file=sys.stderr)
        return []


def set_brightness(display, brightness):
    subprocess.run(
        ["ddcutil", "setvcp", "10", str(brightness),
         "--display", str(display)],
        capture_output=True, timeout=15,
    )


def main():
    ha_url = os.environ["HA_URL"]
    sensor_entity_id = os.environ["SENSOR_ENTITY_ID"]
    lux_min = int(os.environ["LUX_MIN"])
    lux_max = int(os.environ["LUX_MAX"])
    brightness_min = int(os.environ["BRIGHTNESS_MIN"])
    brightness_max = int(os.environ["BRIGHTNESS_MAX"])
    interval = int(os.environ["INTERVAL"])
    hysteresis = int(os.environ["HYSTERESIS"])

    last = {}

    while True:
        try:
            token = read_token()
            lux = get_lux(ha_url, sensor_entity_id, token)
            brightness = log_map(
                lux, lux_min, lux_max, brightness_min, brightness_max,
            )
            displays = detect_displays()

            if not displays:
                print("No displays detected, skipping", file=sys.stderr)
            else:
                for d in displays:
                    prev = last.get(d)
                    if prev is None or abs(brightness - prev) >= hysteresis:
                        print(
                            f"Display {d}: setting brightness to "
                            f"{brightness} (lux={lux:.0f})",
                            file=sys.stderr,
                        )
                        set_brightness(d, brightness)
                        last[d] = brightness
                    else:
                        print(
                            f"Display {d}: within hysteresis "
                            f"(current={brightness}, last={prev})",
                            file=sys.stderr,
                        )
        except Exception as e:
            print(f"Error: {e}", file=sys.stderr)

        time.sleep(interval)


if __name__ == "__main__":
    main()
