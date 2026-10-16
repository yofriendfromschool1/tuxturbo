#!/usr/bin/env bash
#
#  ████████╗██╗   ██╗██╗  ██╗██████╗ ███████╗██████╗ ██╗  ██╗
#  ╚══██╔══╝██║   ██║██╔══██╗██╔════╝██╔══██╗██║  ██║
#     ██║   ██║   ██║██████╔╝██████╔╝█████╗  ██████╔╝███████║
#     ██║   ██║   ██║██╔══██╗██╔══██╗██╔══╝  ██╔═══╝ ╚════██║
#     ██║   ╚██████╔╝██║  ██║██║  ██║███████╗██║          ██║
#     ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝          ╚═╝
#
#  TuxTurbo v1.0.1 — Distro-aware interactive Linux performance tuner
#  https://github.com/YOURNAME/tuxturbo
#
#  WHAT THIS DOES:
#    • Detects your distro (Arch, Artix, Debian, Ubuntu, Mint, Pop!_OS, Fedora,
#      openSUSE, Gentoo, and more), your init system, CPU vendor, GPU, disks,
#      RAM, and laptop-vs-desktop.
#    • Walks you through ~26 curated performance tweaks ordered by difficulty,
#      showing for EACH one: what it does, pros, cons, risk, time estimate,
#      and difficulty PER DISTRO — then asks Y/N.
#    • Logs every change and generates an UNDO script automatically:
#        /var/backups/tuxturbo/undo-<timestamp>.sh
#
#  USAGE:
#    sudo ./tuxturbo.sh                 # interactive full tour
#    sudo ./tuxturbo.sh --dry-run       # preview only, change nothing
#    sudo ./tuxturbo.sh --only kernel,memory,gaming
#    ./tuxturbo.sh --list               # list all tweaks (no root needed)
#    sudo ./tuxturbo.sh --help
#
#  v1.0.1 changelog: fixed parse error in print_list (unquoted ';;' inside
#  [[ ]] is the case-statement token — bash syntax error), plus full
#  full lint audit pass and several runtime bug fixes. See git history.
#
#  SAFETY: take a snapshot first (Timeshift/snopper). You are the pilot.
#  MIT licensed. Zero warranty. Be excellent to each other.

# Associative arrays need bash >= 4
if (( BASH_VERSINFO[0] < 4 )); then
  echo "TuxTurbo needs bash >= 4 (you have ${BASH_VERSION})." >&2
  exit 1
fi

# NOTE: deliberately no -e — an interactive script must survive individual
# command failures and keep going.
set -uo pipefail

VERSION="1.0.1"

# ─────────────────────────────────────────────────────────────────────────────
# CLI FLAGS
# ─────────────────────────────────────────────────────────────────────────────
DRY_RUN=0
LIST_ONLY=0
ONLY_CATS=""

usage() {
  cat <<EOF
TuxTurbo v$VERSION — distro-aware interactive Linux performance tuner

USAGE:
  sudo ./tuxturbo.sh [OPTIONS]

OPTIONS:
  --dry-run          Preview every command without changing anything
  --list             List all tweaks with difficulty/category, then exit
  --only CATS        Comma-separated categories to run, e.g. kernel,memory
  --help             This help
  --version          Print version

CATEGORIES:
  housekeeping  memory  cpu  storage  network  kernel
  services      desktop gaming laptop

UNDO:
  Every session writes an undo script:
    sudo bash /var/backups/tuxturbo/undo-<timestamp>.sh
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --list)    LIST_ONLY=1 ;;
    --only)    ONLY_CATS="${2:-}"; shift ;;
    --help|-h) usage; exit 0 ;;
    --version) echo "TuxTurbo v$VERSION"; exit 0 ;;
    *) echo "Unknown option: $1 (try --help)"; exit 1 ;;
  esac
  shift
done

# ─────────────────────────────────────────────────────────────────────────────
# COLORS & OUTPUT HELPERS
# ─────────────────────────────────────────────────────────────────────────────
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  BOLD=$'\e[1m'; DIM=$'\e[2m'; RED=$'\e[31m'; GREEN=$'\e[32m'; YELLOW=$'\e[33m'
  BLUE=$'\e[34m'; MAGENTA=$'\e[35m'; CYAN=$'\e[36m'; RESET=$'\e[0m'
else
  BOLD=""; DIM=""; RED=""; GREEN=""; YELLOW=""; BLUE=""; MAGENTA=""; CYAN=""; RESET=""
fi

hr() {
  local out="" i
  for ((i=0; i<68; i++)); do out+="─"; done
  printf '%s\n' "$out"
}
info()    { printf '  %sℹ%s  %s\n' "$CYAN" "$RESET" "$*"; }
ok()      { printf '  %s✔%s  %s\n' "$GREEN" "$RESET" "$*"; }
warn()    { printf '  %s⚠%s  %s\n' "$YELLOW" "$RESET" "$*"; }
err()     { printf '  %s✘%s  %s\n' "$RED" "$RESET" "$*" >&2; }

wrap() { printf '%s\n' "$1" | fold -s -w 66 2>/dev/null | sed 's/^/   /'; }

# Print ';;'-separated items as a bulleted list.
# NOTE: we deliberately never put a bare ';;' inside [[ ]] — unquoted, it is
# lexed as the case-statement token and is a hard bash syntax error.
print_list() {
  local items="$1" bullet="$2" item
  while [[ -n "$items" ]]; do
    item="${items%%;;*}"
    printf '   %s %s\n' "$bullet" "$item"
    if [[ "$items" == "$item" ]]; then
      break   # no separator left — that was the last item
    fi
    items="${items#*;;}"
  done
}

# Execute a command (or just print it in dry-run)
run()   { printf '  %s$ %s%s\n' "$DIM" "$*" "$RESET"; (( DRY_RUN )) && return 0; "$@"; }
runsh() { printf '  %s$ %s%s\n' "$DIM" "$1" "$RESET";  (( DRY_RUN )) && return 0; bash -c "$1"; }

# Write stdin to a file (dry-run aware)
write_file() {
  local path="$1" content
  content="$(cat)"
  if (( DRY_RUN )); then
    printf '  %s[dry-run] would write %s:%s\n' "$DIM" "$path" "$RESET"
    printf '%s\n' "$content" | sed 's/^/      /'
    return 0
  fi
  mkdir -p "${path%/*}" 2>/dev/null || true
  printf '%s\n' "$content" > "$path" && ok "wrote $path"
}

# ─────────────────────────────────────────────────────────────────────────────
# STATE, BACKUPS & UNDO
# ─────────────────────────────────────────────────────────────────────────────
STATE_DIR="/var/backups/tuxturbo"
APPLIED_LOG="$STATE_DIR/applied.log"
UNDO_FILE=""
REQ_FAIL=""

init_state() { mkdir -p "$STATE_DIR"; chmod 700 "$STATE_DIR"; touch "$APPLIED_LOG"; }

begin_undo() {
  UNDO_FILE="$STATE_DIR/undo-$(date +%Y%m%d-%H%M%S).sh"
  {
    echo '#!/usr/bin/env bash'
    echo "# TuxTurbo undo script — generated $(date)"
    echo "# Review before running. Restores files/actions this session changed."
    echo "set -u"
  } > "$UNDO_FILE"
  chmod +x "$UNDO_FILE"
}
log_undo() {
  [[ -n "$UNDO_FILE" ]] || begin_undo
  printf '%s\n' "$*" >> "$UNDO_FILE"
}
backup_file() {
  local dest
  dest="$STATE_DIR/backup-$(date +%Y%m%d-%H%M%S)-$(basename "$1")"
  if cp -a "$1" "$dest"; then
    ok "backup saved: $dest"
  else
    err "could not back up $1"
    return 1
  fi
}
applied_date()    { awk -F'|' -v id="$1" '$2==id{print $1; exit}' "$APPLIED_LOG" 2>/dev/null; }
already_applied() { [[ -n "$(applied_date "$1")" ]]; }
mark_applied()    { echo "$(date +%F)|$1" >> "$APPLIED_LOG"; }

# ─────────────────────────────────────────────────────────────────────────────
# PROMPTS
# ─────────────────────────────────────────────────────────────────────────────
ask_yn() { # $1 prompt, $2 default (y/n) — returns 0=yes 1=no
  local prompt="$1" def="${2:-n}" ans hint
  if [[ "$def" == y ]]; then hint="Y/n"; else hint="y/N"; fi
  while true; do
    read -r -p "$(printf '   %s [%s]: ' "$prompt" "$hint")" ans || ans="$def"
    ans="${ans:-$def}"
    case "$ans" in
      [Yy]|[Yy][Ee][Ss]) return 0 ;;
      [Nn]|[Nn][Oo])     return 1 ;;
      *) echo "   Please answer y or n." ;;
    esac
  done
}
danger_confirm() {
  local ack=""
  read -r -p '   Type "I ACCEPT THE RISK" to proceed: ' ack || true
  [[ "${ack:-}" == "I ACCEPT THE RISK" ]]
}

