#!/usr/bin/env bash
# apply-theme.sh -- apply chicago95 xfce settings
# run this from inside a live XFCE session AFTER install.sh completes

set -eo pipefail

log()  { printf '\033[1;32m[+]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[-]\033[0m %s\n' "$*"; exit 1; }

[[ -z "$DISPLAY" && -z "$WAYLAND_DISPLAY" ]] \
    && die "no display detected -- run this from inside an XFCE session"

command -v xfconf-query &>/dev/null \
    && die "xfconf-query not found -- install xfce4 first"

# ── gtk / xfwm4 / cursor ──────────────────────────────────────────────────────
log "applying gtk and window manager theme"
xfconf-query -c xsettings -p /Net/ThemeName           -s "Chicago95" --create -t string
xfconf-query -c xsettings -p /Net/IconThemeName        -s "Chicago95" --create -t string
xfconf-query -c xsettings -p /Gtk/CursorThemeName      -s "Chicago95 Cursor Black" --create -t string
xfconf-query -c xsettings -p /Gtk/FontName             -s "Sans 8" --create -t string
xfconf-query -c xsettings -p /Xft/Antialias            -s "0" --create -t int
xfconf-query -c xsettings -p /Xft/HintStyle            -s "hintnone" --create -t string

xfconf-query -c xfwm4 -p /general/theme                -s "Chicago95" --create -t string
xfconf-query -c xfwm4 -p /general/title_font           -s "Sans Bold 8" --create -t string
xfconf-query -c xfwm4 -p /general/button_layout        -s "O|SHMC" --create -t string

# ── desktop background (teal, win95 default) ──────────────────────────────────
log "setting desktop background"
# iterate all connected monitors/workspaces
for prop in $(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep 'color-style$'); do
    xfconf-query -c xfce4-desktop -p "$prop" -s 0 --create -t int
done
for prop in $(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep 'rgba1$'); do
    xfconf-query -c xfce4-desktop -p "$prop" \
        -s "0.000000" -s "0.000000" -s "0.501961" -s "1.000000" \
        --create -t double -t double -t double -t double
done

# ── panel: win95 taskbar style ────────────────────────────────────────────────
# only adjust size/position/color -- do NOT reset /panels or plugin list
log "styling panel"
panel_id=$(xfconf-query -c xfce4-panel -p /panels 2>/dev/null | grep -m1 '[0-9]' || echo 1)
base="/panels/panel-${panel_id}"

xfconf-query -c xfce4-panel -p "${base}/size"             -s 28 --create -t int
xfconf-query -c xfce4-panel -p "${base}/position"         -s "p=8;x=0;y=0" --create -t string
xfconf-query -c xfce4-panel -p "${base}/position-locked"  -s true --create -t bool
xfconf-query -c xfce4-panel -p "${base}/length"           -s 100 --create -t int
xfconf-query -c xfce4-panel -p "${base}/length-adjust"    -s true --create -t bool
xfconf-query -c xfce4-panel -p "${base}/background-style" -s 1 --create -t int
xfconf-query -c xfce4-panel -p "${base}/background-color" \
    -s "#c0c0c0" --create -t string

# ── restart panel and wm to pick up changes ───────────────────────────────────
log "restarting xfce components"
xfwm4 --replace &
sleep 1
xfce4-panel --restart 2>/dev/null || true

log "done -- chicago95 applied. you may need to log out and back in for icons/cursor to fully reload."
