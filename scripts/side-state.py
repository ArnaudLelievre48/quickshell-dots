#!/usr/bin/env python3
import json
import os
import re
import shutil
import subprocess
import time


def run(*args, timeout=2):
    try:
        return subprocess.check_output(args, text=True, stderr=subprocess.DEVNULL, timeout=timeout).strip()
    except Exception:
        return ""


def cpu_percent():
    def read_stat():
        parts = open('/proc/stat').readline().split()[1:]
        vals = [int(x) for x in parts]
        idle = vals[3] + (vals[4] if len(vals) > 4 else 0)
        total = sum(vals)
        return idle, total
    try:
        i1, t1 = read_stat(); time.sleep(0.12); i2, t2 = read_stat()
        return round(max(0, min(100, (1 - (i2 - i1) / max(1, t2 - t1)) * 100)))
    except Exception:
        return 0


def mem_info():
    vals = {}
    for line in open('/proc/meminfo'):
        k, v = line.split(':', 1)
        vals[k] = int(v.split()[0])
    total = vals.get('MemTotal', 1)
    avail = vals.get('MemAvailable', 0)
    used_pct = round((total - avail) * 100 / total)
    used_gb = (total - avail) / 1024 / 1024
    total_gb = total / 1024 / 1024
    return {"percent": used_pct, "text": f"{used_gb:.1f}/{total_gb:.0f}G"}


def disk_info(path='/'):
    usage = shutil.disk_usage(path)
    pct = round(usage.used * 100 / usage.total)
    free = usage.free / 1024**3
    return {"percent": pct, "free": f"{free:.0f}G", "path": path}


def temp_info():
    out = run('sensors')
    temps = []
    for m in re.finditer(r'\+([0-9]+(?:\.[0-9]+)?)°C', out):
        val = float(m.group(1))
        if 0 < val < 120:
            temps.append(val)
    return round(max(temps)) if temps else 0


def gpu_info():
    out = run('nvidia-smi', '--query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total', '--format=csv,noheader,nounits')
    if out:
        parts = [p.strip() for p in out.splitlines()[0].split(',')]
        try:
            util, temp, used, total = map(int, parts[:4])
            return {"available": True, "percent": util, "temp": temp, "memory": f"{used/1024:.1f}/{total/1024:.0f}G"}
        except Exception:
            pass
    return {"available": False, "percent": 0, "temp": 0, "memory": ""}


def wifi_info():
    radio = run('nmcli', 'radio', 'wifi', timeout=2).strip().lower()
    wifi_on = radio == 'enabled'
    connected = run('nmcli', '-t', '-f', 'ACTIVE,SSID,SECURITY,SIGNAL', 'dev', 'wifi', 'list', '--rescan', 'yes', timeout=8)
    current = {"ssid": "offline", "signal": 0, "security": "", "connected": False}
    by_ssid = {}
    for line in connected.splitlines():
        parts = line.split(':')
        if len(parts) < 4:
            continue
        active = parts[0] == 'yes'
        signal = parts[-1]
        security = parts[-2]
        ssid = ':'.join(parts[1:-2])
        if not ssid:
            continue
        try:
            sig = int(signal)
        except Exception:
            sig = 0
        item = {"ssid": ssid, "signal": sig, "security": security, "locked": bool(security), "active": active}

        # nmcli can output the same SSID twice (one inactive BSSID first, then
        # the active one). Prefer the active entry; otherwise keep best signal.
        old = by_ssid.get(ssid)
        if old is None or active or (not old.get('active') and sig > old.get('signal', 0)):
            by_ssid[ssid] = item

        if active:
            current = {"ssid": ssid, "signal": sig, "security": security, "connected": True}

    networks = list(by_ssid.values())
    networks.sort(key=lambda n: (not n['active'], -n['signal'], n['ssid'].lower()))
    return {"on": wifi_on, "current": current, "networks": networks[:30]}


def bluetooth_info():
    show = run('bluetoothctl', 'show')
    powered = 'Powered: yes' in show
    conn = run('bluetoothctl', 'devices', 'Connected')
    devices_out = run('bluetoothctl', 'devices')
    connected = []
    for line in conn.splitlines():
        m = re.match(r'Device\s+([0-9A-F:]{17})\s+(.+)', line)
        if m:
            connected.append({"mac": m.group(1), "name": m.group(2)})
    devices = []
    connected_macs = {d['mac'] for d in connected}
    for line in devices_out.splitlines():
        m = re.match(r'Device\s+([0-9A-F:]{17})\s+(.+)', line)
        if m:
            devices.append({"mac": m.group(1), "name": m.group(2), "connected": m.group(1) in connected_macs})
    devices.sort(key=lambda d: (not d['connected'], d['name'].lower()))
    return {"powered": powered, "connected": connected, "devices": devices[:8]}


data = {
    "wifi": wifi_info(),
    "bluetooth": bluetooth_info(),
    "ram": mem_info(),
    "disk": disk_info('/'),
    "cpu": {"percent": cpu_percent()},
    "gpu": gpu_info(),
    "temperature": {"celsius": temp_info()},
}
print(json.dumps(data, ensure_ascii=False))