# ─────────────────────────────────────────────────────────────────────────────
# ENVIRONMENT DETECTION
# ─────────────────────────────────────────────────────────────────────────────
DISTRO="unknown"; DISTRO_FAMILY="unknown"; DISTRO_LABEL="Linux"; PKGMAN="none"
INIT_NAME="init"; CPU_VENDOR="unknown"; CPU_MODEL=""; RAM_GB=0; HAS_SSD=0; IS_LAPTOP=0
GPU_INFO=""; KERNEL=""; DE="unknown"

has_systemd() { [[ -d /run/systemd/system ]]; }
is_laptop()   { compgen -G '/sys/class/power_supply/BAT*' >/dev/null 2>&1; }

detect_environment() {
  local f id like
  for f in /etc/os-release /usr/lib/os-release; do
    [[ -r "$f" ]] || continue
    # shellcheck disable=SC1090,SC1091
    . "$f"
    break
  done
  id="${ID:-}"
  like="${ID_LIKE:-}"
  DISTRO_LABEL="${NAME:-Linux}"

  case "$id" in
    arch)           DISTRO=arch;        DISTRO_FAMILY=arch ;;
    artix)          DISTRO=artix;       DISTRO_FAMILY=arch ;;
    cachyos)        DISTRO=cachyos;     DISTRO_FAMILY=arch ;;
    endeavour*)     DISTRO=endeavouros; DISTRO_FAMILY=arch ;;
    manjaro)        DISTRO=manjaro;     DISTRO_FAMILY=arch ;;
    debian)         DISTRO=debian;      DISTRO_FAMILY=debian ;;
    ubuntu)         DISTRO=ubuntu;      DISTRO_FAMILY=debian ;;
    linuxmint|linux_mint) DISTRO=mint;  DISTRO_FAMILY=debian ;;
    pop)            DISTRO=pop;         DISTRO_FAMILY=debian ;;
    elementary*|zorin|neon) DISTRO="$id"; DISTRO_FAMILY=debian ;;
    fedora)         DISTRO=fedora;      DISTRO_FAMILY=rpm ;;
    opensuse*)      DISTRO=opensuse;    DISTRO_FAMILY=rpm ;;
    gentoo|funtoo)  DISTRO=gentoo;      DISTRO_FAMILY=gentoo ;;
    clear-linux-os) DISTRO=clear;       DISTRO_FAMILY=clear ;;
    alpine)         DISTRO=alpine;      DISTRO_FAMILY=apk ;;
    void)           DISTRO=void;        DISTRO_FAMILY=void ;;
    nixos)          DISTRO=nixos;       DISTRO_FAMILY=nix ;;
    "") # No os-release — fingerprint the old way
      if   [[ -e /etc/artix-release ]]; then DISTRO=artix;  DISTRO_FAMILY=arch
      elif [[ -e /etc/arch-release  ]]; then DISTRO=arch;   DISTRO_FAMILY=arch
      elif [[ -e /etc/debian_version ]]; then DISTRO=debian;DISTRO_FAMILY=debian
      elif [[ -e /etc/gentoo-release ]]; then DISTRO=gentoo;DISTRO_FAMILY=gentoo
      elif [[ -e /etc/fedora-release ]]; then DISTRO=fedora; DISTRO_FAMILY=rpm
      elif [[ -d /var/db/repos/gentoo || -d /usr/portage ]]; then DISTRO=gentoo; DISTRO_FAMILY=gentoo
      else DISTRO=lfs; DISTRO_FAMILY=lfs; DISTRO_LABEL="Linux From Scratch (or unknown)"; fi ;;
    *) DISTRO="$id"; DISTRO_FAMILY="unknown" ;;
  esac
  # Fallback via ID_LIKE
  if [[ "$DISTRO_FAMILY" == unknown && -n "$like" ]]; then
    [[ "$like" == *arch*   ]] && DISTRO_FAMILY=arch
    [[ "$like" == *debian* ]] && DISTRO_FAMILY=debian
    [[ "$like" == *rhel* || "$like" == *fedora* ]] && DISTRO_FAMILY=rpm
    [[ "$like" == *suse*   ]] && DISTRO_FAMILY=rpm
  fi

  # Package manager
  local pm
  for pm in apt-get pacman dnf zypper xbps-install apk emerge nix-env; do
    if command -v "$pm" >/dev/null 2>&1; then PKGMAN="$pm"; break; fi
  done
  [[ "$DISTRO_FAMILY" == debian && -x /usr/bin/apt-get ]] && PKGMAN=apt-get

  INIT_NAME=$(cat /proc/1/comm 2>/dev/null) || INIT_NAME="init"

  CPU_VENDOR=$(awk '/^vendor_id/{print $3; exit}' /proc/cpuinfo 2>/dev/null)
  CPU_MODEL=$(awk -F': *' '/^model name/{print $2; exit}' /proc/cpuinfo 2>/dev/null)
  RAM_GB=$(awk '/MemTotal/{printf "%d", $2/1024/1024; exit}' /proc/meminfo 2>/dev/null)
  KERNEL=$(uname -r)
  GPU_INFO=$(lspci 2>/dev/null | grep -Ei 'vga|3d controller|display' | head -2 | sed 's/^[0-9:.]* //')
  [[ -z "$GPU_INFO" ]] && GPU_INFO="not detected"

  local rota
  while read -r rota _; do
    [[ "$rota" == 0 ]] && HAS_SSD=1
  done < <(lsblk -d -n -o ROTA 2>/dev/null)

  is_laptop && IS_LAPTOP=1

  local d
  for d in gnome-shell plasmashell xfce4-session lxqt-session cinnamon-session mate-session i3 sway Hyprland; do
    if pgrep -x "$d" >/dev/null 2>&1; then DE="$d"; break; fi
  done
}

pkg_install() {
  case "$PKGMAN" in
    apt-get)       run env DEBIAN_FRONTEND=noninteractive apt-get install -y "$@" ;;
    pacman)        run pacman -S --needed --noconfirm "$@" ;;
    dnf)           run dnf install -y "$@" ;;
    zypper)        run zypper --non-interactive install "$@" ;;
    xbps-install)  run xbps-install -y "$@" ;;
    apk)           run apk add "$@" ;;
    emerge)        run emerge "$@" ;;
    *)             err "No supported package manager to install: $*"; return 1 ;;
  esac
}
pkg_remove() {
  case "$PKGMAN" in
    apt-get)      run env DEBIAN_FRONTEND=noninteractive apt-get remove -y "$@" ;;
    pacman)       run pacman -Rns --noconfirm "$@" ;;
    dnf)          run dnf remove -y "$@" ;;
    zypper)       run zypper --non-interactive remove "$@" ;;
    emerge)       run emerge --deselect "$@" ;;
    *)            err "No supported package manager to remove: $*"; return 1 ;;
  esac
}
svc_enable()  { if has_systemd; then run systemctl enable --now "$1"; else warn "enable '$1' manually for your init ($INIT_NAME)"; fi; }
svc_disable() { if has_systemd; then run systemctl disable --now "$1"; else warn "disable '$1' manually for your init ($INIT_NAME)"; fi; }

# ─────────────────────────────────────────────────────────────────────────────
# TWEAK CATALOG
#   reg <id> <name> <diff> <cat> <risk> <time> <req> <desc> <pros> <cons> <diffnote>
#   pros/cons use ';;' between items. req: systemd|laptop|intel|arch|ssd (space-sep)
# ─────────────────────────────────────────────────────────────────────────────
declare -A TW_NAME TW_DIFF TW_CAT TW_RISK TW_TIME TW_REQ TW_DESC TW_PROS TW_CONS TW_NOTE
TW_ORDER=()

reg() {
  TW_ORDER+=("$1")
  TW_NAME[$1]="$2"; TW_DIFF[$1]="$3"; TW_CAT[$1]="$4"; TW_RISK[$1]="$5"
  TW_TIME[$1]="$6"; TW_REQ[$1]="$7"; TW_DESC[$1]="$8"; TW_PROS[$1]="$9"
  TW_CONS[$1]="${10}"; TW_NOTE[$1]="${11}"
}

