#!/bin/bash
set -euo pipefail

usage() {
    echo "usage: $0 <package> [label]" >&2
    echo "env: MODE=background|idle|scroll DURATION=600 URLS=\"url ...\" OUT=bench-results" >&2
    exit 1
}

[ $# -ge 1 ] || usage
PKG="$1"
LABEL="${2:-$1}"
MODE="${MODE:-background}"
DURATION="${DURATION:-600}"
OUT="${OUT:-bench-results}"
URLS="${URLS:-https://en.wikipedia.org/wiki/Android_(operating_system) https://www.bbc.com/news https://github.com/trending https://www.theverge.com https://news.ycombinator.com}"

case "$MODE" in background|idle|scroll) ;; *) usage ;; esac

adb get-state >/dev/null
adb shell pm path "$PKG" >/dev/null || { echo "$PKG is not installed" >&2; exit 1; }

RUN="$OUT/$(date +%Y%m%d-%H%M%S)-$LABEL-$MODE"
mkdir -p "$RUN"

uid_name() {
    local uid
    uid=$(adb shell dumpsys package "$PKG" | tr -d '\r' | grep -m1 -o 'userId=[0-9]*' | cut -d= -f2)
    [ -n "$uid" ] || { echo "cannot resolve uid for $PKG" >&2; exit 1; }
    if [ "$uid" -ge 10000 ]; then
        echo "u0a$((uid - 10000))"
    else
        echo "$uid"
    fi
}

to_bytes() {
    awk '{
        v = $1; u = toupper($2);
        if (u ~ /^GB/) v *= 1024 * 1024 * 1024;
        else if (u ~ /^MB/) v *= 1024 * 1024;
        else if (u ~ /^KB/) v *= 1024;
        printf "%d\n", v
    }'
}

finish() {
    adb shell dumpsys battery reset >/dev/null 2>&1 || true
    adb shell svc power stayon false >/dev/null 2>&1 || true
}
trap finish EXIT

UID_NAME=$(uid_name)

adb shell am force-stop "$PKG"
adb shell svc power stayon usb
adb shell input keyevent KEYCODE_WAKEUP
sleep 2

START_MS=$(adb shell am start -W -a android.intent.action.VIEW -d "about:blank" -p "$PKG" \
    | tr -d '\r' | awk -F': ' '/TotalTime/ {print $2}')
START_MS="${START_MS:-NA}"
sleep 5

adb shell dumpsys battery unplug
adb shell dumpsys batterystats --reset >/dev/null

for url in $URLS; do
    adb shell am start -a android.intent.action.VIEW -d "$url" -p "$PKG" >/dev/null
    sleep 15
done

case "$MODE" in
    background)
        adb shell input keyevent KEYCODE_HOME
        sleep "$DURATION"
        ;;
    idle)
        sleep "$DURATION"
        ;;
    scroll)
        read -r W H < <(adb shell wm size | tr -d '\r' | awk -F'[ x]' '/Physical/ {print $3, $4}')
        END=$((SECONDS + DURATION))
        while [ "$SECONDS" -lt "$END" ]; do
            adb shell input swipe $((W / 2)) $((H * 3 / 4)) $((W / 2)) $((H / 4)) 300
            sleep 1
            adb shell input swipe $((W / 2)) $((H / 4)) $((W / 2)) $((H * 3 / 4)) 300
            sleep 1
        done
        ;;
esac

adb shell dumpsys batterystats | tr -d '\r' > "$RUN/batterystats.txt"
adb shell dumpsys meminfo | tr -d '\r' > "$RUN/meminfo.txt"
adb shell dumpsys alarm | tr -d '\r' > "$RUN/alarm.txt"
adb shell dumpsys jobscheduler | tr -d '\r' > "$RUN/jobscheduler.txt"

UID_BLOCK="$RUN/uid.txt"
awk -v u="  $UID_NAME:" '
    index($0, u) == 1 { on = 1; print; next }
    on && /^  [0-9a-z]+:$/ { exit }
    on { print }
' "$RUN/batterystats.txt" > "$UID_BLOCK"

POWER_MAH=$(grep -m1 -E "^ +UID $UID_NAME: " "$RUN/batterystats.txt" \
    | sed -E 's/^ +UID [^:]+: ([0-9.]+).*/\1/' || true)
CPU_LINE=$(grep -m1 "Total cpu time:" "$UID_BLOCK" || true)
CPU_USER_MS=$(echo "$CPU_LINE" | grep -o 'u=[0-9]*ms' | tr -dc '0-9' || true)
CPU_SYS_MS=$(echo "$CPU_LINE" | grep -o 's=[0-9]*ms' | tr -dc '0-9' || true)
WIFI_RX=$(grep -m1 "Wi-Fi network:" "$UID_BLOCK" | sed -E 's/.*network: ([0-9.]+[A-Za-z]+) received.*/\1/' \
    | sed -E 's/([0-9.]+)([A-Za-z]+)/\1 \2/' | to_bytes || true)
WIFI_TX=$(grep -m1 "Wi-Fi network:" "$UID_BLOCK" | sed -E 's/.*received, ([0-9.]+[A-Za-z]+) sent.*/\1/' \
    | sed -E 's/([0-9.]+)([A-Za-z]+)/\1 \2/' | to_bytes || true)
MOBILE_RX=$(grep -m1 "Mobile network:" "$UID_BLOCK" | sed -E 's/.*network: ([0-9.]+[A-Za-z]+) received.*/\1/' \
    | sed -E 's/([0-9.]+)([A-Za-z]+)/\1 \2/' | to_bytes || true)
WAKEUPS=$(grep -E "Wakeup alarm" "$UID_BLOCK" | grep -o '[0-9]* times' | tr -dc '0-9\n' \
    | awk '{s += $1} END {print s + 0}')
JOBS=$(grep -c -E "^ +JOB #.*$PKG" "$RUN/jobscheduler.txt" || true)
PSS_KB=$(awk '/Total PSS by process:/ {on = 1; next} on && /^$/ {exit} on {print}' "$RUN/meminfo.txt" \
    | grep -F "$PKG" | sed -E 's/^ *([0-9,]+)K: .*/\1/' | tr -d ',' | awk '{s += $1} END {print s + 0}')

CSV="$OUT/bench.csv"
[ -f "$CSV" ] || echo "timestamp,label,package,mode,duration_s,cold_start_ms,power_mah,cpu_user_ms,cpu_sys_ms,wifi_rx_bytes,wifi_tx_bytes,mobile_rx_bytes,alarm_wakeups,scheduled_jobs,pss_kb" > "$CSV"
echo "$(date -Iseconds),$LABEL,$PKG,$MODE,$DURATION,$START_MS,${POWER_MAH:-NA},${CPU_USER_MS:-NA},${CPU_SYS_MS:-NA},${WIFI_RX:-NA},${WIFI_TX:-NA},${MOBILE_RX:-NA},${WAKEUPS:-NA},${JOBS:-NA},${PSS_KB:-NA}" >> "$CSV"

echo "raw dumps: $RUN"
tail -n 1 "$CSV"
