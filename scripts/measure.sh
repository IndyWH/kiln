#!/usr/bin/env bash
# Kiln baseline measurement. The same script and workload run on Ubuntu and on Kiln.
#
#   measure.sh run    CPU speed, audio latency and responsiveness, once
#   measure.sh boot   save this boot's times; run once after each of 5 reboots
#   measure.sh new    start a fresh results folder
#
# Add --short for a quick test, kept apart from real results.
# Writes only to results/ in this repo. No disk tests. No settings are changed.

set -u
export LC_ALL=C

SELF=$(readlink -f "$0")
cd "$(dirname "$SELF")/.." || exit 1

MODE=${1:-}
SHORT=0
for a in "$@"; do [ "$a" = --short ] && SHORT=1; done

BOOTS_WANTED=5
BUFFERS="1024 512 256 128 64 32"
STREAM=kiln-measure
HIST_MAX_US=100000
CORES=$(nproc)

if ((SHORT)); then
  SB_SECS=2 REPEATS=1 SEVEN_PASSES=1 AUDIO_SECS=5 RESP_SECS=5 LOAD_SETTLE=3
else
  SB_SECS=30 REPEATS=3 SEVEN_PASSES=10 AUDIO_SECS=120 RESP_SECS=120 LOAD_SETTLE=15
fi

OS=$(. /etc/os-release; echo "${ID:-linux}${VERSION_ID:+-$VERSION_ID}")
LOAD_PIDS=()
PW_PID=

results_dir() {
  if ((SHORT)); then echo "results/$OS-$(date +%F)-short"; return; fi
  local latest
  latest=$(ls -1dt "results/$OS"-20* 2>/dev/null | grep -v -- '-short$' | head -1)
  echo "${latest:-results/$OS-$(date +%F)}"
}