register_catalog() {

  # ── housekeeping ──────────────────────────────────────────────────────────
  reg update "Full system update" EASY housekeeping LOW "~2-20 min" "" \
    "Brings kernel, drivers, compilers and libraries to their newest versions. The cheapest performance you will ever get — a huge share of 'my Linux got slow' reports are fixed by this alone." \
    "Bug fixes and scheduler/driver improvements;;Newer kernels often mean better CPU/GPU power management;;Security fixes cost nothing" \
    "Occasional regressions between releases;;Download (and on Gentoo, compile) time" \
    "Debian/Ubuntu 🟢 · Arch 🟢 · Fedora 🟢 · Gentoo 🟡 (world rebuild) · LFS 💀 (you are the updater)"

  reg clean "Remove orphans & package caches" EASY housekeeping LOW "~3 min" "" \
    "Cleans orphaned packages and package-manager caches, shrinking your system and speeding up package operations." \
    "Frees disk space;;Smaller/faster package operations;;Less cruft to update" \
    "Review the orphan list before accepting — it can rarely remove something you wanted" \
    "Debian/Ubuntu 🟢 · Arch 🟢 · Fedora 🟢 · Gentoo 🟡 (depclean is more powerful AND more dangerous) · LFS 💀"

  reg microcode "Install CPU microcode" EASY housekeeping LOW "~2 min" "" \
    "Installs your CPU vendor's microcode updates (loaded at boot). Fixes stability bugs and security errata; occasionally improves turbo behavior." \
    "Stability and security fixes for your exact CPU;;Free, invisible once installed" \
    "Very rare microcode revisions caused boot issues — keep a fallback kernel entry" \
    "Debian/Ubuntu 🟢 · Arch 🟢 · Fedora 🟢 (preinstalled) · Gentoo 🟡 · LFS 💀 (manual /boot install)"

  # ── memory ────────────────────────────────────────────────────────────────
  reg swappiness "Tune vm.swappiness & cache pressure" EASY memory LOW "~1 min" "" \
    "vm.swappiness controls how eagerly the kernel swaps app memory to disk (default 60). vfs_cache_pressure controls reclaiming filesystem metadata cache. Desktops with >=8GB RAM feel snappier with swappiness 10." \
    "Apps stay resident in RAM instead of being swapped out;;More predictable desktop response under load" \
    "Subtle on machines with lots of RAM;;If you enable zram, you may actually want swappiness 100-180 instead — zram is fast" \
    "🟢 everywhere (one drop-in file)"

  reg zram "Enable zram — compressed RAM swap" EASY memory LOW "~3 min" "systemd" \
    "Creates a compressed block device inside RAM and uses it as swap. Swapping happens at RAM speed with no disk IO. Fedora ships this by default; most other distros don't." \
    "Swap at RAM speed — no disk IO under memory pressure;;Less SSD wear;;Effectively 1.5-2x usable RAM on 4-16GB machines" \
    "Small CPU cost when compressing;;Not a substitute for real RAM;;Complicates hibernation (needs disk swap);;If zswap is active you should disable it (instructions shown)" \
    "Debian/Ubuntu 🟢 (one package) · Arch 🟢 · Fedora 🟢 (often pre-enabled) · Gentoo 🟡 · Artix 🟡 (init-dependent) · LFS 💀"

  reg earlyoom "Install earlyoom (anti-freeze guard)" EASY memory LOW "~2 min" "" \
    "A tiny daemon that kills the biggest memory hog BEFORE the system starts thrashing. You lose one tab instead of the whole desktop session." \
    "System stays responsive under memory pressure;;Trivial to remove" \
    "It WILL kill an unsaved app at the worst moment if you run out of RAM — save your work" \
    "Debian/Ubuntu 🟢 · Arch 🟢 · Fedora 🟢 (or use preinstalled systemd-oomd) · Gentoo 🟡 · LFS 💀"

  reg tmpfs "Mount /tmp as tmpfs (RAM)" MEDIUM memory MEDIUM "~3 min" "systemd" \
    "Puts /tmp on a RAM filesystem. Temp files are written at RAM speed and never touch (or wear) your SSD." \
    "Much faster temp IO (compiles, builds, some app caches);;Less SSD wear" \
    "Large temp files eat RAM — on low-RAM machines this can OOM you;;Contents of /tmp vanish on reboot (by design)" \
    "systemd distros 🟢 · Artix 🟡 · Gentoo 🟡 · LFS 💀"

  # ── cpu ───────────────────────────────────────────────────────────────────
  reg governor "Set CPU governor to performance" EASY cpu MEDIUM "~2 min" "" \
    "CPU governors decide how fast your clocks ramp. 'performance' pins CPUs at maximum frequency. On modern amd-pstate/intel_pstate hardware, schedutil is often 95% as good — check what you have." \
    "Instant max clock — lower latency, most consistent FPS;;Great for plugged-in desktops" \
    "More heat and power — laptops on battery will suffer;;On some hardware the difference is near-zero" \
    "Debian/Ubuntu 🟢 · Arch 🟢 · Fedora 🟢 · Gentoo 🟢 · LFS 🟡 (write sysfs in your init)"

  reg ananicy "ananicy-cpp — auto-prioritize background apps" MEDIUM cpu LOW "~3 min" "arch" \
    "A rules daemon that automatically lowers the priority of background hogs (compilers, indexers, backups) so your foreground apps stay buttery. CachyOS popularized it." \
    "Foreground responsiveness with zero manual renice;;Set-and-forget" \
    "Occasionally misclassifies an app;;One more daemon" \
    "Arch/CachyOS 🟢 (package) · Debian/Fedora 🟡 (build from source) · Gentoo 🟡 · LFS 💀"

  reg irqbalance "IRQ strategy (off for gaming latency)" MEDIUM cpu MEDIUM "~2 min" "systemd" \
    "irqbalance spreads hardware interrupts across CPUs — great for servers. On a dedicated gaming box, disabling it (and letting your game's cores breathe) can reduce jitter." \
    "OFF: fewer interrupt migrations → lower jitter in latency-sensitive games;;ON (default): better balance under heavy IO" \
    "OFF: can hurt throughput if you also compile/serve on the same machine;;This is a tuning choice, not an upgrade" \
    "🟡 everywhere — decide per machine role"

  # ── storage ───────────────────────────────────────────────────────────────
  reg fstrim "Enable periodic SSD TRIM" EASY storage LOW "~1 min" "ssd" \
    "Enables the weekly fstrim timer. TRIM lets your SSD maintain write performance over its lifetime." \
    "Sustains SSD write speed for years;;Zero cost (weekly, seconds)" \
    "None worth mentioning — this is table stakes for SSDs" \
    "🟢 everywhere with systemd + SSD"

  reg noatime "Add noatime to filesystem mounts" MEDIUM storage LOW "~5 min" "" \
    "By default Linux updates a file's access time on every read. noatime removes those writes. (Modern relatime already skips most of them, so expect a modest gain.)" \
    "Fewer disk writes on every file read;;Slightly faster metadata-heavy workloads" \
    "Editing /etc/fstab wrong can break boot — this tool backs it up and shows a diff first;;Apps that need atime (rare, e.g. old mutt setups) use relatime instead" \
    "🟢 everywhere (one file edit + reboot)"

  reg journal "Cap journald log size" EASY storage LOW "~2 min" "systemd" \
    "Caps the systemd journal at 100MB instead of letting it grow to 10% of your filesystem. Less disk churn and space." \
    "Less background IO and disk usage;;Faster journald on huge logs" \
    "Less log history for debugging" \
    "systemd distros 🟢 · Artix ❌ (no journald) · LFS 💀"

  reg iosched "Per-device I/O schedulers (udev rule)" MEDIUM storage LOW "~5 min" "" \
    "Sets the right scheduler per device class: 'none' for NVMe (lowest overhead), 'mq-deadline' for SATA SSDs, 'bfq' for spinning HDDs (dramatically better interactivity during copies)." \
    "BFQ on HDDs = desktop stays usable during big copies;;none on NVMe = max IOPS, less CPU" \
    "Micro-management — wrong mapping can hurt throughput;;Takes effect on next device event/boot" \
    "🟢–🟡 everywhere (one udev rule file)"

  # ── network ───────────────────────────────────────────────────────────────
  reg bbr "TCP BBR + network sysctls" EASY network LOW "~2 min" "" \
    "Switches TCP congestion control to Google's BBR with the fq qdisc, enables TCP Fast Open, and raises socket buffers. Sustains throughput far better on lossy/wireless links." \
    "Faster, steadier downloads on Wi-Fi/lossy links;;Faster connection setup (fastopen);;Set-and-forget" \
    "Oversized buffers waste RAM if you go beyond the suggested values;;BBRv1 fairness debates (irrelevant on desktops)" \
    "🟢 everywhere (all modern kernels ship BBR)"

  # ── kernel ────────────────────────────────────────────────────────────────
  reg watchdog "Disable kernel watchdogs" MEDIUM kernel MEDIUM "~2 min" "" \
    "The NMI watchdog generates constant interrupts to detect hangs. On a desktop it is dead weight (small but real CPU/latency cost)." \
    "Fewer interrupts → small latency and CPU win" \
    "A hard-hung system will no longer be detected — do NOT do this on servers" \
    "🟢 everywhere (sysctl drop-in; full effect wants the nowatchdog boot param — instructions shown)"

  reg altkernel "Install an alternative performance kernel" HARD kernel MEDIUM "~10-40 min" "" \
    "Installs a desktop/latency-tuned kernel BESIDE your stock one (stock stays as fallback). Options depend on distro: linux-zen (Arch), backports/Liquorix/XanMod (Debian family), linux-lowlatency (Ubuntu), dist-kernel vs sources (Gentoo)." \
    "1000Hz tick, desktop preemption, tuned schedulers — ~the easy 80% of a custom kernel;;Installed side-by-side; your old kernel stays in the boot menu" \
    "Third-party kernels need trust;;Occasional DKMS/NVIDIA module friction;;You must keep up with updates" \
    "Arch 🟢 (official repos) · Ubuntu/Mint 🟢–🟡 (PPA) · Debian 🟡 (backports) · Fedora 🟡 · Gentoo 🟡 (it's normal there) · LFS 💀 (it IS the custom kernel)"

  reg makepkg "makepkg -march=native (AUR builds)" MEDIUM kernel MEDIUM "~5 min" "arch" \
    "Replaces the generic -march=x86-64 compiler flags in /etc/makepkg.conf with -march=native, so every AUR package you build is optimized for YOUR exact CPU." \
    "Typical 1-10% gain in anything you build from AUR;;One-line config change" \
    "Only affects packages YOU build — official binaries stay generic;;Built packages are no longer portable to other machines" \
    "Arch 🟢 (one file) · Gentoo 🟢 (this is literally the default there) · Debian 🔴 (not practical) · LFS 💀 (you set it in your own toolchain)"

  reg mitigations "mitigations=off — disable CPU exploit mitigations" HARD kernel EXTREME "~5 min + reboot" "" \
    "Disables kernel workarounds for Spectre/Meltdown/Retbleed-class CPU vulnerabilities. Often yields 5-30% more CPU performance on syscall-heavy work. THIS RE-EXPOSES YOUR MACHINE TO KNOWN CPU EXPLOITS." \
    "One of the biggest single CPU performance gains available — 5-30% depending on workload;;Lower syscall/interrupt latency" \
    "SECURITY: every browser tab is untrusted code running on your CPU;;Reasonable ONLY on offline gaming/benchmark rigs — NOT daily internet machines;;Middle ground: mitigations=auto" \
    "Difficulty 🟡 on every distro (one boot param) — the DECISION is what's hard"

  reg kernelguide "GUIDE: compiling a custom kernel" GUIDE kernel LOW "~10 min read" "" \
    "Prints the full custom-kernel walkthrough (localmodconfig, menuconfig performance options, march=native build, install, keeping a fallback). The deepest performance rabbit hole available." \
    "Leanest possible kernel for your exact hardware;;-march=native kernel code, no debug bloat, MGLRU, 1000Hz;;Smaller attack surface, faster boot" \
    "Hours per build;;YOU own every future security recompile;;DKMS/NVIDIA may complicate" \
    "Arch 🟡 · Gentoo 🟡 (normal Tuesday) · Debian 🟡–🔴 · Fedora 🔴 · LFS 💀 (the whole point)"

  # ── services ──────────────────────────────────────────────────────────────
  reg services "Interactive boot & service audit" MEDIUM services MEDIUM "~10 min" "systemd" \
    "Shows your slowest boot units (systemd-analyze blame + critical-chain), then offers to disable well-known safe candidates one by one — printing what each does before asking." \
    "Boot time often drops 30-50%;;Less background RAM/CPU noise" \
    "Disabling something you actually need breaks it (printing, bluetooth, mDNS);;Some candidates (apt timers) mean YOU must update manually" \
    "systemd distros 🟢–🟡 · Artix 🟡 (your init's service manager) · LFS 💀"

  # ── desktop ───────────────────────────────────────────────────────────────
  reg vaapi "GUIDE: hardware video decoding (VAAPI)" MANUAL desktop LOW "~2 min read" "" \
    "Prints how to make your browser decode video on the GPU instead of the CPU — 10-20x less CPU during YouTube, less heat, more thermal headroom for everything else." \
    "Massive CPU reduction during video playback;;Cooler machine = more sustained boost for real work" \
    "Browser flags vary by version and are occasionally glitchy with exotic codecs" \
    "🟡 everywhere (driver + browser flags)"

  # ── gaming ────────────────────────────────────────────────────────────────
  reg gamemode "Install Feral GameMode" EASY gaming LOW "~2 min" "" \
    "A daemon that flips your system into 'gaming mode' (performance governor, priority tweaks) while a game runs and restores everything after." \
    "Automatic performance governor during games;;Zero configuration once set in Steam launch options" \
    "Only affects games launched through it (gamemoderun %command%)" \
    "Debian/Ubuntu 🟢 · Arch 🟢 · Fedora 🟢 · Gentoo 🟡 · LFS 💀"

  reg mangohud "Install MangoHud (perf overlay)" EASY gaming LOW "~2 min" "" \
    "The standard in-game performance overlay: FPS, frametime, 1% lows, CPU/GPU temps & usage. Not a speedup itself — it's how you PROVE every other tweak worked." \
    "See real gains (1% lows!) instead of guessing;;Tiny overhead" \
    "Adds a (toggleable) overlay" \
    "Debian/Ubuntu 🟢 · Arch 🟢 · Fedora 🟢 · Gentoo 🟡 · LFS 💀"

  # ── laptop ────────────────────────────────────────────────────────────────
  reg tlp "Install TLP (laptop power management)" EASY laptop LOW "~3 min" "laptop" \
    "TLP applies battery-saving profiles (USB autosuspend, PCIe ASPM, Wi-Fi powersave). Cooler laptop = more SUSTAINED boost clocks. Conflicts with power-profiles-daemon (handled if detected)." \
    "20-40% battery life on many laptops;;Cooler & quieter = sustained performance when plugged in" \
    "Desktops gain nothing (this card only appears on laptops);;Occasionally quirks with exotic peripherals on autosuspend" \
    "Debian/Ubuntu 🟢 · Arch 🟢 · Fedora 🟢 · Gentoo 🟡 · LFS 💀"

  reg thermald "Install thermald (Intel thermal mgmt)" EASY laptop LOW "~2 min" "intel" \
    "Intel's daemon that distributes heat more intelligently across cores, avoiding hard throttle cliffs on Intel machines." \
    "Fewer nasty thermal throttle cliffs = steadier performance;;Free and invisible" \
    "Intel CPUs only (this card is hidden otherwise);;Marginal on machines with good cooling" \
    "Debian/Ubuntu 🟢 · Arch 🟢 · Fedora 🟢 · Gentoo 🟡 · LFS 💀"
}

