#!/usr/bin/env python3
import json
import re
import subprocess


def run(*args):
    try:
        return subprocess.check_output(args, text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return ""


def short_time(raw):
    m = re.search(r"(\d+):(\d+)(?::\d+)?", raw or "")
    if not m:
        return ""
    h, minutes = int(m.group(1)), int(m.group(2))
    return f"{h}h{minutes:02d}"

acpi = run("acpi", "-b")
percentages = [int(x) for x in re.findall(r"(\d{1,3})%", acpi)]
percentage = round(sum(percentages) / len(percentages)) if percentages else 0

lower = acpi.lower()
charging = "charging" in lower and "discharging" not in lower
full = "full" in lower
plugged = charging or full or "not charging" in lower
status = "Full" if full else "Charging" if charging else "Plugged" if plugged else "Discharging" if "discharging" in lower else "Unknown"

time_match = re.search(r"(\d+:\d+(?::\d+)?)\s+(remaining|until charged)", acpi, re.IGNORECASE)
time_raw = time_match.group(1) if time_match else ""
time_left = short_time(time_raw)

if charging:
    time_label = time_left or "--"
    detail = f"{time_label} to full" if time_left else "charging"
elif full:
    time_label = "full"
    detail = "charged"
elif plugged:
    time_label = "plug"
    detail = "plugged"
elif time_left:
    time_label = time_left
    detail = f"{time_label} left"
else:
    time_label = ""
    detail = status.lower()

if charging or plugged or full:
    icon = "󰂄"
elif percentage <= 10:
    icon = "󰁺"
elif percentage <= 20:
    icon = "󰁻"
elif percentage <= 30:
    icon = "󰁼"
elif percentage <= 40:
    icon = "󰁽"
elif percentage <= 50:
    icon = "󰁾"
elif percentage <= 60:
    icon = "󰁿"
elif percentage <= 70:
    icon = "󰂀"
elif percentage <= 80:
    icon = "󰂁"
elif percentage <= 90:
    icon = "󰂂"
else:
    icon = "󰁹"

print(json.dumps({
    "available": bool(acpi),
    "percentage": percentage,
    "status": status,
    "charging": charging,
    "plugged": plugged,
    "time": time_label,
    "detail": detail,
    "icon": icon,
    "raw": acpi,
}, ensure_ascii=False))