need() {
  local missing=() pkgs=() t
  for t in "$@"; do
    case $t in
      7z) command -v 7z >/dev/null || command -v 7zz >/dev/null || { missing+=(7z); pkgs+=(7zip); } ;;
      *)
        command -v "$t" >/dev/null && continue
        missing+=("$t")
        case $t in
          cyclictest) pkgs+=(rt-tests) ;;
          pw-cat | pw-top) pkgs+=(pipewire-bin) ;;
          wpctl) pkgs+=(wireplumber) ;;
          systemd-analyze) pkgs+=(systemd) ;;
          *) pkgs+=("$t") ;;
        esac
        ;;
    esac
  done
  ((${#missing[@]})) || return 0
  echo "Missing tools: ${missing[*]}"
  if command -v apt-get >/dev/null; then
    echo "Run this, then start again:"
    echo "  sudo apt install $(printf '%s\n' "${pkgs[@]}" | sort -u | tr '\n' ' ')"
  else
    echo "Install them, then start again."
  fi
  exit 1
}

median() {
  sort -n | awk '{a[NR]=$1} END {if (NR) printf "%.3f", (NR%2) ? a[(NR+1)/2] : (a[NR/2]+a[NR/2+1])/2}'
}

say() { echo "$*" | tee -a "$LOG"; }

# --- Compile load: one loop per core. gcc reads from a pipe and writes nothing to disk. ---

gen_source() {
  awk 'BEGIN {
    for (i = 0; i < 4000; i++) {
      printf "static int t%d[64];\n", i
      printf "int f%d(int x, int y) { int s = x; for (int i = 0; i < 64; i++) {", i
      printf " t%d[i] = (s * %d + y) ^ i; if (t%d[i] & 1) s += t%d[i]; else s -= i * y; }", i, i + 3, i, i
      printf " return s; }\n"
    }
  }'
}
export -f gen_source

start_load() {
  local i
  for ((i = 0; i < CORES; i++)); do
    setsid bash -c 'while :; do gen_source | gcc -x c -O2 -pipe -S -o /dev/null -; done' >/dev/null 2>&1 &
    LOAD_PIDS+=($!)
  done
  sleep "$LOAD_SETTLE"
}

stop_load() {
  local p
  for p in "${LOAD_PIDS[@]}"; do kill -TERM -- "-$p" 2>/dev/null; done
  ((${#LOAD_PIDS[@]})) && wait "${LOAD_PIDS[@]}" 2>/dev/null
  LOAD_PIDS=()
}

cleanup() {
  [ -n "$PW_PID" ] && kill "$PW_PID" 2>/dev/null
  stop_load
}

cpu_ticks() { awk '/^cpu /{b=$2+$3+$4+$7+$8; print b, b+$5+$6; exit}' /proc/stat; }

busy_since() {
  local b t
  read -r b t < <(cpu_ticks)
  awk -v b0="$1" -v t0="$2" -v b="$b" -v t="$t" 'BEGIN {printf "%.1f", (t>t0) ? 100*(b-b0)/(t-t0) : 0}'
}

# --- System facts, so the two systems can be compared fairly ---

screen_cards() {
  local s c
  for s in /sys/class/drm/card*-*/status; do
    [ "$(cat "$s" 2>/dev/null)" = connected ] || continue
    c=$(basename "$(dirname "$s")")
    printf '%s %s:%s\n' "$c" \
      "$(sed 's/0x//' "/sys/class/drm/${c%%-*}/device/vendor" 2>/dev/null)" \
      "$(sed 's/0x//' "/sys/class/drm/${c%%-*}/device/device" 2>/dev/null)"
  done
}

power_mode() {
  command -v powerprofilesctl >/dev/null && powerprofilesctl get 2>/dev/null && return
  cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference 2>/dev/null
}

log_system() {
  {
    echo "=== System, $(date '+%F %T')"
    echo "OS: $OS  Kernel: $(uname -r)"
    grep -m1 'model name' /proc/cpuinfo
    echo "Threads: $CORES  Load average: $(cut -d' ' -f1-3 /proc/loadavg)"
    grep -m1 microcode /proc/cpuinfo
    echo "Power mode: $(power_mode)"
    echo "Governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)"
    echo "Boot options: $(cat /proc/cmdline)"
    echo "Screen: $(screen_cards | tr '\n' ' ')"
    gcc --version | head -1
    sysbench --version
    "$SEVEN" 2>&1 | grep -m1 '7-Zip'
    cyclictest --help 2>&1 | head -1
    pw-cat --version 2>&1 | grep -i -m1 'libpipewire'
    echo
  } >>"$LOG"
}

# --- 1. CPU speed: sysbench and 7-Zip, on one thread and on every thread ---

run_cpu() {
  local rep t out score
  echo "tool,threads,repeat,score" >"$DIR/cpu.csv"
  for ((rep = 1; rep <= REPEATS; rep++)); do
    for t in 1 "$CORES"; do
      say "CPU speed: sysbench, $t threads, run $rep of $REPEATS"
      out=$(sysbench cpu --cpu-max-prime=20000 --threads="$t" --time="$SB_SECS" run 2>&1)
      echo "$out" >>"$LOG"
      score=$(echo "$out" | awk '/events per second/{print $NF}')
      echo "sysbench,$t,$rep,${score:-failed}" >>"$DIR/cpu.csv"

      say "CPU speed: 7-Zip, $t threads, run $rep of $REPEATS"
      out=$("$SEVEN" b "$SEVEN_PASSES" -mmt="$t" -md25 2>&1)
      echo "$out" >>"$LOG"
      score=$(echo "$out" | awk '/^Tot:/{print $NF}')
      echo "7zip,$t,$rep,${score:-failed}" >>"$DIR/cpu.csv"
    done
  done
}

# --- 2. Audio latency: silence is played at smaller and smaller buffers, under load ---

audio_step() {
  local q=$1 b0 t0 busy res samples actual rate drops wq bq status
  pw-cat -p -a --rate 48000 --channels 2 --format s16 --latency "$q" --target "$SINK" \
    -P "{ node.name = $STREAM }" - </dev/zero >>"$LOG" 2>&1 &
  PW_PID=$!
  sleep 3
  read -r b0 t0 < <(cpu_ticks)
  res=$(pw-top -b -n $((AUDIO_SECS + 1)) 2>&1 | awk '$1 == "R"' | tee -a "$LOG" |
    awk -v sink="$SINK" -v stream="$STREAM" '
      $NF == sink || $NF == stream {
        if (!($NF in first)) first[$NF] = $9
        last[$NF] = $9
        if ($7 + 0 > wq) wq = $7 + 0
        if ($8 + 0 > bq) bq = $8 + 0
        if ($NF == sink) { n++; q = $3; r = $4 }
      }
      END {
        for (k in last) d += last[k] - first[k]
        printf "%d %d %d %d %.2f %.2f", n, q, r, d, wq, bq
      }')
  busy=$(busy_since "$b0" "$t0")
  kill "$PW_PID" 2>/dev/null
  wait "$PW_PID" 2>/dev/null
  PW_PID=
  read -r samples actual rate drops wq bq <<<"$res"

  if ((samples < AUDIO_SECS * 8 / 10)); then status=no-data
  elif ((drops > 0)); then status=dropouts
  elif ((actual != q)); then status=wrong-buffer
  else status=clean
  fi
  echo "$q,$actual,$rate,$samples,$drops,$wq,$bq,$busy,$status" >>"$DIR/audio.csv"
  say "Audio: buffer $q, used $actual, dropouts $drops, every core ${busy}% busy: $status"
  [ "$status" = clean ] || [ "$status" = wrong-buffer ]
}

run_audio() {
  local q
  echo "buffer,actual,rate,samples,dropouts,worst_wait,worst_busy,cpu_busy,status" >"$DIR/audio.csv"
  for q in $BUFFERS; do
    audio_step "$q" || break
  done
}

# --- 3. Responsiveness: how late a normal waiting task wakes up, under load ---

run_responsiveness() {
  local raw="$DIR/cyclictest.log" b0 t0 busy res
  say "Responsiveness: 8 waiting tasks for $RESP_SECS seconds"
  read -r b0 t0 < <(cpu_ticks)
  cyclictest --policy=other -t 8 -i 1000 -D "$RESP_SECS" -q --laptop -h "$HIST_MAX_US" >"$raw" 2>&1
  busy=$(busy_since "$b0" "$t0")
  res=$(awk -v hmax="$HIST_MAX_US" '
    /^[0-9]/ { for (i = 2; i <= NF; i++) { c[$1 + 0] += $i; total += $i } }
    /Histogram Overflows:/ { for (i = 4; i <= NF; i++) { over += $i + 0; total += $i + 0 } }
    /Max Latencies:/ { for (i = 4; i <= NF; i++) if ($i + 0 > max) max = $i + 0 }
    END {
      if (!total) { print "failed"; exit }
      p50 = p99 = p999 = -1
      for (u = 0; u <= hmax; u++) {
        seen += c[u]
        if (p50 < 0 && seen >= total * 0.5) p50 = u
        if (p99 < 0 && seen >= total * 0.99) p99 = u
        if (p999 < 0 && seen >= total * 0.999) p999 = u
      }
      if (p50 < 0) p50 = max
      if (p99 < 0) p99 = max
      if (p999 < 0) p999 = max
      printf "%d,%d,%d,%d,%d,%d", total, p50, p99, p999, max, over
    }' "$raw")
  echo "wakeups,median_us,p99_us,p999_us,worst_us,over_100ms,cpu_busy" >"$DIR/responsiveness.csv"
  echo "$res,$busy" >>"$DIR/responsiveness.csv"
}

# --- Boot time ---

to_seconds() {
  awk -v t="$*" 'BEGIN {
    n = split(t, a, " ")
    for (i = 1; i <= n; i++) {
      v = a[i] + 0
      if (a[i] ~ /ms$/) s += v / 1000
      else if (a[i] ~ /min$/) s += v * 60
      else if (a[i] ~ /h$/) s += v * 3600
      else if (a[i] ~ /us$/) s += v / 1000000
      else s += v
    }
    printf "%.3f", s
  }'
}

run_boot() {
  need systemd-analyze
  mkdir -p "$DIR"
  local csv="$DIR/boot.csv" id count line i parts graphical
  id=$(cat /proc/sys/kernel/random/boot_id)
  [ -f "$csv" ] || echo "boot,time,boot_id,kernel_version,firmware,loader,kernel,initrd,userspace,login_screen,total_no_firmware" >"$csv"
  count=$(($(wc -l <"$csv") - 1))

  if grep -q "$id" "$csv"; then
    echo "This boot is already saved ($count of $BOOTS_WANTED). Reboot, log in and run this again."
    exit 0
  fi
  if ((count >= BOOTS_WANTED)); then
    echo "All $BOOTS_WANTED boots are saved. To start again, run: scripts/measure.sh new"
    exit 0
  fi

  for ((i = 0; i < 24; i++)); do
    line=$(systemd-analyze 2>&1) && break
    ((i)) || echo "Waiting for the boot to finish..."
    line=
    sleep 5
  done
  if [ -z "$line" ]; then
    echo "The system says its boot has not finished. Try again in a few minutes."
    exit 1
  fi

  # Split "16.8s (firmware) + 1.8s (loader) + ..." into phases, in seconds. A missing phase stays blank.
  parts=$(echo "$line" | awk '/^Startup finished in/ {
    acc = ""
    for (i = 4; i <= NF; i++) {
      if ($i == "=") break
      if ($i == "+") continue
      if ($i ~ /^\(.*\)$/) { name = substr($i, 2, length($i) - 2); print name "=" acc; acc = ""; continue }
      acc = acc " " $i
    }
    exit
  }')
  phase() { to_seconds "$(echo "$parts" | sed -n "s/^$1=//p")"; }
  graphical=$(echo "$line" | sed -n 's/.*reached after \(.*\) in userspace.*/\1/p')

  local fw lo ke ir us gr total
  fw=$(phase firmware) lo=$(phase loader) ke=$(phase kernel) ir=$(phase initrd) us=$(phase userspace)
  gr=$(to_seconds "$graphical")
  total=$(awk -v a="$lo" -v b="$ke" -v c="$ir" -v d="$us" 'BEGIN {printf "%.3f", a+b+c+d}')
  count=$((count + 1))
  echo "$count,$(date '+%F %T'),$id,$(uname -r),$fw,$lo,$ke,$ir,$us,$gr,$total" >>"$csv"

  {
    echo "=== Boot $count, $(date '+%F %T')"
    echo "$line"
    systemd-analyze critical-chain 2>&1
    systemd-analyze blame 2>&1 | head -20
    echo "System state: $(systemctl is-system-running 2>&1)"
    echo
  } >>"$DIR/boot.log"

  echo "Boot $count of $BOOTS_WANTED saved: $total s without firmware, firmware $fw s."
  if ((count < BOOTS_WANTED)); then
    echo "Reboot, log in and run this again."
  else
    write_summary
  fi
}

# --- Summary of whatever has been measured so far ---

cpu_median() {
  awk -F, -v tool="$1" -v t="$2" '$1 == tool && $2 == t {print $4}' "$DIR/cpu.csv" | median
}

boot_median() {
  awk -F, -v col="$1" 'NR > 1 {print $col}' "$DIR/boot.csv" | median
}

write_summary() {
  local f="$DIR/summary.txt"
  {
    echo "Kiln measurement: $OS, $(date +%F)"
    if [ -f "$DIR/boot.csv" ]; then
      local n kernels
      n=$(($(wc -l <"$DIR/boot.csv") - 1))
      kernels=$(awk -F, 'NR > 1 {print $4}' "$DIR/boot.csv" | sort -u | wc -l)
      if ((n >= BOOTS_WANTED)); then
        printf 'Boot (median of %d, seconds): %.1f without firmware (loader %.1f, kernel %.1f, initrd %.1f, userspace %.1f). Firmware %.1f separately.\n' \
          "$n" "$(boot_median 11)" "$(boot_median 6)" "$(boot_median 7)" "$(boot_median 8)" "$(boot_median 9)" "$(boot_median 5)"
      else
        echo "Boot: $n of $BOOTS_WANTED boots saved so far."
      fi
      ((kernels > 1)) && echo "WARNING: the kernel changed between boots. Boot numbers may not be fair."
    fi
    if [ -f "$DIR/audio.csv" ]; then
      awk -F, 'NR > 1 {
          if ($9 == "clean") { q = $1; r = $3; w = $6; b = $7; c = $8 }
          if ($9 != "clean") bad = bad " " $1 "=" $9
        }
        END {
          if (q) printf "Audio: smallest clean buffer %d samples (%.2f ms), every core %s%% busy. Worst timing %s wait, %s busy, as a share of the buffer.\n", q, 1000 * q / r, c, w, b
          else print "Audio: no buffer played clean."
          if (bad) print "Audio, not clean:" bad
          if (q == 32) print "Audio note: 32 is the lowest PipeWire allows here. Compare worst timing instead."
        }' "$DIR/audio.csv"
    fi
    if [ -f "$DIR/responsiveness.csv" ]; then
      awk -F, 'NR == 2 {
        if ($1 == "failed") { print "Responsiveness: failed, see cyclictest.log"; exit }
        printf "Responsiveness: wake-up delay median %.2f ms, 99%% %.2f ms, worst %.2f ms, every core %s%% busy.\n", $2 / 1000, $3 / 1000, $5 / 1000, $NF
      }' "$DIR/responsiveness.csv"
    fi
    if [ -f "$DIR/cpu.csv" ]; then
      printf 'CPU: sysbench %.0f (1 thread), %.0f (%d threads) events per second. 7-Zip %.0f (1 thread), %.0f (%d threads) MIPS.\n' \
        "$(cpu_median sysbench 1)" "$(cpu_median sysbench "$CORES")" "$CORES" \
        "$(cpu_median 7zip 1)" "$(cpu_median 7zip "$CORES")" "$CORES"
    fi
    echo "Setup: power mode $(power_mode), screen on $(screen_cards | tr '\n' ' ')"
    echo "Details: $DIR"
  } >"$f"
  cat "$f"
}

# --- Main run ---

keep_awake() {
  [ -n "${KILN_AWAKE:-}" ] && return
  export KILN_AWAKE=1
  local why="Kiln measurement running"
  # A sleeping screen can remove its audio output mid-test. Lasts only as long as the run.
  if command -v gnome-session-inhibit >/dev/null && gnome-session-inhibit --inhibit idle true 2>/dev/null; then
    exec gnome-session-inhibit --inhibit idle:suspend --reason "$why" "$SELF" "$@"
  elif systemd-inhibit --what=idle:sleep --who=kiln --why="$why" true 2>/dev/null; then
    exec systemd-inhibit --what=idle:sleep --who=kiln --why="$why" "$SELF" "$@"
  fi
  echo "Note: could not keep the screen awake. Move the mouse now and then during the run."
}

run_all() {
  need sysbench 7z gcc cyclictest pw-cat pw-top wpctl
  SEVEN=$(command -v 7z || command -v 7zz)
  SINK=$(wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null | sed -n 's/.*node\.name = "\(.*\)".*/\1/p')
  if [ -z "$SINK" ]; then
    echo "No audio output found. Is PipeWire running?"
    exit 1
  fi

  ((SHORT)) && rm -f "$DIR/run.log" "$DIR/responsiveness.csv"
  if [ -f "$DIR/responsiveness.csv" ]; then
    echo "$DIR already has a finished run. To measure again, run: scripts/measure.sh new"
    exit 0
  fi
  mkdir -p "$DIR"
  LOG="$DIR/run.log"
  trap cleanup EXIT
  trap 'exit 130' INT TERM

  log_system
  say "Audio output: $SINK"
  awk '$1 > 4 {print "Warning: the machine is already busy. Close other apps for a fair result."}' /proc/loadavg | tee -a "$LOG"

  run_cpu
  say "Starting the compile load on all $CORES threads"
  start_load
  run_audio
  run_responsiveness
  stop_load
  echo >>"$LOG"
  say "Finished, $(date '+%F %T')"
  echo
  write_summary
}

if [ "$(id -u)" = 0 ]; then
  echo "Run this as your normal user, not with sudo."
  exit 1
fi

DIR=$(results_dir)

case $MODE in
  run)
    keep_awake "$@"
    run_all
    ;;
  boot)
    run_boot
    ;;
  new)
    DIR="results/$OS-$(date +%F)"
    i=2
    while [ -e "$DIR" ]; do DIR="results/$OS-$(date +%F)-$i"; i=$((i + 1)); done
    mkdir -p "$DIR"
    echo "New results folder: $DIR"
    ;;
  *)
    sed -n '2,9p' "$SELF" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac
