#!/usr/bin/env python3
import json
import subprocess


def run(*args):
    try:
        return subprocess.check_output(args, text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return ""

status = run("playerctl", "status")
title = run("playerctl", "metadata", "--format", "{{title}}")
artist = run("playerctl", "metadata", "--format", "{{artist}}")
album = run("playerctl", "metadata", "--format", "{{album}}")
player = run("playerctl", "metadata", "--format", "{{playerName}}")
art_url = run("playerctl", "metadata", "--format", "{{mpris:artUrl}}")
length = run("playerctl", "metadata", "--format", "{{mpris:length}}")
position = run("playerctl", "position")

print(json.dumps({
    "available": bool(status),
    "status": status or "Stopped",
    "title": title or "Nothing playing",
    "artist": artist,
    "album": album,
    "player": player,
    "artUrl": art_url,
    "length": length,
    "position": position,
}, ensure_ascii=False))