# ─────────────────────────────────────────────────────────────────────────────
# APPLY FUNCTIONS
#   return 0 = applied · 2 = manual instructions shown · 3 = user declined
#   anything else = failure
# ─────────────────────────────────────────────────────────────────────────────

apply_update() {
  case "$PKGMAN" in
    apt-get)
      run env DEBIAN_FRONTEND=noninteractive apt-get update
      run env DEBIAN_FRONTEND=noninteractive apt-get full-upgrade -y
      ;;
    pacman)  run pacman -Syu --noconfirm ;;
    dnf)     run dnf upgrade -y --refresh ;;
    zypper)  run zypper --non-interactive refresh; run zypper --non-interactive dup ;;
    emerge)  run emerge --sync; run emerge -uDN @world ;;
    *)       err "No supported package manager detected — update manually."; return 2 ;;
  esac
}

apply_clean() {
  case "$PKGMAN" in
    apt-get)
      run env DEBIAN_FRONTEND=noninteractive apt-get autoremove --purge -y
      run env DEBIAN_FRONTEND=noninteractive apt-get clean
      ;;
    pacman)
      local orphans
      orphans=$(pacman -Qtdq 2>/dev/null || true)
      if [[ -n "$orphans" ]]; then
        # Intentional word splitting: pacman wants the package list as separate args.
        # shellcheck disable=SC2086
        run pacman -Rns --noconfirm $orphans
      else
        info "No orphans found."
      fi
      if command -v paccache >/dev/null 2>&1; then
        run paccache -rk2
      fi
      run pacman -Sc --noconfirm
      ;;
    dnf)
      run dnf autoremove -y
      run dnf clean all
      ;;
    zypper)
      run zypper --non-interactive clean --all
      ;;
    emerge)
      info "Gentoo: consider 'emerge --depclean' manually (powerful but needs review)."
      return 2
      ;;
    *)
      return 2
      ;;
  esac
}

apply_microcode() {
  case "$DISTRO_FAMILY" in
    debian)
      if [[ "$CPU_VENDOR" == GenuineIntel ]]; then pkg_install intel-microcode; else pkg_install amd64-microcode; fi
      ;;
    arch)
      if [[ "$CPU_VENDOR" == GenuineIntel ]]; then pkg_install intel-ucode; else pkg_install amd-ucode; fi
      ;;
    rpm)
      if [[ "$DISTRO" == opensuse ]]; then
        if [[ "$CPU_VENDOR" == GenuineIntel ]]; then
          pkg_install ucode-intel
        else
          info "AMD microcode ships with kernel-firmware on openSUSE."
        fi
      else
        info "Fedora: microcode ships inside linux-firmware — nothing to install."
      fi
      ;;
    gentoo)
      if [[ "$CPU_VENDOR" == GenuineIntel ]]; then
        pkg_install sys-apps/intel-microcode
      else
        info "AMD microcode rides along in sys-kernel/linux-firmware on Gentoo."
        pkg_install sys-kernel/linux-firmware
      fi
      ;;
    *)
      err "Install microcode manually for this distro (see README 1.2)."
      return 2
      ;;
  esac
  info "Reboot to load, then verify with: dmesg | grep -i microcode"
}

