#!/usr/bin/env bash
set -euo pipefail

dir="$HOME/.config/rofi/my-rofi"
confirm_theme="$dir/confirm.rasi"
message_theme="$dir/message.rasi"

action="${1:-}"

confirm_exit() {
    rofi -dmenu -i -no-fixed-num-lines -p "Are You Sure? : " -theme "$confirm_theme"
}

msg() {
    rofi -theme "$message_theme" -e "Available Options  -  yes / y / no / n"
}

confirmed() {
    local ans
    ans="$(confirm_exit || true)"
    case "$ans" in
        yes|YES|y|Y) return 0 ;;
        no|NO|n|N|"") return 1 ;;
        *) msg; return 1 ;;
    esac
}

case "$action" in
    poweroff)
        confirmed && systemctl poweroff
        ;;
    reboot)
        confirmed && systemctl reboot
        ;;
    lock)
        if command -v betterlockscreen >/dev/null 2>&1; then
            #betterlockscreen -l -w /home/arnaud/Desktop/arnaud/img/canada.jpg -u
            betterlockscreen -l;
            betterlockscreen -u $HOME/Desktop/arnaud/wallpapers/$(bash -c 'ls $HOME/Desktop/arnaud/wallpapers | sort -R |tail -1')
        elif command -v i3lock >/dev/null 2>&1; then
            i3lock -t -k -f -i $HOME/Desktop/arnaud/wallpapers/$(bash -c 'ls $HOME/Desktop/arnaud/wallpapers | grep ".png" | sort -R |tail -1')
        fi
        ;;
    suspend)
        if confirmed; then
            mpc -q pause 2>/dev/null || true
            amixer set Master mute 2>/dev/null || true
            systemctl suspend
        fi
        ;;
    *)
        exit 2
        ;;
esac
