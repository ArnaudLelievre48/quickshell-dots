#!/usr/bin/env bash
set -euo pipefail

ssid="${1:-}"
[[ -n "$ssid" ]] || exit 2

rofi_dir="$HOME/.config/rofi/my-rofi"
confirm_theme="$rofi_dir/confirm.rasi"

# First try without asking: this works for open networks and saved connections.
if nmcli dev wifi connect "$ssid" >/tmp/quickshell-wifi-connect.log 2>&1; then
  exit 0
fi

# If nmcli failed, ask for a password/passphrase via rofi.
password="$(rofi -dmenu -password -i -p "Password for $ssid" -theme "$confirm_theme" || true)"
[[ -n "$password" ]] || exit 1

nmcli dev wifi connect "$ssid" password "$password"