apply_swappiness() {
  write_file /etc/sysctl.d/99-tuxturbo-memory.conf <<'EOF' || return 1
# TuxTurbo: desktop memory tuning
vm.swappiness = 10
vm.vfs_cache_pressure = 50
EOF
  run sysctl --system
  ok "swappiness now: $(sysctl -n vm.swappiness 2>/dev/null || echo '?')"
  log_undo "# revert swappiness tweak"
  log_undo "rm -f /etc/sysctl.d/99-tuxturbo-memory.conf && sysctl --system"
  if zramctl 2>/dev/null | grep -q zram0; then
    warn "zram detected — consider vm.swappiness=100-180 instead (zram is fast; swapping to it is GOOD). Edit the file to taste."
  fi
}

apply_zram() {
  if zramctl 2>/dev/null | grep -q zram; then
    ok "zram is already active:"
    zramctl
    return 0
  fi
  if [[ "$(cat /sys/module/zswap/parameters/enabled 2>/dev/null)" == "Y" ]]; then
    warn "zswap is active. Stacking zram+zswap is wasteful."
    info "Disable zswap by adding 'zswap.enabled=0' to your kernel command line, then re-run."
  fi
  case "$DISTRO_FAMILY" in
    debian)
      if (( DRY_RUN )); then
        echo "  ${DIM}[dry-run] would: apt install systemd-zram-generator (fallback: zram-tools)${RESET}"
      else
        env DEBIAN_FRONTEND=noninteractive apt-get install -y systemd-zram-generator 2>/dev/null \
          || env DEBIAN_FRONTEND=noninteractive apt-get install -y zram-tools \
          || { err "no zram package available"; return 1; }
      fi
      ;;
    arch) pkg_install zram-generator ;;
    rpm)   info "Fedora-class: zram normally ships by default — enabling via config below." ;;
    *)     err "Install zram support manually for this distro (README 1.4)."; return 2 ;;
  esac
  if [[ "$DISTRO_FAMILY" == debian ]] && dpkg -s zram-tools >/dev/null 2>&1; then
    write_file /etc/default/zramswap <<'EOF'
ALGO=zstd
PERCENT=50
EOF
    runsh "systemctl restart zramswap 2>/dev/null || true"
    log_undo "# revert zram (zram-tools)"
    log_undo "systemctl disable --now zramswap; rm -f /etc/default/zramswap"
  else
    write_file /etc/systemd/zram-generator.conf <<'EOF'
[zram0]
zram-size = min(ram / 2, 4096)
compression-algorithm = zstd
EOF
    run systemctl daemon-reload
    run systemctl start systemd-zram-setup@zram0.service
    log_undo "# revert zram"
    log_undo "swapoff /dev/zram0 2>/dev/null; systemctl stop systemd-zram-setup@zram0.service 2>/dev/null; rm -f /etc/systemd/zram-generator.conf; systemctl daemon-reload"
  fi
  info "Verify with: zramctl"
}

apply_earlyoom() {
  pkg_install earlyoom || return 1
  svc_enable earlyoom
  log_undo "# revert earlyoom"
  log_undo "systemctl disable --now earlyoom"
}

apply_tmpfs() {
  if [[ "$(findmnt -n -o FSTYPE /tmp 2>/dev/null)" == "tmpfs" ]]; then
    ok "/tmp is already tmpfs"
    return 0
  fi
  run systemctl unmask tmp.mount
  run systemctl enable --now tmp.mount
  info "Size defaults to ~50% of RAM. To cap it, create a drop-in with Options=size=4G (see README 2.3)."
  log_undo "# revert tmpfs /tmp"
  log_undo "systemctl disable --now tmp.mount"
}

apply_governor() {
  if [[ ! -e /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]]; then
    err "No cpufreq interface (VM or exotic platform) — governor not manageable here."
    return 2
  fi
  local prev_gov avail
  prev_gov=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
  avail=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors 2>/dev/null)
  info "Current governor: $prev_gov | available: ${avail:-unknown}"
  if [[ "$avail" != *performance* ]]; then
    warn "'performance' not available on this driver — schedutil/powersave only. Skipping."
    return 2
  fi
  write_file /etc/systemd/system/tuxturbo-governor.service <<EOF
[Unit]
Description=TuxTurbo: set performance CPU governor
[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor'
[Install]
WantedBy=multi-user.target
EOF
  run systemctl daemon-reload
  svc_enable tuxturbo-governor.service
  log_undo "# revert governor to '$prev_gov'"
  log_undo "systemctl disable --now tuxturbo-governor.service; rm -f /etc/systemd/system/tuxturbo-governor.service; echo $prev_gov | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor"
  ok "Governor set to performance (re-applies at boot)."
}

apply_ananicy() {
  if [[ "$DISTRO_FAMILY" == arch ]]; then
    pkg_install ananicy-cpp || return 1
    svc_enable ananicy-cpp.service
    log_undo "# revert ananicy-cpp"
    log_undo "systemctl disable --now ananicy-cpp.service"
  else
    info "Non-Arch: build from https://github.com/zavgan/ananicy-cpp (cmake)."
    return 2
  fi
}

apply_irqbalance() {
  if ! has_systemd; then
    info "Manual: decide irqbalance per your init's service manager."
    return 2
  fi
  if systemctl is-active --quiet irqbalance 2>/dev/null; then
    if ask_yn "irqbalance is RUNNING. Disable it for gaming-latency (say NO on servers)?" "n"; then
      run systemctl disable --now irqbalance
      log_undo "# re-enable irqbalance"
      log_undo "systemctl enable --now irqbalance"
    else
      info "Kept irqbalance enabled (good choice for general use)."
    fi
  else
    info "irqbalance is not running — nothing to do."
  fi
}

apply_fstrim() {
  run systemctl enable --now fstrim.timer
  info "Verify: systemctl list-timers fstrim.timer"
  log_undo "# revert fstrim timer"
  log_undo "systemctl disable --now fstrim.timer"
}

apply_noatime() {
  [[ -f /etc/fstab ]] || { err "No /etc/fstab found."; return 1; }
  local tmp
  tmp=$(mktemp)
  awk '{
    if ($1 !~ /^#/ && $3 ~ /^(ext[234]|xfs|btrfs|f2fs)$/ && $4 !~ /(^|,)noatime(,|$)/) {
      $4 = $4 ",noatime"
    }
    print
  }' /etc/fstab > "$tmp"
  if diff -q /etc/fstab "$tmp" >/dev/null; then
    info "No candidate mounts to change (already noatime, or unsupported fs)."
    rm -f "$tmp"
    return 0
  fi
  echo
  info "Proposed /etc/fstab changes:"
  diff /etc/fstab "$tmp" || true
  if ! ask_yn "Apply these fstab changes?" "n"; then
    rm -f "$tmp"
    info "Skipped."
    return 3
  fi
  backup_file /etc/fstab || { rm -f "$tmp"; return 1; }
  if (( DRY_RUN )); then
    echo "  ${DIM}[dry-run] would install the new fstab${RESET}"
    rm -f "$tmp"
    return 0
  fi
  cat "$tmp" > /etc/fstab
  rm -f "$tmp"
  ok "fstab updated. Remount or reboot to activate."
  log_undo "# restore fstab (noatime) — replace path with your backup if moved"
  log_undo "# cp $STATE_DIR/backup-*-fstab /etc/fstab"
}

apply_journal() {
  write_file /etc/systemd/journald.conf.d/tuxturbo.conf <<'EOF'
[Journal]
SystemMaxUse=100M
EOF
  run systemctl restart systemd-journald
  log_undo "# revert journald cap"
  log_undo "rm -f /etc/systemd/journald.conf.d/tuxturbo.conf; systemctl restart systemd-journald"
}

