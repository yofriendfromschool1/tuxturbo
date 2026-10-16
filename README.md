<div align="center">

# 🐧⚡ TuxTurbo

### The ultimate, distro-aware guide & toolkit to squeeze **every last drop** of performance out of your Linux machine.

[![GitHub stars](https://img.shields.io/github/stars/yofriendfromschool1/tuxturbo?style=for-the-badge&logo=github)](https://github.com/yofriendfromschool1/tuxturbo/stargazers)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)](LICENSE)
[![ShellCheck](https://img.shields.io/github/actions/workflow/status/yofriendfromschool1/tuxturbo/shellcheck.yml?label=shellcheck&style=for-the-badge)](https://github.com/yofriendfromschool1/tuxturbo/actions)
[![Platform](https://img.shields.io/badge/platform-Linux-1793D1?style=for-the-badge&logo=linux&logoColor=white)]()
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen?style=for-the-badge)](CONTRIBUTING.md)

**100+ tweaks · 10 distros · kernels, sysctls, schedulers, I/O, boot, network, gaming & laptops**

*Debian · Ubuntu · Mint · Pop!_OS · Arch · Artix · CachyOS/EndeavourOS · Fedora · openSUSE · Gentoo · LFS*

</div>

---

> ## ⚠️ READ THIS FIRST
> Tweaks marked 🔴/💀 trade **security or stability** for speed. Always:
> 1. **Take a snapshot first** (Timeshift, snapper, or btrfs snapshot),
> 2. **Benchmark before & after** (see [📊 Benchmark first](#-benchmark-first-do-this-before-anything)),
> 3. **Keep a fallback kernel/boot entry** before installing custom kernels.
>
> This repo is MIT-licensed and comes with **zero warranty**. You are the pilot.

---

## 📖 Table of Contents

- [⚡ The 80/20 — if you only do 5 things](#-the-8020--if-you-only-do-5-things)
- [🚀 Quick start (the script)](#-quick-start-the-script)
- [📊 Benchmark first — do this before anything](#-benchmark-first--do-this-before-anything)
- [🏷️ Difficulty & risk legend](#%EF%B8%8F-difficulty--risk-legend)
- [🗺️ Same tweak, different pain — difficulty by distro](#%EF%B8%8F-same-tweak-different-pain--difficulty-by-distro)
- [🟢 Universal tweaks — Tier 1: Easy](#-universal-tweaks--tier-1-easy)
- [🟡 Universal tweaks — Tier 2: Intermediate](#-universal-tweaks--tier-2-intermediate)
- [🔴 Universal tweaks — Tier 3: Advanced](#-universal-tweaks--tier-3-advanced)
- [💀 Universal tweaks — Tier 4: Expert / Reckless](#-universal-tweaks--tier-4-expert--reckless)
- [🐧 Distro chapters](#-distro-chapters) (Debian, Ubuntu, Mint, Pop!_OS, Arch, Artix, CachyOS/EndeavourOS, Fedora, openSUSE, Gentoo, LFS, honorable mentions)
- [🧠 The Kernel Chapter](#-the-kernel-chapter) (prebuilt kernels, schedulers, custom build walkthrough, `.config` cheat sheet, cmdline reference)
- [⚙️ sysctl reference tables](#%EF%B8%8F-sysctl-reference-tables)
- [🖥️ Desktop & GPU](#%EF%B8%8F-desktop--gpu)
- [🎮 Gaming](#-gaming)
- [💻 Laptops](#-laptops)
- [🔩 Hardware — the REAL performance](#-hardware--the-real-performance)
- [⏱️ Boot-time reduction checklist](#%EF%B8%8F-boot-time-reduction-checklist)
- [↩️ Rollback & the undo system](#%EF%B8%8F-rollback--the-undo-system)
- [🧙 Myths & snake oil](#-myths--snake-oil)
- [❓ FAQ](#-faq)
- [🤝 Contributing](#-contributing)
- [📜 License & Credits](#-license--credits)

---

## ⚡ The 80/20 — if you only do 5 things

1. **Update everything + install CPU microcode** → [1.1](#11-update-everything) & [1.2](#12-cpu-microcode)
2. **Enable zram** → [1.4](#14-zram--compressed-ram-swap)
3. **Audit your boot & disable junk services** → [1.9](#19-boot--service-audit)
4. **Set swappiness + I/O schedulers** → [1.3](#13-vmswappiness--vfs_cache_pressure) & [2.1](#21-io-scheduler-per-device)
5. **Profile your thermals** → if you're thermal throttling, *no* software tweak matters. See [💻 Laptops](#-laptops).

---

## 🚀 Quick start (the script)

The interactive script **detects your distro, CPU, GPU, disks, RAM, init system**, then walks you through every tweak — showing **difficulty, risk, pros, cons and difficulty-per-distro** — and asks **Y/N** for each. Every change is logged and an **undo script is generated automatically**.

```bash
git clone https://github.com/yofriendfromschool1/tuxturbo.git
cd tuxturbo
chmod +x tuxturbo.sh

sudo ./tuxturbo.sh                 # full interactive tour
sudo ./tuxturbo.sh --dry-run       # preview everything, change nothing
sudo ./tuxturbo.sh --only kernel,memory,gaming
./tuxturbo.sh --list               # see every tweak + difficulty
```

> 💡 Don't `curl | bash` this — it's interactive and needs your terminal's stdin. Download it first.

**Undo everything you did in a session:**

```bash
sudo bash /var/backups/tuxturbo/undo-<timestamp>.sh
```

---

## 📊 Benchmark first — do this before anything

Numbers before ego. Save results to a file so you can prove your gains later.

```bash
mkdir -p ~/benchmarks && cd ~/benchmarks

# Boot time
systemd-analyze | tee boot-before.txt
systemd-analyze blame | head -25
systemd-analyze critical-chain

# CPU / thermals (watch for throttling during load!)
sudo apt install s-tui stress || sudo pacman -S s-tui stress
s-tui -j                       # run + stress, screenshot it

# Storage
fio --name=rand --filename=/tmp/fio --size=1G --bs=4k --rw=randrw \
    --iodepth=32 --direct=1 --runtime=30 --group_reporting | tee fio-before.txt

# Network
iperf3 -c <server> | tee net-before.txt

# Real-world apps & games
hyperfine 'your-app --version'        # app launch timing
# Games: use MangoHud (see Gaming chapter) — log 1% lows, not just avg FPS

# Full suite (the gold standard)
sudo apt install phoronix-test-suite || sudo pacman -S phoronix-test-suite
phoronix-test-suite benchmark pts/disk pts/cpu
```

| Goal | Tools |
|---|---|
| Boot time | `systemd-analyze`, `bootchart` |
| Latency | `cyclictest` (`rt-tests`), `latencytop` |
| CPU/thermal | `s-tui`, `turbostat`, `stress-ng` |
| Disk | `fio`, `kdisks`/`iostat`, `io.zone` |
| GPU/Games | `MangoHud`, `glmark2`, `vkmark`, `superposition` |
| Network | `iperf3`, `ping`, `mtr` |

---

## 🏷️ Difficulty & risk legend

| Difficulty | Meaning | Risk | Meaning |
|---|---|---|---|
| 🟢 **Easy** | copy-paste, minutes | 🟢 **LOW** | trivially reversible |
| 🟡 **Medium** | config files, reboot | 🟡 **MED** | functionality tradeoff |
| 🔴 **Hard** | compiling, deep config | 🔴 **HIGH** | stability/security tradeoff |
| 💀 **Very Hard** | you ARE the maintainer | 💀 **EXTREME** | may eat your homework |

---

## 🗺️ Same tweak, different pain — difficulty by distro

| Task | Debian/Ubuntu/Mint | Arch/Artix | Fedora | Gentoo | LFS |
|---|---|---|---|---|---|
| sysctl / service tweaks | 🟢 | 🟢 | 🟢 | 🟢 | 🟡 |
| zram | 🟢 (pkg) | 🟢 (pkg) | 🟢 (default!) | 🟡 | 💀 |
| Alternative kernel | 🟡 (PPA/repo) | 🟢 (repo/AUR) | 🟡 | 🟡 (natural, slow) | 💀 |
| Custom kernel config | 🔴 | 🟡 | 🔴 | 🟡 (it's the norm) | 💀 (it's the point) |
| `-march=native` binaries | 🔴 (rare) | 🟡 (rebuilds / v3 repos) | 🔴 | 🟢 (**the default**) | 💀 |
| Init system choice | ❌ | 🟡 (Artix!) | ❌ | 🟡 | 💀 |

---

# 🟢 Universal tweaks — Tier 1: Easy

*(Ordered from least to most involved. All distros unless noted.)*

---

### 1.1 Update everything
**Difficulty 🟢 · Risk 🟢 · 2–20 min**

```bash
# Debian/Ubuntu/Mint/Pop        # Arch/Artix              # Fedora                  # openSUSE                # Gentoo
sudo apt update && \
sudo apt full-upgrade            sudo pacman -Syu          sudo dnf upgrade          sudo zypper dup           sudo emerge --sync && \
                                                                                                               sudo emerge -avuDN @world
```

- ✅ **Pros:** bug fixes, driver improvements, scheduler fixes, security patches — the cheapest perf you'll ever get.
- ❌ **Cons:** occasional regressions; download time.
- **Difficulty by distro:** identical everywhere 🟢 (Gentoo: compile time 🟡).

---

### 1.2 CPU microcode
**Difficulty 🟢 · Risk 🟢 · 1 min**

```bash
# Intel                          # AMD
sudo apt install intel-microcode  sudo apt install amd64-microcode     # Debian family
sudo pacman -S intel-ucode        sudo pacman -S amd-ucode             # Arch family
# Fedora: ships in linux-firmware (nothing to do) — Gentoo: sys-apps/intel-microcode
```
Reboot, then verify: `dmesg | grep -i microcode`

- ✅ **Pros:** stability fixes, security fixes, sometimes better turbo behavior. Free.
- ❌ **Cons:** very rarely a microcode revision causes boot issues — keep a fallback kernel.
- **Difficulty by distro:** Debian/Ubuntu/Arch 🟢 · Fedora 🟢 (preinstalled) · Gentoo 🟡 · LFS 💀 (manual install to `/boot`).

---

### 1.3 `vm.swappiness` & `vfs_cache_pressure`
**Difficulty 🟢 · Risk 🟢 · 1 min**

```bash
sudo tee /etc/sysctl.d/99-perf.conf >/dev/null <<'EOF'
vm.swappiness = 10
vm.vfs_cache_pressure = 50
EOF
sudo sysctl --system
```

- ✅ **Pros:** desktops with ≥8 GB RAM stay snappier — the kernel prefers evicting cache over swapping apps out.
- ❌ **Cons:** barely noticeable with lots of RAM; **if you use zram, you may actually want `vm.swappiness=100–180`** (zram is fast — see 1.4).
- **Difficulty by distro:** 🟢 everywhere.

---

### 1.4 Zram — compressed RAM swap
**Difficulty 🟢 · Risk 🟢 · 3 min**

```bash
# Arch/Artix
sudo pacman -S zram-generator
# Debian/Ubuntu/Mint/Pop (older releases: sudo apt install zram-tools)
sudo apt install systemd-zram-generator

sudo tee /etc/systemd/zram-generator.conf >/dev/null <<'EOF'
[zram0]
zram-size = min(ram / 2, 4096)
compression-algorithm = zstd
EOF
sudo systemctl daemon-reload && sudo systemctl start systemd-zram-setup@zram0.service
zramctl   # verify
```
> Fedora 33+ and Ubuntu 25.04+ ship zram **by default** — check with `zramctl` first. If `zswap` is active, disable it (kernel param `zswap.enabled=0`) so you don't stack two compressed caches.

| | zram | zswap | disk swap |
|---|---|---|---|
| Speed | ⚡ RAM-speed | ⚡ fast (compressed, RAM) | 🐢 disk |
| Needs disk swap | no | **yes** | is one |
| Hibernation | no | yes (via backing) | yes |

- ✅ **Pros:** swap at RAM speed; less SSD wear; effectively 1.5–2× usable RAM on 4–16 GB machines; far better under memory pressure.
- ❌ **Cons:** slight CPU cost when compressing; not a substitute for real RAM; complicates hibernation.
- **Difficulty by distro:** Debian/Ubuntu/Arch/Fedora 🟢 · Gentoo 🟡 · Artix 🟡 (init-dependent) · LFS 💀.

---

### 1.5 Periodic TRIM (SSDs)
**Difficulty 🟢 · Risk 🟢 · 1 min**

```bash
sudo systemctl enable --now fstrim.timer
systemctl list-timers fstrim.timer
```

- ✅ **Pros:** sustains write performance over the SSD's life; free longevity.
- ❌ **Cons:** none real. (Prefer weekly `fstrim` over the continuous `discard` mount option — the latter can add latency.)
- **Difficulty by distro:** 🟢 everywhere (systemd distros).

---

### 1.6 `noatime` mount flag
**Difficulty 🟡 · Risk 🟢 · 5 min**

Edit `/etc/fstab`, add `noatime` to the options of your `ext4`/`xfs`/`btrfs`/`f2fs` mounts:

```
UUID=xxxx  /      ext4   defaults,noatime,errors=remount-ro  0 1
UUID=yyyy  /home  btrfs  defaults,noatime,compress=zstd:1     0 2
```
Then `sudo mount -o remount /` or reboot.

- ✅ **Pros:** eliminates constant access-time writes; marginally faster metadata-heavy workloads.
- ❌ **Cons:** modern `relatime` default already skips ~99% of atime writes — gains are small; `mutt`-class apps that want atime must use `relatime`.
- **Difficulty by distro:** 🟢 everywhere (one file edit + reboot).

---

### 1.7 Journald diet
**Difficulty 🟢 · Risk 🟢 · 2 min**

```bash
sudo mkdir -p /etc/systemd/journald.conf.d
sudo tee /etc/systemd/journald.conf.d/perf.conf >/dev/null <<'EOF'
[Journal]
SystemMaxUse=100M
EOF
sudo systemctl restart systemd-journald
```

- ✅ **Pros:** caps log disk churn & size; less background I/O.
- ❌ **Cons:** less history for debugging. (`Storage=volatile` is even faster but loses logs on reboot.)
- **Difficulty by distro:** 🟢 (systemd distros; Artix skips this one).

---

### 1.8 GRUB timeout & quiet boot
**Difficulty 🟢 · Risk 🟢 · 3 min**

```bash
sudo sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=1/' /etc/default/grub
# optionally also set: GRUB_CMDLINE_LINUX_DEFAULT="quiet loglevel=3 systemd.show_status=0"
sudo update-grub || sudo grub-mkconfig -o /boot/grub/grub.cfg   # (Fedora: grubby handles args)
```

- ✅ **Pros:** shaves 4–9 s off every boot; less console noise.
- ❌ **Cons:** less time to pick recovery kernels; `quiet` hides boot errors.
- **Difficulty by distro:** Debian/Ubuntu 🟢 · Arch/Artix 🟢 · Fedora 🟡 (`grubby`) · Gentoo 🟡 · LFS 💀.

---

### 1.9 Boot & service audit
**Difficulty 🟡 · Risk 🟡 · 15 min**

```bash
systemd-analyze blame | head -25          # what's slow
systemd-analyze critical-chain            # the critical path
# Common safe-to-disable candidates (only if you truly don't use them):
sudo systemctl disable --now NetworkManager-wait-online.service   # −5–15 s boot, safe on desktop
sudo systemctl disable --now cups cups-browsed                     # no printer?
sudo systemctl disable --now bluetooth                             # no BT?
sudo systemctl disable --now ModemManager                          # no cellular modem?
sudo systemctl disable --now avahi-daemon                          # no .local/mDNS discovery?
sudo systemctl disable --now apt-daily.timer apt-daily-upgrade.timer  # manual updates only!
```

- ✅ **Pros:** boot time often drops 30–50%; less RAM/CPU background noise.
- ❌ **Cons:** **know what you're disabling** — disabling the wrong thing breaks printing, discovery, or auto-updates (and forgotten manual updates = security risk).
- **Difficulty by distro:** systemd distros 🟢–🟡 · Artix 🟡 (your init's service manager) · LFS 💀 (you built it, you know it).

---

### 1.10 CPU governor → `performance`
**Difficulty 🟢–🟡 · Risk 🟡 · 2 min**

```bash
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor    # current state
sudo cpupower frequency-set -g performance                   # right now

# Persist (universal systemd one-shot):
sudo tee /etc/systemd/system/perf-gov.service >/dev/null <<'EOF'
[Unit]
Description=Set performance CPU governor
[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor'
[Install]
WantedBy=multi-user.target
EOF
sudo systemctl enable --now perf-gov.service
```

- ✅ **Pros:** CPU ramps to max instantly; lower latency; best FPS consistency.
- ❌ **Cons:** more heat & power; laptops on battery will weep (use `schedutil` there — or TLP, see [Laptops](#-laptops)).
- **Difficulty by distro:** 🟢 everywhere. Note: on recent AMD (amd-pstate) and Intel (intel_pstate HWP) hardware, `schedutil`/EPP often delivers 95% of the benefit with none of the heat.

---

### 1.11 `earlyoom` / `systemd-oomd` — kill thrash before it starts
**Difficulty 🟢 · Risk 🟢 · 2 min**

```bash
sudo apt install earlyoom && sudo systemctl enable --now earlyoom   # Debian family
sudo pacman -S earlyoom && sudo systemctl enable --now earlyoom     # Arch family
# Fedora: systemd-oomd is preconfigured — `systemctl status systemd-oomd`
```

- ✅ **Pros:** system stays responsive instead of swapping to death; you lose one tab instead of the whole session.
- ❌ **Cons:** it *will* kill something at the worst moment if you run out of RAM — save your work.
- **Difficulty by distro:** 🟢 everywhere.

---

### 1.12 GameMode (Feral)
**Difficulty 🟢 · Risk 🟢 · 1 min**

```bash
sudo pacman -S gamemode lib32-gamemode     # Arch
sudo apt install gamemode                  # Debian family
# Steam launch options:   gamemoderun %command%
```

- ✅ **Pros:** auto-switches to performance governor, tweaks priorities while gaming, restores after.
- ❌ **Cons:** only helps games launched through it.
- **Difficulty by distro:** 🟢 everywhere.

---

### 1.13 `preload` (adaptive readahead)
**Difficulty 🟢 · Risk 🟢 · 1 min**

```bash
sudo apt install preload && sudo systemctl enable --now preload
```

- ✅ **Pros:** frequently-used apps open faster (cached based on usage patterns).
- ❌ **Cons:** debatable gains on SSDs; eats some RAM; project is old but still ships in distro repos.
- **Difficulty by distro:** 🟢 (Gentoo: `emerge preload`).

---

### 1.14 Hardware video decode (VAAPI)
**Difficulty 🟡 · Risk 🟢 · 10 min**

```bash
sudo apt install intel-media-va-driver-non-free libva-utils    # or mesa-va-drivers for AMD
vainfo                                                          # must show decode entry points
# Chromium: enable "Hardware-accelerated video decode" flag + VaapiVideoDecoder
# Firefox: media.ffmpeg.vaapi.enabled = true in about:config
```

- ✅ **Pros:** 10–20× less CPU during video playback → less heat → more thermal headroom for everything else.
- ❌ **Cons:** driver-dependent; occasional glitches with exotic codecs/HDR.
- **Difficulty by distro:** 🟡 everywhere (flags differ per browser).

---

### 1.15 Firmware updates (`fwupd`)
**Difficulty 🟢 · Risk 🟡 · 10 min**

```bash
sudo fwupdmgr refresh && sudo fwupdmgr update
```

- ✅ **Pros:** firmware bugs throttle SSDs, GPUs and ECs; this fixes them.
- ❌ **Cons:** rare bad firmware updates exist — keep a recovery plan for laptops.
- **Difficulty by distro:** 🟢 everywhere.

---

### 1.16 Housekeeping — orphans, caches, fast mirrors
**Difficulty 🟢 · Risk 🟢 · 5 min**

```bash
# Debian family                    # Arch family
sudo apt autoremove --purge         sudo pacman -Rns $(pacman -Qtdq) 2>/dev/null
sudo apt clean                      sudo paccache -rk2                  # needs pacman-contrib
                                    sudo reflector --latest 10 --sort rate --save /etc/pacman.d/mirrorlist
# Fedora
sudo dnf autoremove && sudo dnf clean all
```

- ✅ **Pros:** disk space, smaller update surface, faster package operations; `reflector` makes `pacman -Syu` dramatically faster.
- ❌ **Cons:** review the orphan list before nuking.
- **Difficulty by distro:** 🟢 everywhere.

---

### 1.17 DNS caching
**Difficulty 🟢 · Risk 🟢 · 5 min**

```bash
# systemd-resolved (most systemd distros): enable caching (default) & verify:
resolvectl statistics
```

- ✅ **Pros:** repeat lookups are instant → faster browsing *feel*.
- ❌ **Cons:** an extra network layer to debug when things break.
- **Difficulty by distro:** 🟢 everywhere.

---

### 1.18 Disable unattended upgrades *(optional — Ubuntu)*
**Difficulty 🟢 · Risk 🟡**

```bash
sudo systemctl disable --now unattended-upgrades.service apt-daily.timer apt-daily-upgrade.timer
```

- ✅ **Pros:** no surprise background downloads/IO; predictable performance.
- ❌ **Cons:** **you** must run updates. Security tradeoff — many should skip this tweak.
- **Difficulty by distro:** Ubuntu/Mint 🟢 · others N/A.

---

### 1.19 Go lighter (the biggest software win of all)
**Difficulty 🟡 · Risk 🟢 · 30–60 min**

| Heavy | Light | RAM saved (typical idle) |
|---|---|---|
| GNOME | XFCE / LXQt / KDE (plasma is surprisingly light nowadays) | 1–2.5 GB |
| KDE/XFCE | i3 / sway / Hyprland (tiling WMs) | 2–3 GB |
| Chrome (30 tabs) | Firefox + tab suspender | 1–4 GB |
| LibreOffice startup | — (disable QuickStarter autostart) | background RAM |

- ✅ **Pros:** on old/low-RAM hardware this beats every other tweak on this page combined.
- ❌ **Cons:** workflow change; fewer accessibility/polish features.
- **Difficulty by distro:** 🟢 everywhere (it's just packages).

---

# 🟡 Universal tweaks — Tier 2: Intermediate

---

### 2.1 I/O scheduler per device
**Difficulty 🟡 · Risk 🟢 · 5 min**

```bash
# Check current:   for d in /sys/block/*/queue/scheduler; do echo "$d: $(cat $d)"; done
sudo tee /etc/udev/rules.d/60-iosched.rules >/dev/null <<'EOF'
# NVMe → none (least overhead) | SATA SSD → mq-deadline | HDD/spinning → bfq
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
ACTION=="add|change", KERNEL=="mmcblk[0-9]*", ATTR{queue/scheduler}="bfq"
EOF
sudo udevadm control --reload-rules && sudo udevadm trigger
```

- ✅ **Pros:** BFQ on HDDs = dramatically better desktop responsiveness during copies; `none` on NVMe = lowest CPU overhead and max IOPS.
- ❌ **Cons:** micro-management; wrong mapping can hurt throughput.
- **Difficulty by distro:** 🟢–🟡 everywhere.

---

### 2.2 TCP BBR + network sysctls
**Difficulty 🟢 · Risk 🟢 · 3 min**

```bash
sudo modprobe tcp_bbr
sudo tee /etc/sysctl.d/99-net-perf.conf >/dev/null <<'EOF'
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
sudo sysctl --system
sysctl net.ipv4.tcp_congestion_control    # must say: bbr
```

- ✅ **Pros:** BBR sustains throughput on lossy/wireless links far better than cubic; `fq`+buffers help bulk transfers.
- ❌ **Cons:** buffer inflation if you go wild; BBRv1 fairness debates (irrelevant for desktops).
- **Difficulty by distro:** 🟢 everywhere (all modern kernels have BBR).

---

### 2.3 tmpfs `/tmp` (+ browser profile caching)
**Difficulty 🟡 · Risk 🟡 · 5 min**

```bash
systemctl unmask tmp.mount 2>/dev/null; sudo systemctl enable --now tmp.mount
findmnt /tmp    # verify fstype=tmpfs
# Browser profiles in RAM (big win on old machines — mind data-loss on power cut):
yay -S profile-sync-daemon && systemctl --user enable --now psd
```

- ✅ **Pros:** temp files at RAM speed; much less SSD wear; snappier compiles/builds.
- ❌ **Cons:** big temp files eat RAM (can OOM small machines); PSD loses unsaved browsing data on power loss.
- **Difficulty by distro:** systemd 🟢 · Artix 🟡 · Gentoo 🟡 (tmpfiles/init scripts).

---

### 2.4 Blacklist unused kernel modules
**Difficulty 🟡 · Risk 🟡 · 10 min**

```bash
sudo tee /etc/modprobe.d/perf-blacklist.conf >/dev/null <<'EOF'
# Only add lines for hardware you KNOW you don't have/use:
blacklist pcspkr          # PC speaker beep
blacklist firewire_core   # no FireWire
# blacklist uvcvideo      # no webcam  (uncomment only if true!)
EOF
```

- ✅ **Pros:** less RAM, less probe time, fewer interrupts, less power.
- ❌ **Cons:** blacklist something you actually have → device silently missing.
- **Difficulty by distro:** 🟢 everywhere.

---

### 2.5 Disable watchdogs (desktops)
**Difficulty 🟡 · Risk 🟡 · 2 min**

```bash
echo 'kernel.nmi_watchdog = 0' | sudo tee /etc/sysctl.d/99-watchdog.conf
sudo sysctl --system
# Optional kernel param for full effect: nowatchdog   (see Kernel cmdline table)
```

- ✅ **Pros:** removes a constant interrupt source; measurable (small) latency/CPU win.
- ❌ **Cons:** a hard hang won't self-reboot — **don't do this on servers**.
- **Difficulty by distro:** 🟢 everywhere.

---

### 2.6 TLP / auto-cpufreq *(laptops)*
**Difficulty 🟢 · Risk 🟢 · 3 min**

```bash
sudo apt install tlp && sudo systemctl enable --now tlp    # conflicts with power-profiles-daemon — remove it first
# or: sudo apt install auto-cpufreq (AUR/other distros similarly)
```

- ✅ **Pros:** cooler laptop → **more sustained boost** (thermals are performance); 20–40% battery life.
- ❌ **Cons:** desktops gain nothing; tiny config learning curve.
- **Difficulty by distro:** 🟢 everywhere.

---

### 2.7 Thermald *(Intel)*
**Difficulty 🟢 · Risk 🟢 · 2 min**

```bash
sudo apt install thermald && sudo systemctl enable --now thermald
```

- ✅ **Pros:** smarter thermal management = fewer throttle cliffs on Intel laptops.
- ❌ **Cons:** Intel-only; negligible overhead.
- **Difficulty by distro:** 🟢 everywhere.

---

### 2.8 IRQ strategy (irqbalance off for gaming)
**Difficulty 🔴 · Risk 🟡**

```bash
systemctl status irqbalance
# Latency-first gaming box:  sudo systemctl disable --now irqbalance   (then pin IRQs via /proc/irq/*/smp_affinity)
# Server / general use:      KEEP irqbalance.
```

- ✅ **Pros (off):** fewer IRQ migrations → lower jitter in games.
- ❌ **Cons (off):** worse CPU balance under heavy IO — bad for servers.
- **Difficulty by distro:** 🟡 everywhere (manual pinning 🔴).

---

### 2.9 ananicy-cpp (auto-nice background apps)
**Difficulty 🟡 · Risk 🟢**

```bash
sudo pacman -S ananicy-cpp && sudo systemctl enable --now ananicy-cpp   # Arch/CachyOS
# Others: build from github.com/zavgan/ananicy-cpp (cmake)
```

- ✅ **Pros:** background hogs (compilers, indexers) get auto-lowered priority → foreground stays buttery with zero manual `renice`.
- ❌ **Cons:** rarely misclassifies an app; one more daemon.
- **Difficulty by distro:** Arch 🟢 · Debian/Fedora 🟡 (build) · Gentoo 🟡 · LFS 💀.

---

### 2.10 Btrfs mount options & compression
**Difficulty 🟡 · Risk 🟢**

```
# /etc/fstab example:
UUID=xxx  /  btrfs  defaults,noatime,compress=zstd:1,ssd  0 0
```

- ✅ **Pros:** transparent compression = less IO + more usable space (often *faster* on compressible data).
- ❌ **Cons:** CPU cost on incompressible data (zstd:1 is cheap though); must be set per-mount.
- **Difficulty by distro:** 🟢 everywhere with btrfs.

---

### 2.11 initramfs slimming
**Difficulty 🟡 · Risk 🟡**

```bash
# Arch: /etc/mkinitcpio.conf → COMPRESSION="zstd", keep "autodetect" hook, then:
sudo mkinitcpio -P
# Fedora/dracut: echo 'hostonly="yes"' | sudo tee /etc/dracut.conf.d/hostonly.conf && sudo dracut -f
```

- ✅ **Pros:** smaller initramfs = faster boot.
- ❌ **Cons:** `hostonly` breaks portability (moving disk to other hardware); **always keep a fallback initramfs**.
- **Difficulty by distro:** Arch 🟢 · Fedora 🟡 · Debian 🟡 · Gentoo 🟡 · LFS 💀.

---

### 2.12 systemd-boot instead of GRUB
**Difficulty 🟡 · Risk 🟡**

```bash
sudo bootctl install   # on UEFI systems; entries in /boot/loader/entries/*.conf
```

- ✅ **Pros:** simpler, slightly faster, integrates with `kernel-install`.
- ❌ **Cons:** fewer features than GRUB; migration has foot-guns on encrypted setups.
- **Difficulty by distro:** Arch 🟢 · others 🟡–🔴.

---

### 2.13 Wi-Fi power save off
**Difficulty 🟢 · Risk 🟢**

```bash
sudo tee /etc/NetworkManager/conf.d/wifi-powersave.conf >/dev/null <<'EOF'
[connection]
wifi.powersave = 2    # 2 = disable
EOF
sudo systemctl restart NetworkManager
```

- ✅ **Pros:** lower latency & fewer micro-stutters on Wi-Fi.
- ❌ **Cons:** measurable battery cost on laptops.
- **Difficulty by distro:** 🟢 everywhere (NetworkManager).

---

# 🔴 Universal tweaks — Tier 3: Advanced

---

### 3.1 Alternative prebuilt kernels — the easy 80% of a custom kernel
*(Full comparison table + install commands in the [🧠 Kernel Chapter](#-the-kernel-chapter).)*

Quick picks:

```bash
sudo pacman -S linux-zen linux-zen-headers                 # Arch/Artix — desktop-tuned, official
sudo apt install linux-lowlatency                          # Ubuntu/Mint — 1000 Hz low-latency
sudo add-apt-repository ppa:damentz/liquorix && sudo apt update \
  && sudo apt install linux-image-liquorix-amd64           # Debian family — zen-flavored
```

- ✅ **Pros:** 1000 Hz tick, desktop preemption, tuned schedulers, newer compiler flags — installed as a *side-by-side* kernel with your stock one as fallback.
- ❌ **Cons:** third-party trust; occasional DKMS/NVIDIA breakage; update churn.
- **Difficulty by distro:** Arch 🟢 · Ubuntu/Mint 🟢–🟡 (PPA) · Debian 🟡 (backports/liquorix) · Fedora 🟡 · Gentoo 🟡 · LFS 💀.

---

### 3.2 Latency-focused kernel command line
**Difficulty 🔴 · Risk 🔴 — verify with `cyclictest`, see [cmdline reference](#kernel-cmdline-reference)**

```ini
# /etc/default/grub — for a dedicated gaming box with 8+ cores (example: cores 4-7 reserved)
GRUB_CMDLINE_LINUX_DEFAULT="... threadirqs rcu_nocbs=4-7 nohz_full=4-7 isolcpus=no_domain,4-7"
```

- ✅ **Pros:** dramatic jitter reduction for gaming/DAW/trading on dedicated cores.
- ❌ **Cons:** wastes cores; wrong syntax = weird performance; **measure or don't bother**.
- **Difficulty by distro:** Arch/Debian 🟡 (one file) · Gentoo 🟡 · LFS 💀.

---

### 3.3 Compile your own kernel
The full walkthrough + `.config` cheat sheet lives in the [🧠 Kernel Chapter](#-the-kernel-chapter).

- ✅ **Pros:** only the code your hardware needs, `-march=native`, MGLRU, 1000 Hz, no debug bloat → faster boot, smaller RAM footprint, last few % of performance.
- ❌ **Cons:** hours per build; **you** own security recompiles; DKMS/NVIDIA can complicate.
- **Difficulty by distro:** Arch 🟡 · Gentoo 🟡 (normal Tuesday) · Debian 🟡–🔴 · Fedora 🔴 · LFS 💀 *(the entire point of LFS)*.

---

### 3.4 `-march=native` for everything you build *(Arch)*
**Difficulty 🟡 · Risk 🟡**

```bash
# /etc/makepkg.conf — affects AUR/self-built packages only:
CFLAGS="-march=native -O2 -pipe -fno-plt"
CXXFLAGS="-march=native -O2 -pipe -fno-plt"
```

- ✅ **Pros:** real gains (typically 1–10%) in anything you compile yourself.
- ❌ **Cons:** official repo binaries are still generic; breaks portability of built packages.
- **Difficulty by distro:** Arch 🟢 (one file) · Debian 🔴 (rebuild world via apt-build — usually not worth it) · Gentoo 🟢 (**this is just Gentoo**).

---

### 3.5 x86-64-v3/v4 optimized repos
**Difficulty 🟡 · Risk 🟡**

CachyOS repositories (usable on plain Arch — follow docs at cachyos.org) provide AVX-512/v3-optimized rebuilds of huge parts of the repo, plus their LTO'd kernel.

- ✅ **Pros:** distro-wide `-march` gains without compiling anything yourself.
- ❌ **Cons:** third-party repo mixing; some package mismatch churn.
- **Difficulty by distro:** Arch 🟡 · everything else 🔴/💀 · or just install **CachyOS** and get it for free.

---

### 3.6 GPU tuning
**AMD:** `CoreCtrl` for power profiles; unlock overclocking with `amdgpu.ppfeaturemask=0xffffffff` (risky). RADV (Mesa) is the best gaming driver for AMD — you already have it.
**NVIDIA:** `nvidia-drm.modeset=1`; test "full composition pipeline" OFF for lower latency; check GSP firmware behavior on your card (see Arch Wiki NVIDIA page).
**Intel:** `i915.enable_guc=2` enables GuC/HuC (better media offload); FBC usually on by default.

- ✅ **Pros:** correctly configured GPU = the difference between a stutter-fest and smooth frames.
- ❌ **Cons:** driver-specific quirks; OC/undervolt risks hardware.
- **Difficulty by distro:** 🟡 everywhere (kernel params + userland tools).

---

### 3.7 CPU undervolt / overclock
**Difficulty 🔴 · Risk 💀**

```bash
# Older Intel: sudo apt install intel-undervolt (modern CPUs are locked — thanks, Plundervolt)
# AMD Ryzen: Curve Optimizer in BIOS (best route)
```

- ✅ **Pros:** lower temps → longer sustained boost clocks → *faster*, quieter machine.
- ❌ **Cons:** instability, potential degradation, warranty questions. **Stress-test or regret.**
- **Difficulty by distro:** distro-independent 🔴 (it's BIOS + tools).

---

### 3.8 Workload specials: hugepages/NUMA (DBs, VMs)
`vm.nr_hugepages`, `numactl`, `ksm` for dense VM hosts — see [sysctl tables](#%EF%B8%8F-sysctl-reference-tables). Niche but big wins when applicable.

---

### 3.9 VM host gaming (VFIO)
GPU passthrough + CPU pinning + `Looking Glass` = near-native Windows gaming in a VM. See the Arch Wiki VFIO page (the definitive guide). Difficulty 💀-adjacent 🔴, but the payoff is unique.

---

### 3.10 sched-ext (`scx`) schedulers — bleeding edge
Kernel 6.12+ lets you *swap CPU schedulers at runtime*. Try LAVD (`scx_lavd`) for gaming responsiveness on Arch/CachyOS (`sudo pacman -S scx`). Hot research area — expect churn.

- ✅ **Pros:** purpose-built schedulers (latency, gaming, server) without reboots.
- ❌ **Cons:** young; behavior changes release to release.
- **Difficulty by distro:** Arch/CachyOS 🟡 · others 🔴 (build from source).

---

# 💀 Universal tweaks — Tier 4: Expert / Reckless

> Everything below **trades security or sanity for speed**. Read twice. Snapshot thrice.

### 4.1 `mitigations=off` — disable CPU vulnerability mitigations
**Difficulty 🟡 (to apply) · Risk 💀 (to live with)**

```bash
# Verify what you currently have exposed:
grep -r . /sys/devices/system/cpu/vulnerabilities/ | column -t
# Apply (GRUB distros):
sudo sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 mitigations=off"/' /etc/default/grub
sudo update-grub || sudo grub-mkconfig -o /boot/grub/grub.cfg
# Fedora: sudo grubby --update-kernel=ALL --args="mitigations=off"
```

- ✅ **Pros:** often **5–30% more CPU performance** (syscall/interrupt-heavy workloads gain the most); lower latency.
- ❌ **Cons:** re-enables Spectre/Meltdown/L1TF/Retbleed-class attacks. **Every browser tab is untrusted code.** For single-user offline gaming/benchmark rigs: defensible. For a daily internet machine: **don't**. Middle ground: `mitigations=auto` and keep browser sandboxing.
- **Difficulty by distro:** 🟡 everywhere (one param) — the *decision* is the hard part.

### 4.2 Per-vulnerability mitigation control
`spectre_v2=off retbleed=off pti=off ...` — pick your poison per CVE class. Same pros/cons as 4.1, more granular. 🔴💀.

### 4.3 `PREEMPT_RT` everywhere
Full real-time kernel (mainline since 6.12 for x86): guaranteed microsecond latency, ~1–5% throughput cost. For audio/robotics/HSI — not a general speedup. 🔴.

### 4.4 Custom userland: musl, LTO-everything, custom libc
Alpine-style musl userland, GentooLTO overlay, PGO builds. Gains: 1–10%. Pain: high. 💀 (Gentoo makes it merely 🔴).

### 4.5 Disabling SELinux/AppArmor
Measurable gain ≈ 0–1% in most workloads. **Keep your MAC on.** Listed so you don't fall for forum posts. 💀 (and pointless).

---

# 🐧 Distro chapters

## Debian
**Vibe:** stability first — but backports make it fast.

```bash
# Newer kernel from backports (bookworm example):
echo 'deb http://deb.debian.org/debian bookworm-backports main non-free-firmware' \
  | sudo tee /etc/apt/sources.list.d/backports.list
sudo apt update && sudo apt -t bookworm-backports install linux-image-amd64
```
- ✔ Easy: everything via apt (zram, microcode, thermald, earlyoom, tlp)
- ✔ Liquorix repo works beautifully on Debian
- 🔴 Hard: custom kernel the "Debian way" (`make-kpkg` is dead; use `make bindeb-pkg`)
- **Difficulty rating: 🟢 overall** — most tweaks are one apt command.

## Ubuntu (+ flavors)
Same as Debian, plus:
```bash
sudo apt install linux-lowlatency              # 1000 Hz preempt kernel from official repos — easy mode
sudo apt install --install-recommends linux-generic-hwe-22.04   # newer HWE kernel on LTS
# mainline kernels GUI: ppa:cappelikan/ppa → mainline-gtk
```
- ✔ Consider removing snapd for snappier app launches & less RAM (`sudo apt purge snapd`) — pros: speed; cons: loses some app delivery & sandboxing.
- ⚠️ Ubuntu ships **zswap** by default — move to zram (see 1.4) for most desktops.
- **Difficulty: 🟢** — the friendliest distro for every tweak in this repo.

## Linux Mint
Ubuntu/Debian base + **Timeshift snapshots built in** → you already have the safety net this repo demands. All Ubuntu tweaks apply. **Difficulty: 🟢.**

## Pop!_OS
Ships the **System76 scheduler** (ananicy-class auto-prioritization) and a gaming-friendly kernel — half this list is pre-applied. Keep the stock kernel. **Difficulty: 🟢.**

## Arch Linux
**Vibe:** the tweak playground.

```bash
sudo pacman -S linux-zen linux-lts      # zen for daily, lts as safety net
yay -S linux-cachyos                    # or add CachyOS repos: BORE scheduler + LTO + v3/v4
yay -S linux-tkg-pds                    # tkg kernels: pick PDS/TT scheduler
# makepkg.conf -march=native (see 3.4)
sudo pacman -S ananicy-cpp scx zram-generator thermald gamemode mangohud
```
- ✔ Easy: prebuilt alternative kernels from official repos
- 🟡 Medium: AUR kernels, makepkg flags, mkinitcpio tuning
- 🔴 Hard: full custom kernel via ABS
- **Difficulty: 🟡 overall** — everything is *available*, but you assemble it.

## Artix
Arch without systemd — **choose your init** (runit = famously snappy boot, also OpenRC/s6/dinit). All Arch package tweaks apply; systemd-specific ones (systemd-analyze audit, journald, tmp.mount, systemd-resolved) have init-specific equivalents — check the Artix wiki. `zram-generator` is systemd-tied, so prefer a `zramswap` service for your init. **Difficulty: 🟡.**

## CachyOS / EndeavourOS
**CachyOS is this repo pre-installed**: x86-64-v3/v4 optimized packages, BORE/EEVDF-tuned kernel with LTO, zram, ananicy, scx. If you're installing fresh and performance is the goal, start here and enjoy. **Difficulty: 🟢 (it's done for you).**
EndeavourOS = Arch with a friendly installer; Arch chapter applies.

## Fedora
```bash
# dnf speed:
echo -e 'max_parallel_downloads=10\nfastestmirror=True' | sudo tee -a /etc/dnf/dnf.conf
# tuned — Fedora's killer feature:
sudo dnf install tuned && sudo systemctl enable --now tuned
tuned-adm profile latency-performance    # or throughput-performance / desktop / balanced
sudo dnf install kernel-rt               # real-time kernel (see 4.3)
```
Zram is default; kernels are fresh; `tuned` profiles encapsulate half of Tier 1–2. **Difficulty: 🟢–🟡.**

## openSUSE
`zypper dup` for updates, `tuned` available, **snapper** gives automatic btrfs snapshots = perfect safety net for kernel experiments. **Difficulty: 🟢–🟡.**

## Gentoo
**The whole distro is a performance tweak.** The pain is time; the payoff is a system compiled for *your* CPU.

`/etc/portage/make.conf`:
```bash
COMMON_FLAGS="-march=native -O2 -pipe"
MAKEOPTS="-j$(nproc) -l$(nproc)"
EMERGE_DEFAULT_OPTIONS="--jobs=$(nproc) --load-average=$(nproc)"
FEATURES="ccache"
```
```bash
echo "*/* $(cpuid2cpuflags)" | sudo tee /etc/portage/package.use/00cpu-flags   # exact CPU features
sudo emerge gentoo-kernel        # easy mode: auto-maintained distribution kernel
sudo emerge gentoo-sources       # purist mode: manual kernel (see Kernel Chapter)
# LTO everything: eselect repository enable gentoo-lto (github.com/InBetweenNames/gentoo-lto)
```
- ✔ Easy: source-based `-march=native` by default; USE-flag trimming
- 🟡 Medium: kernel configs, ccache/distcc setup (distcc = compile on your whole LAN)
- 🔴 Hard: LTO overlay, full custom profiles
- **Difficulty: 🔴 overall** (mostly *time*, not complexity — the Handbook is superb).

## Linux From Scratch
You built the toolchain; you ARE the distro maintainer. Performance is fully yours:
- Kernel: `make localmodconfig` → the leanest kernel on earth, by construction.
- Userland: musl or glibc, your flags, your init (busybox `init` boots in **milliseconds**).
- Tradeoff: every security update is a you-update.
- **Difficulty: 💀** — recommended order: do this repo's Tier 1–3 on a normal distro *first*, then LFS when you want enlightenment. (linuxfromscratch.org)

## Honorable mentions
- **Clear Linux (Intel):** frequently tops Phoronix charts out-of-the-box (aggressive compiler flags, stateless design) — Intel CPUs benefit most.
- **Alpine/musl:** tiny & fast for containers/servers; desktop app compatibility caveats.

---

# 🧠 The Kernel Chapter

## Which scheduler? (brief history)
- **CFS** → classic fair scheduler. Replaced in 6.6 by…
- **EEVDF** → current mainline default; genuinely good for desktops.
- **BORE** (CachyOS) → EEVDF with response-time tuning; popular for gaming feel.
- **PDS / BMQ / TT** (tkg, Liquorix) → desktop/latency-focused alternatives.
- **MuQSS** → Con Kolivas's legendary scheduler — retired. Pour one out. 🫗
- **sched-ext (6.12+)** → hot-swappable eBPF schedulers (`scx_lavd`, `scx_bpfland`, …) — the future.

## Prebuilt kernel comparison

| Kernel | For | Key features | Difficulty |
|---|---|---|---|
| **linux-zen** (Arch official) | Arch desktops | 1000 Hz-ish tuned config, latency-focused | 🟢 |
| **XanMod** (xanmod.org) | Debian/Ubuntu/Arch | full preemption, x64v2/v3/v4 builds, optional RT branch | 🟢–🟡 |
| **Liquorix** (ppa:damentz/liquorix) | Debian family | zen-derived desktop tuning | 🟢 |
| **linux-lowlatency** (Ubuntu) | Ubuntu audio/gaming | 1000 Hz, preempt | 🟢 |
| **CachyOS kernel** (cachyos.org) | Arch (+repos) | BORE, clang LTO, v3/v4 | 🟡 |
| **tkg kernels** (Frogging-Family) | tweakers | choose scheduler/Hz at build time | 🔴 |
| **kernel-rt / PREEMPT_RT** | audio, robotics | hard real-time | 🟡–🔴 |
| **linux-hardened** (Arch) | security | *slower*, listed so you know | 🟢 |

**Pros (all):** kernel-level responsiveness gains without compiling. **Cons (all):** third-party maintenance, occasional module/DKMS friction — **always keep your distro's stock kernel installed as fallback.**

## Custom kernel walkthrough

```bash
# 0. Have your USB sticks/peripherals PLUGGED IN (for localmodconfig) + a snapshot taken
# 1. Get sources (Arch: sudo pacman -S core/linux-headers && asp checkout linux — or kernel.org tarball; Debian: sudo apt install linux-source; Gentoo: emerge gentoo-sources)
cd linux-6.x.y/

# 2. Seed a config
make localmodconfig        # leanest: only what's currently loaded
#  OR start from your distro's config: zcat /proc/config.gz > .config  (if available)

# 3. Customize
make menuconfig            # cheat sheet below

# 4. Build with your CPU's best flags
KCFLAGS="-march=native" make -j"$(nproc)"

# 5. Install (Debian family — makes .deb packages):
sudo make modules_install
sudo make install          # or: make -j$(nproc) bindeb-pkg && sudo apt install ./linux-image-*.deb
# 5b. Arch: copy arch/x86/boot/bzImage to /boot/vmlinuz-custom, mkinitcpio -P, bootloader entry
# 5c. Gentoo: make install + dracut --force / grub-mkconfig (or the gentoo-kernel package does it all)

# 6. KEEP your old kernel entry in the bootloader. Reboot. Test. Keep old kernel ~2 weeks.
```

### `.config` cheat sheet (the options that actually matter)

| Option | Set to | Why |
|---|---|---|
| Preemption model | `PREEMPT` / `PREEMPT__LL` ("Fully preemptible/low-latency desktop") | snappier interactive response |
| Timer frequency | `HZ_1000` | smoother games/audio (small power cost) |
| `CONFIG_LRU_GEN` (+`_ENABLED`) | `y` | MGLRU — much better under memory pressure |
| `CONFIG_CPU_FREQ_DEFAULT_GOV_*` | `performance` (or `schedutil` for laptops) | your call |
| Kernel hacking → debug options | **all off** (`DEBUG_INFO_NONE`, no lockdep/kasan/ubsan) | smaller, faster kernel |
| `CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE` | `y` (some trees offer O3) | compiler opt level |
| `CONFIG_ZRAM(_ZSTD)` | `y` | enables 1.4 |
| `CONFIG_MODULE_COMPRESS_ZSTD` | `y` | faster module loads |
| `CONFIG_KERNEL_ZSTD` | `y` | faster decompression at boot |
| `CONFIG_HIBERNATION` | `n` (if you never hibernate) | faster boot, smaller kernel |
| Filesystems | only what you use | smaller attack/bug surface |

## Kernel cmdline reference

| Param | Effect | Gain | Risk |
|---|---|---|---|
| `mitigations=off` | disables CPU bug workarounds | 5–30% CPU | 💀 security |
| `nowatchdog` | disables NMI/soft watchdog | small latency | 🟡 no auto-reboot on hang |
| `threadirqs` | IRQs run as threads (preemptible) | lower jitter | 🟢 |
| `rcu_nocbs=X-Y` | offload RCU callbacks from cores X-Y | lower jitter | 🟡 |
| `nohz_full=X-Y` | tickless dedicated cores | lower jitter | 🔴 measure! |
| `isolcpus=no_domain,X-Y` | keep cores away from scheduler | latency on those cores | 🔴 |
| `processor.max_cstate=1` / `idle=poll` | shallower CPU idle | lower wakeup latency | 🔴 heat/power 💀 for `idle=poll` |
| `zswap.enabled=0` | disable zswap (when using zram) | cleanliness | 🟢 |
| `i915.enable_guc=2` | Intel GuC/HuC | media offload | 🟡 |
| `amdgpu.ppfeaturemask=0xffffffff` | unlock AMD OC | OC ability | 🔴 |
| `nvidia-drm.modeset=1` | NVIDIA modesetting | smoother | 🟢 |
| `plymouth.enable=0` | skip splash | boot time | 🟢 |
| `quiet loglevel=3` | quieter boot | boot time (marginal) | 🟡 hides errors |
| `audit=0` | disable audit subsystem | small CPU | 🟡 security/compliance |

---

## ⚙️ sysctl reference tables

### Memory (`/etc/sysctl.d/*.conf`)

| Key | Default | Suggested | Notes / risk |
|---|---|---|---|
| `vm.swappiness` | 60 | 10 (disk swap) / 100–180 (zram) | zram *likes* high values |
| `vm.vfs_cache_pressure` | 100 | 50 | keeps dentry/inode cache |
| `vm.dirty_background_bytes` | ratio-based | 268435456 (256M) | smoother writeback |
| `vm.dirty_bytes` | ratio-based | 1073741648 (1G) | throughput vs. data-at-risk on power loss |
| `vm.min_free_kbytes` | ~90k | 262144 | OOM safety headroom |
| `vm.overcommit_memory` | 0 | 1 **for DBs only** | 💀 apps-only territory |
| `vm.nr_hugepages` | 0 | per-workload | DBs/VMs |

### Network

| Key | Suggested | Why |
|---|---|---|
| `net.ipv4.tcp_congestion_control` | `bbr` | throughput on lossy links |
| `net.core.default_qdisc` | `fq` | pairs with BBR |
| `net.ipv4.tcp_fastopen` | `3` | faster connection setup |
| `net.ipv4.tcp_slow_start_after_idle` | `0` | keeps window warm |
| `net.core.rmem_max` / `wmem_max` | `16777216` | bigger buffers for fat pipes |
| `net.core.somaxconn` | `1024` | servers under connection bursts |

---

## 🖥️ Desktop & GPU

- **Disable animations:** `gsettings set org.gnome.desktop.interface enable-animations false` (GNOME); KDE → System Settings → Animations off.
- **Compositor:** on X11, picom is light; some WMs let you disable compositing for fullscreen games automatically.
- **Fonts cache after install:** `fc-cache -f` (avoids slow first-launch font scans).
- **Wayland vs X11:** Wayland is the future & generally fine; on NVIDIA it historically lagged — test both, keep the smoother.
- **GPU drivers:** AMD/Intel → Mesa (RADV/ANV) is excellent, always latest = best. NVIDIA → proprietary driver, see 3.6.

## 🎮 Gaming

```bash
sudo pacman -S gamemode lib32-gamemode mangohud lib32-mangohud gamescope   # Arch
sudo apt  install gamemode mangohud                                        # Debian family
```

**Steam launch options toolbox:**
```
gamemoderun mangohud %command%                          # gamemode + overlay
gamescope -w 2560 -h 1440 -r 144 --force-grab-cursor -- %command%   # micro-compositor
```
- **Proton-GE** (`protonup-qt`): newest fixes, best compatibility — the single biggest "gaming performance" freebie.
- **MangoHud config sample** (`~/.config/MangoHud/MangoHud.conf`):
  ```ini
  fps,frametime,cpu_temp,gpu_temp,vram,ram
  position=top-left
  toggle_hud=Shift_R+F12
  ```
- Watch **1% lows**, not average FPS — that's what tweaks actually move.
- **NTSync** (kernel 6.14+) is the new faster-than-fsync Wine sync — support is landing in Proton forks; watch this space.

## 💻 Laptops

1. **Thermals are performance.** `s-tui` under stress; if you throttle: repaste, dust, elevate, fan curves.
2. **Plug in + performance profile** when you need speed (battery power caps clocks hard).
3. TLP (2.6) for battery, `performance` governor + GameMode when docked.
4. **Suspend:** `s2idle` vs `deep` — AMD machines often behave differently; test `mem_sleep_default=deep` if resume is broken (or vice versa).
5. Check `powertop` for wakers.

## 🔩 Hardware — the REAL performance

No sysctl survives bad hardware:

- **RAM:** enable **XMP/EXPO/DOCP** in BIOS — running rated RAM at JEDEC speeds is the #1 free hardware win people miss. Confirm dual-channel (`dmidecode -t memory` — 2+ sticks, correct slots!).
- **Storage:** NVMe over SATA is ~5–6× sequential, often more in random I/O.
- **BIOS:** update it; disable unused devices; set fan curves; AHCI mode; disable CSM.
- **Cooling:** a throttled i9 performs like an i3. Clean your filters.
- **The hierarchy:** cooling > RAM training > storage > GPU/CPU class > everything in this repo.

## ⏱️ Boot-time reduction checklist

1. `systemd-analyze` → baseline ☑
2. Kill `NetworkManager-wait-online` ☑ (1.9)
3. GRUB timeout 1s ☑ (1.8)
4. Plymouth off (`plymouth.enable=0` or remove package) ☑
5. Service audit ☑ (1.9)
6. initramfs: zstd + hostonly ☑ (2.11)
7. Blacklist unused modules ☑ (2.4)
8. systemd-boot ☑ (2.12)
9. Watchdogs off ☑ (2.5)
10. `DefaultTimeoutStopSec=10s` in `/etc/systemd/system.conf` ☑

## ↩️ Rollback & the undo system

- **The script** saves backups to `/var/backups/tuxturbo/` and writes `undo-<timestamp>.sh` per session:
  ```bash
  sudo bash /var/backups/tuxturbo/undo-<timestamp>.sh
  ```
- **Manual changes:** every config-file tweak in this README lives in a *drop-in* file (`/etc/sysctl.d/99-*.conf`, journald.conf.d, modprobe.d, udev rules) — rollback = **delete the file**.
- **Kernels:** never uninstall your stock kernel on day one. Boot menu = your undo button.
- **Snapshots** (Timeshift/snapper) before Tier 3+.

## 🧙 Myths & snake oil

| Myth | Reality |
|---|---|
| "RAM cleaners/optimizers" | Actively harmful — the kernel *wants* full RAM as cache |
| "Disable swap for speed" | Causes OOM kills; zram is the correct answer |
| "Prelink your binaries" | Dead project; ASLR made it pointless |
| "Disable IPv6 = faster internet" | Placebo 99% of the time (and breaks things) |
| "Faster DNS = faster downloads" | Only affects lookup latency, not throughput |
| "`echo 3 > drop_caches` before benchmarks" | Makes things *slower*; only for testing cold cache |

## ❓ FAQ

**Will this break my system?** Tier 1: no (drop-in files, reversible). Tier 3–4: possibly — that's why snapshots & fallback kernels exist.
**Why not just use CachyOS?** Honestly? If you're on Arch and starting fresh, maybe you should — this repo is for everyone else (and for CachyOS users who want Tier 3+).
**Is `mitigations=off` worth it?** Offline gaming/benchmark rig: yes. Internet-facing daily driver: no.
**zram or zswap?** Desktop: zram. Server with existing swap partitions: zswap. Never both.
**Do I need a custom kernel?** If you're asking — no. `linux-zen`/XanMod/Liquorix get you ~95% of it.
**Why is my laptop still slow?** Thermals or battery power state. Check [Laptops](#-laptops) first.
**Where did my gains go?** You didn't benchmark before. 📊 (It happens to everyone. Once.)

## 🤝 Contributing

PRs welcome for: new tweaks (with pros/cons + difficulty-by-distro), distro corrections, benchmark results. See [CONTRIBUTING.md](CONTRIBUTING.md). ShellCheck-clean bash only.

## 📜 License & Credits

MIT © yofriendfromschool1 — see [LICENSE](LICENSE).

Standing on the shoulders of: **Arch Wiki** (the greatest Linux documentation on Earth), **Phoronix** (Michael Larabel's kernel benchmarks), zram-generator docs, Feral GameMode, CachyOS, Liquorix/XanMod maintainers, and every kernel developer.

<div align="center">

**⭐ If this made your machine faster, star the repo — it's 0 cost and 100% dopamine for maintainers. ⭐**

*Drive it like you stole it.* 🏁
