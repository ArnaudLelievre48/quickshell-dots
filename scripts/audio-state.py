#!/usr/bin/env python3
import json
import re
import subprocess


def run(*args):
    try:
        return subprocess.check_output(args, text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return ""


def volume_for(target):
    text = run("pactl", "get-sink-volume", target)
    if not text:
        text = run("pactl", "get-source-volume", target)
    match = re.search(r"(\d+)%", text)
    return int(match.group(1)) if match else 0


def muted_for(kind, target):
    cmd = "get-sink-mute" if kind == "sink" else "get-source-mute"
    return "yes" in run("pactl", cmd, target).lower()


def short_list(kind):
    out = run("pactl", "list", "short", kind + "s")
    items = []
    for line in out.splitlines():
        parts = line.split("\t")
        if len(parts) < 2:
            continue
        name = parts[1]
        if kind == "source" and name.endswith(".monitor"):
            continue
        items.append(name)
    return items


def description(kind, name):
    plural = kind + "s"
    out = run("pactl", "list", plural)
    block = ""
    needle = "Name: " + name
    for candidate in out.split("\n\n"):
        if needle in candidate:
            block = candidate
            break
    match = re.search(r"Description: (.+)", block)
    return match.group(1).strip() if match else name


def build_items(kind, default):
    return [
        {
            "name": name,
            "description": description(kind, name),
            "volume": volume_for(name),
            "muted": muted_for(kind, name),
            "default": name == default,
        }
        for name in short_list(kind)
    ]


default_sink = run("pactl", "get-default-sink")
default_source = run("pactl", "get-default-source")
state = {
    "defaultSink": default_sink,
    "defaultSource": default_source,
    "sinkVolume": volume_for("@DEFAULT_SINK@"),
    "sourceVolume": volume_for("@DEFAULT_SOURCE@"),
    "sinkMuted": muted_for("sink", "@DEFAULT_SINK@"),
    "sourceMuted": muted_for("source", "@DEFAULT_SOURCE@"),
    "sinks": build_items("sink", default_sink),
    "sources": build_items("source", default_source),
}
print(json.dumps(state, ensure_ascii=False))