apply_iosched() {
  write_file /etc/udev/rules.d/60-tuxturbo-iosched.rules <<'EOF'
# TuxTurbo: per-device I/O schedulers
# NVMe -> none (least overhead) | SATA SSD -> mq-deadline | spinning HDD -> bfq
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
ACTION=="add|change", KERNEL=="mmcblk[0-9]*", ATTR{queue/scheduler}="bfq"
EOF
  run udevadm control --reload-rules
  run udevadm trigger
  info "Current schedulers (rule persists across boots):"
  local d
  for d in /sys/block/*/queue/scheduler; do
    [[ -e "$d" ]] || continue
    printf '     %s: %s\n' "$d" "$(cat "$d" 2>/dev/null)"
  done
  log_undo "# revert I/O scheduler rule"
  log_undo "rm -f /etc/udev/rules.d/60-tuxturbo-iosched.rules; udevadm control --reload-rules"
}

apply_bbr() {
  local avail
  avail=$(sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null || true)
  if [[ "$avail" != *bbr* ]]; then
    runsh "modprobe tcp_bbr 2>/dev/null || true"
    avail=$(sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null || true)
  fi
  if [[ "$avail" != *bbr* ]]; then
    err "Kernel lacks BBR (very old kernel?) — update first."
    return 1
  fi
  write_file /etc/sysctl.d/99-tuxturbo-network.conf <<'EOF' || return 1
# TuxTurbo: network tuning
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_slow_start_after_idle = 0
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.core.somaxconn = 1024
EOF
  run sysctl --system
  ok "congestion control now: $(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)"
  log_undo "# revert network tuning"
  log_undo "rm -f /etc/sysctl.d/99-tuxturbo-network.conf && sysctl --system"
}

apply_watchdog() {
  write_file /etc/sysctl.d/99-tuxturbo-watchdog.conf <<'EOF' || return 1
# TuxTurbo: disable NMI watchdog (desktop)
kernel.nmi_watchdog = 0
EOF
  run sysctl --system
  info "For the full effect, also add 'nowatchdog' to your kernel cmdline (see README 2.5)."
  log_undo "# revert watchdog tweak"
  log_undo "rm -f /etc/sysctl.d/99-tuxturbo-watchdog.conf && sysctl --system"
}

apply_altkernel() {
  case "$DISTRO_FAMILY:$DISTRO" in
    arch:*)
      echo
      info "Options: [1] linux-zen (official)  [2] linux-lts (fallback)  [3] linux-hardened  [4] AUR/custom instructions"
      local c=""
      read -r -p "   Choose [1-4]: " c || c=""
      c="${c:-4}"
      case "$c" in
        1) pkg_install linux-zen linux-zen-headers || return 1 ;;
        2) pkg_install linux-lts linux-lts-headers || return 1 ;;
        3) pkg_install linux-hardened linux-hardened-headers || return 1 ;;
        4) info "AUR (needs yay/paru): linux-cachyos (BORE+LTO), linux-tkg-* (pick your scheduler)."
           info "Or add the CachyOS repos: https://cachyos.org — x86-64-v3 optimized."
           return 2 ;;
        *) info "No valid choice — skipping."; return 3 ;;
      esac
      ok "Kernel installed BESIDE your current one — both stay in the boot menu."
      ;;
    debian:debian)
      echo
      info "Options: [1] backports kernel  [2] Liquorix  [3] XanMod  [4] skip"
      local c="" codename
      read -r -p "   Choose [1-4]: " c || c=""
      c="${c:-4}"
      codename=$(grep -m1 '^VERSION_CODENAME=' /etc/os-release | cut -d= -f2)
      if [[ -z "$codename" ]]; then
        err "Could not detect Debian codename from /etc/os-release."
        return 1
      fi
      case "$c" in
        1) write_file /etc/apt/sources.list.d/backports.list <<EOF || return 1
deb http://deb.debian.org/debian ${codename}-backports main non-free-firmware
EOF
           run env DEBIAN_FRONTEND=noninteractive apt-get update
           run env DEBIAN_FRONTEND=noninteractive apt-get install -y -t "${codename}-backports" linux-image-amd64 || return 1
           log_undo "# remove backports source"
           log_undo "rm -f /etc/apt/sources.list.d/backports.list && apt-get update"
           ;;
        2) info "Liquorix (https://liquorix.net): add their repo per their instructions, then:"
           info "  sudo apt install linux-image-liquorix-amd64 linux-headers-liquorix-amd64"
           return 2 ;;
        3) info "XanMod (https://xanmod.org): verify current key instructions on the site, then:"
           info "  sudo apt install linux-xanmod-x64v3"
           return 2 ;;
        *) info "Skipped."; return 3 ;;
      esac
      ;;
    debian:*)
      echo
      info "Options: [1] linux-lowlatency (official Ubuntu)  [2] XanMod  [3] mainline kernels (GUI)  [4] skip"
      local c=""
      read -r -p "   Choose [1-4]: " c || c=""
      c="${c:-4}"
      case "$c" in
        1) pkg_install linux-lowlatency linux-lowlatency-headers || return 1
           ok "Installed beside your current kernel — both stay in the boot menu." ;;
        2) info "XanMod: https://xanmod.org — verify current key instructions there, then:"
           info "  sudo apt install linux-xanmod-x64v3"
           return 2 ;;
        3) info "Mainline GUI: sudo add-apt-repository ppa:cappelikan/ppa && sudo apt install mainline-gtk"
           return 2 ;;
        *) info "Skipped."; return 3 ;;
      esac
      ;;
    rpm:*)
      info "Fedora-class kernels are always fresh. Optional: sudo dnf install kernel-rt (real-time)."
      info "For XanMod-style gains, read the Kernel Chapter in the README."
      return 2
      ;;
    gentoo:*)
      echo
      info "Options: [1] gentoo-kernel (auto-maintained — easy mode)  [2] gentoo-sources + manual (the true way)"
      local c=""
      read -r -p "   Choose [1/2]: " c || c=""
      c="${c:-2}"
      case "$c" in
        1) pkg_install gentoo-kernel || return 1 ;;
        2) pkg_install gentoo-sources || return 1
           info "Then: cd /usr/src/linux && make localmodconfig && make menuconfig && make -j\$(nproc)"
           info "Full walkthrough: README → Kernel Chapter."
           return 2 ;;
        *) return 3 ;;
      esac
      ;;
    *)
      info "No automated kernel install for this distro — see README Kernel Chapter."
      return 2
      ;;
  esac
}

apply_makepkg() {
  [[ -f /etc/makepkg.conf ]] || { err "No /etc/makepkg.conf (not Arch-family?)"; return 1; }
  backup_file /etc/makepkg.conf || return 1
  if (( DRY_RUN )); then
    echo "  ${DIM}[dry-run] would set CFLAGS/CXXFLAGS to -march=native -O2 -pipe -fno-plt${RESET}"
    return 0
  fi
  sed -i \
    -e 's|^CFLAGS=.*|CFLAGS="-march=native -O2 -pipe -fno-plt"|' \
    -e 's|^CXXFLAGS=.*|CXXFLAGS="-march=native -O2 -pipe -fno-plt"|' \
    /etc/makepkg.conf
  ok "makepkg.conf updated — future AUR builds compile for YOUR cpu."
  log_undo "# restore makepkg.conf — replace path with your backup"
  log_undo "# cp $STATE_DIR/backup-*-makepkg.conf /etc/makepkg.conf"
}

apply_mitigations() {
  echo
  printf '   %s%s!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!%s\n' "$RED" "$BOLD" "$RESET"
  printf '   %s%s!!  MITIGATIONS=OFF RE-EXPOSES KNOWN CPU VULNERABILITIES !!%s\n' "$RED" "$BOLD" "$RESET"
  printf '   %s%s!!  (Spectre / Meltdown / L1TF / Retbleed class)          !!%s\n' "$RED" "$BOLD" "$RESET"
  printf '   %s%s!!  ONLY sensible on offline gaming/benchmark machines.  !!%s\n' "$RED" "$BOLD" "$RESET"
  printf '   %s%s!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!%s\n' "$RED" "$BOLD" "$RESET"
  echo
  info "Current exposure status (before any change):"
  grep -r . /sys/devices/system/cpu/vulnerabilities/ 2>/dev/null | head -10 | sed 's/^/     /'
  echo
  if ! danger_confirm; then
    info "Wise choice. Nothing changed."
    return 3
  fi
  if [[ -d /boot/loader/entries ]] || { command -v bootctl >/dev/null 2>&1 && bootctl status 2>/dev/null | grep -q 'systemd-boot'; }; then
    info "systemd-boot detected — manual edit needed:"
    info "  add 'mitigations=off' to /etc/kernel/cmdline (or your loader entry), then reboot"
    return 2
  fi
  if [[ "$DISTRO" == fedora ]]; then
    run grubby --update-kernel=ALL --args="mitigations=off"
    log_undo "# revert mitigations=off"
    log_undo 'grubby --update-kernel=ALL --remove-args="mitigations=off"'
  else
    [[ -f /etc/default/grub ]] || { err "No /etc/default/grub found."; return 1; }
    if grep -q 'mitigations=off' /etc/default/grub; then
      ok "mitigations=off already present in GRUB config."
    else
      backup_file /etc/default/grub || return 1
      if (( DRY_RUN )); then
        echo "  ${DIM}[dry-run] would append mitigations=off to GRUB_CMDLINE_LINUX_DEFAULT${RESET}"
        return 0
      fi
      if grep -q '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub; then
        sed -i -E 's|^(GRUB_CMDLINE_LINUX_DEFAULT="[^"]*)"|\1 mitigations=off"|' /etc/default/grub
      else
        echo 'GRUB_CMDLINE_LINUX_DEFAULT="quiet mitigations=off"' >> /etc/default/grub
      fi
      if command -v update-grub >/dev/null 2>&1; then
        run update-grub
      else
        run grub-mkconfig -o /boot/grub/grub.cfg
      fi
    fi
    log_undo "# revert mitigations=off (grub)"
    log_undo "sed -i -E 's|^(GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*) mitigations=off|\1|' /etc/default/grub && (update-grub || grub-mkconfig -o /boot/grub/grub.cfg)"
  fi
  warn "Reboot required. Expect 5-30% more CPU perf — and a much larger attack surface."
}

apply_kernelguide() {
  cat <<'EOF'

   CUSTOM KERNEL — THE WALKTHROUGH (condensed)
   ───────────────────────────────────────────
   0. Snapshot your system. Plug in every peripheral you use.
   1. Get sources:   Arch: asp checkout linux (or kernel.org tarball)
                     Debian: apt install linux-source
                     Gentoo: emerge gentoo-sources
   2. Seed config:   cd linux-*/
                        make localmodconfig      # leanest: only loaded modules
                     (or start from distro: zcat /proc/config.gz > .config)
   3. Tune:          make menuconfig
                        * Preemption → "Fully preemptible (low-latency desktop)"
                        * Timer frequency → 1000 Hz
                        * CONFIG_LRU_GEN=y (+ENABLED)  (MGLRU)
                        * Kernel hacking → turn ALL debug off
                        * Filesystems → only the ones you use
   4. Build:         KCFLAGS="-march=native" make -j$(nproc)
   5. Install:       sudo make modules_install && sudo make install
                     (Debian alternative: make bindeb-pkg && apt install ./linux-image*.deb)
   6. Bootloader:    regenerate (grub-mkconfig / keep old entries!)
   7. Reboot with BOTH kernels available. Keep the stock one ~2 weeks.

   Full details + .config cheat sheet: see README → Kernel Chapter.
EOF
  return 2
}

apply_services() {
  echo
  info "Your slowest boot units:"
  systemd-analyze blame 2>/dev/null | head -12 | sed 's/^/     /'
  echo
  info "Critical chain:"
  systemd-analyze critical-chain --no-pager 2>/dev/null | head -12 | sed 's/^/     /'
  echo
  local candidates=(
    "NetworkManager-wait-online.service|Waits for network at boot; commonly adds 5-15s. Safe to disable on desktops/laptops.|"
    "ModemManager.service|Manages cellular modems. Disable if you never use mobile broadband.|"
    "cups.service|Printing subsystem. Disable if you never print.|"
    "cups-browsed.service|Auto-discovery of network printers.|"
    "bluetooth.service|Disable if you never use Bluetooth.|"
    "avahi-daemon.service|mDNS/.local discovery (network printers, device discovery).|"
    "apport.service|Ubuntu crash reporter.|apt"
    "speech-dispatcherd.service|Speech dispatcher (screen readers / TTS).|"
    "apt-daily.timer|Background apt downloads (Debian/Ubuntu). Disabling = manual updates!|apt"
    "apt-daily-upgrade.timer|Background apt upgrades (Debian/Ubuntu). Disabling = manual updates!|apt"
    "man-db.timer|Nightly man-page cache rebuild. Reschedules the cost to your first man call.|"
    "plocate-updatedb.timer|Nightly file-index rebuild (locate).|"
  )
  local entry svc rest desc only enabled active
  for entry in "${candidates[@]}"; do
    svc="${entry%%|*}"
    rest="${entry#*|}"
    desc="${rest%%|*}"
    only="${rest##*|}"
    if [[ -n "$only" && "$PKGMAN" != *"$only"* ]]; then
      continue
    fi
    if systemctl list-unit-files "$svc" 2>/dev/null | grep -q "^$svc"; then
      enabled=$(systemctl is-enabled "$svc" 2>/dev/null || true)
      active=$(systemctl is-active "$svc" 2>/dev/null || true)
      if [[ "$enabled" == enabled || "$active" == active ]]; then
        echo
        info "$svc — $desc"
        if ask_yn "Disable $svc?" "n"; then
          run systemctl disable --now "$svc"
          log_undo "# re-enable $svc"
          log_undo "systemctl enable --now $svc"
        fi
      fi
    fi
  done
  info "Audit complete. Reboot & compare with: systemd-analyze"
}

apply_vaapi() {
  cat <<'EOF'

   HARDWARE VIDEO DECODE (VAAPI) — HOW TO
   ───────────────────────────────────────
   1. Install drivers:
        Intel: sudo apt install intel-media-va-driver-non-free libva-utils
        AMD:   sudo apt install mesa-va-drivers libva-utils
        (Arch: intel-media-driver / libva-mesa-driver + libva-utils)
   2. Verify hardware decode paths exist:    vainfo
   3. Browser:
        Chromium: enable "Hardware-accelerated video decode" flag
        Firefox:  about:config → media.ffmpeg.vaapi.enabled = true
   4. Watch CPU% drop during 4K YouTube (check with htop).
EOF
  return 2
}

apply_gamemode() {
  pkg_install gamemode || return 1
  if [[ "$PKGMAN" == pacman ]] && grep -q '^\[multilib\]' /etc/pacman.conf 2>/dev/null; then
    pkg_install lib32-gamemode
  fi
  cat <<'EOF'

   USAGE: add to Steam launch options:
        gamemoderun %command%
   Verify it's active in-game:  gamemoded -s
EOF
}

apply_mangohud() {
  pkg_install mangohud || return 1
  if [[ "$PKGMAN" == pacman ]] && grep -q '^\[multilib\]' /etc/pacman.conf 2>/dev/null; then
    pkg_install lib32-mangohud
  fi
  cat <<'EOF'

   USAGE: Steam launch options →   mangohud %command%
   Toggle overlay (default): Shift_R + F12
   Watch 1% LOW frametime — that's what tweaks actually improve.
EOF
}

apply_tlp() {
  if has_systemd && systemctl is-active --quiet power-profiles-daemon 2>/dev/null; then
    warn "power-profiles-daemon is active and conflicts with TLP."
    if ask_yn "Disable power-profiles-daemon first?" "y"; then
      run systemctl disable --now power-profiles-daemon
      log_undo "# re-enable power-profiles-daemon (was disabled for TLP)"
      log_undo "systemctl enable --now power-profiles-daemon"
    else
      info "TLP skipped (conflict)."
      return 3
    fi
  fi
  pkg_install tlp || return 1
  svc_enable tlp
  log_undo "# revert TLP"
  log_undo "systemctl disable --now tlp"
}

apply_thermald() {
  pkg_install thermald || return 1
  svc_enable thermald
  log_undo "# revert thermald"
  log_undo "systemctl disable --now thermald"
}

# ─────────────────────────────────────────────────────────────────────────────
# REQUIREMENT CHECKS
# ─────────────────────────────────────────────────────────────────────────────
check_req() {
  local r
  [[ -n "${1:-}" ]] || return 0
  for r in $1; do
    case "$r" in
      systemd) has_systemd || { REQ_FAIL="requires systemd (this machine boots $INIT_NAME)"; return 1; } ;;
      laptop)  (( IS_LAPTOP )) || { REQ_FAIL="laptops only (no battery detected)"; return 1; } ;;
      intel)   [[ "$CPU_VENDOR" == GenuineIntel ]] || { REQ_FAIL="Intel CPUs only (you have ${CPU_VENDOR:-unknown})"; return 1; } ;;
      arch)    [[ "$DISTRO_FAMILY" == arch ]] || { REQ_FAIL="Arch-family only (you're on $DISTRO_LABEL)"; return 1; } ;;
      ssd)     (( HAS_SSD )) || { REQ_FAIL="no SSD detected"; return 1; } ;;
    esac
  done
  return 0
}

# ─────────────────────────────────────────────────────────────────────────────
# UI: CARD PRINTER & RUNNER
# ─────────────────────────────────────────────────────────────────────────────
diff_icon() {
  case "$1" in
    EASY)   echo "🟢" ;;
    MEDIUM) echo "🟡" ;;
    HARD)   echo "🔴" ;;
    *)      echo "📘" ;;
  esac
}
risk_txt() {
  case "$1" in
    LOW)     echo "${GREEN}LOW${RESET}" ;;
    MEDIUM)  echo "${YELLOW}MEDIUM${RESET}" ;;
    HIGH)    echo "${RED}HIGH${RESET}" ;;
    EXTREME) echo "${RED}${BOLD}EXTREME${RESET}" ;;
    *)       echo "$1" ;;
  esac
}

print_card() {
  local id="$1" idx="$2" total="$3"
  local d="${TW_DIFF[$id]}"
  hr
  printf '  %s%s%s/%s · %s%s%s\n' "$BOLD" "$idx" "$RESET" "$total" "$BOLD" "${TW_NAME[$id]}" "$RESET"
  printf '  %sdifficulty:%s %s %-7s  %srisk:%s %s  %stime:%s %s  %scategory:%s %s%s%s\n' \
    "$DIM" "$RESET" "$(diff_icon "$d")" "$d" \
    "$DIM" "$RESET" "$(risk_txt "${TW_RISK[$id]}")" \
    "$DIM" "$RESET" "${TW_TIME[$id]}" \
    "$MAGENTA" "$RESET" "${TW_CAT[$id]}" "$MAGENTA" "$RESET"
  if [[ -n "${TW_REQ[$id]}" ]]; then
    printf '  %srequires:%s %s\n' "$DIM" "$RESET" "${TW_REQ[$id]}"
  fi
  echo
  printf '  %sWhat it does%s\n' "$BOLD" "$RESET"
  wrap "${TW_DESC[$id]}"
  echo
  printf '  %s%sPros%s\n' "$GREEN" "$BOLD" "$RESET"
  print_list "${TW_PROS[$id]}" "${GREEN}+${RESET}"
  echo
  printf '  %s%sCons%s\n' "$RED" "$BOLD" "$RESET"
  print_list "${TW_CONS[$id]}" "${RED}-${RESET}"
  echo
  printf '  %sDifficulty by distro:%s\n' "$DIM" "$RESET"
  wrap "${TW_NOTE[$id]}"
}

APPLIED=(); MANUAL=(); FAILED=(); DECLINED=(); SKIPPED=0; QUIT=0

run_tweaks() {
  local cats=("$@")
  local ids=() id c
  for id in "${TW_ORDER[@]}"; do
    for c in "${cats[@]}"; do
      if [[ "${TW_CAT[$id]}" == "$c" ]]; then
        ids+=("$id")
      fi
    done
  done
  local total=${#ids[@]} count=0 rc
  for id in "${ids[@]}"; do
    (( QUIT )) && break
    ((count++))
    if ! check_req "${TW_REQ[$id]}"; then
      echo
      info "SKIP [${id}] — $REQ_FAIL"
      continue
    fi
    echo
    print_card "$id" "$count" "$total"
    if already_applied "$id"; then
      warn "You already applied this on $(applied_date "$id") — re-applying is usually safe/idempotent."
    fi
    local ans
    read -r -p "$(printf '   %sApply this tweak?%s [y/N] (q=quit): ' "$BOLD" "$RESET")" ans || ans="n"
    case "${ans:-n}" in
      [Yy]|[Yy][Ee][Ss])
        if declare -f "apply_$id" >/dev/null; then
          "apply_$id"
          rc=$?
          case $rc in
            0) ok "✔ applied: ${TW_NAME[$id]}"; APPLIED+=("$id"); mark_applied "$id" ;;
            2) info "📘 instructions printed above — manual step"; MANUAL+=("$id"); mark_applied "$id" ;;
            3) info "⤼ declined — nothing changed"; DECLINED+=("$id") ;;
            *) err "✘ '$id' did not complete (exit $rc) — see output above"; FAILED+=("$id") ;;
          esac
        else
          err "internal: no apply_$id function"
          FAILED+=("$id")
        fi
        ;;
      [Qq]) QUIT=1 ;;
      *) ((SKIPPED++)) ;;
    esac
  done
}

# ─────────────────────────────────────────────────────────────────────────────
# BANNER / REPORT / SUMMARY
# ─────────────────────────────────────────────────────────────────────────────
ALL_CATS=(housekeeping memory cpu storage network kernel services desktop gaming laptop)

print_banner() {
  cat <<EOF

  ${CYAN}${BOLD}██╗██╗   ██╗██╗  ██╗██████╗ ███████╗██████╗ ██╗  ██╗${RESET}
  ${CYAN}${BOLD}██║██║   ██║██║  ██║██╔══██╗██╔════╝██╔══██╗██║  ██║${RESET}
  ${CYAN}${BOLD}██║██║   ██║██████╔╝██████╔╝█████╗  ██████╔╝███████║${RESET}
  ${CYAN}${BOLD}██║██║   ██║██╔══██╗██╔══██╗██╔══╝  ██╔═══╝ ╚════██║${RESET}
  ${CYAN}${BOLD}██║╚██████╔╝██║  ██║██║  ██║███████╗██║          ██║${RESET}
  ${CYAN}${BOLD}╚═╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝          ╚═╝${RESET}
  ${DIM}v$VERSION — distro-aware interactive performance tuner${RESET}
EOF
}

print_system_report() {
  hr
  echo "  ${BLUE}${BOLD}SYSTEM REPORT${RESET}"
  printf '   Distro      : %s (%s family)\n' "$DISTRO_LABEL" "$DISTRO_FAMILY"
  printf '   Package mgr : %s\n' "$PKGMAN"
  printf '   Init        : %s%s\n' "$INIT_NAME" "$( if has_systemd; then echo ' (systemd)'; fi )"
  printf '   Kernel      : %s\n' "$KERNEL"
  printf '   CPU         : %s\n' "${CPU_MODEL:-$CPU_VENDOR}"
  printf '   RAM         : %s GB\n' "$RAM_GB"
  printf '   GPU         : %s\n' "$GPU_INFO"
  local storage="HDD only" machine="desktop/server"
  if (( HAS_SSD )); then storage="SSD detected"; fi
  if (( IS_LAPTOP )); then machine="laptop"; fi
  printf '   Storage     : %s\n' "$storage"
  printf '   Machine     : %s\n' "$machine"
  printf '   Desktop     : %s\n' "$DE"
  hr
  if [[ "$DISTRO" == nixos ]]; then
    warn "NixOS detected: config lives in configuration.nix — use this script's suggestions as RECIPE, not commands."
  fi
  warn "Take a snapshot first (Timeshift/snapper). An undo script is auto-generated for every session."
}

choose_categories() {
  if [[ -n "$ONLY_CATS" ]]; then
    # NOTE: capture the space-joined list BEFORE changing IFS, or the join
    # would use commas and never match.
    local c valid=() all="${ALL_CATS[*]}"
    local IFS=','
    for c in $ONLY_CATS; do
      if [[ " $all " == *" $c "* ]]; then
        valid+=("$c")
      else
        err "Unknown category: $c"
      fi
    done
    if (( ${#valid[@]} == 0 )); then
      err "No valid categories. Try --help"
      exit 1
    fi
    SELECTED_CATS=("${valid[@]}")
    return
  fi
  echo "  ${BOLD}Categories${RESET}: ${ALL_CATS[*]}"
  if ask_yn "Run the FULL tour (all categories)?" "y"; then
    SELECTED_CATS=("${ALL_CATS[@]}")
    return
  fi
  SELECTED_CATS=()
  local c2
  for c2 in "${ALL_CATS[@]}"; do
    if ask_yn "  Include category '$c2'?" "n"; then
      SELECTED_CATS+=("$c2")
    fi
  done
  if (( ${#SELECTED_CATS[@]} == 0 )); then
    info "Nothing selected — bye!"
    exit 0
  fi
}

list_tweaks() {
  hr
  printf '  %-14s %-10s %-14s %s\n' "CATEGORY" "DIFFICULTY" "ID" "TWEAK"
  hr
  local id
  for id in "${TW_ORDER[@]}"; do
    printf '  %-14s %-10s %-14s %s\n' "${TW_CAT[$id]}" "$(diff_icon "${TW_DIFF[$id]}") ${TW_DIFF[$id]}" "$id" "${TW_NAME[$id]}"
  done
  hr
  echo "  Run: sudo ./tuxturbo.sh --only <categories>   |   --dry-run to preview"
}

finalize() {
  echo
  hr
  echo "  ${BOLD}SESSION SUMMARY${RESET}"
  printf '   ✔ Applied  : %d\n' "${#APPLIED[@]}"
  for id in "${APPLIED[@]:-}"; do [[ -n "$id" ]] && printf '       • %s\n' "${TW_NAME[$id]}"; done
  printf '   📘 Manual  : %d\n' "${#MANUAL[@]}"
  for id in "${MANUAL[@]:-}"; do [[ -n "$id" ]] && printf '       • %s\n' "${TW_NAME[$id]}"; done
  printf '   ⤼ Declined : %d\n' "${#DECLINED[@]}"
  for id in "${DECLINED[@]:-}"; do [[ -n "$id" ]] && printf '       • %s\n' "${TW_NAME[$id]}"; done
  printf '   ✘ Failed   : %d\n' "${#FAILED[@]}"
  for id in "${FAILED[@]:-}"; do [[ -n "$id" ]] && printf '       • %s\n' "${TW_NAME[$id]}"; done
  printf '   ⤼ Skipped  : %d\n' "$SKIPPED"
  if [[ -n "$UNDO_FILE" ]]; then
    echo
    warn "UNDO script for this session:"
    printf '       %s\n' "$UNDO_FILE"
    printf '   Run it with: %s\n' "sudo bash $UNDO_FILE"
    echo "   Backups live in: $STATE_DIR"
  fi
  echo
  if (( ${#APPLIED[@]} > 0 )); then
    warn "Reboot recommended for kernel/boot/sysctl changes to fully apply."
    info "Benchmark after reboot and compare:"
    echo "       systemd-analyze            # boot time"
    echo "       zramctl                    # zram status"
    echo "       sysctl vm.swappiness net.ipv4.tcp_congestion_control"
    echo "       s-tui                      # thermals under load"
  fi
  echo
  echo "  ${DIM}TuxTurbo — drive it like you stole it. 🏁 Star the repo if this helped.${RESET}"
  hr
}

on_interrupt() { echo; warn "Interrupted — finalizing so you keep your undo script."; QUIT=1; }

# ─────────────────────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────────────────────
main() {
  # --list needs no root
  if (( LIST_ONLY )); then
    register_catalog
    list_tweaks
    exit 0
  fi

  if [[ $EUID -ne 0 ]]; then
    if command -v sudo >/dev/null 2>&1; then
      info "Not root — re-execing with sudo..."
      exec sudo "$0" "$@"
    fi
    err "Please run as root (sudo)."
    exit 1
  fi

  init_state
  detect_environment
  register_catalog
  print_banner
  print_system_report

  if (( DRY_RUN )); then
    warn "DRY RUN — nothing will actually be changed."
  fi

  choose_categories
  trap on_interrupt INT
  run_tweaks "${SELECTED_CATS[@]}"
  finalize
}

main "$@"
