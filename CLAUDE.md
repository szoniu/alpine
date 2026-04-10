# CLAUDE.md — Kontekst projektu dla Claude Code

## Co to jest

Interaktywny TUI installer Alpine Linux w Bashu. Cel: boot z Alpine Linux Live ISO (Extended), sklonowac repo, `./install.sh` — i dostac dzialajacy desktop KDE Plasma, GNOME, XFCE, Sway lub niri.

Alpine Linux to:
- **musl libc** (nie glibc)
- **OpenRC** init system (nie systemd, nie dinit)
- **apk** package manager
- **Minimalistyczny** — najlzejsza dystrybucja z pelnym desktop support
- **Open-source GPU drivers only** (brak NVIDIA proprietary)

## Architektura

### Model: outer process + chroot

1. Wizard TUI -> konfiguracja
2. Partycjonowanie dysku (opcjonalnie LUKS)
3. `apk --root --initdb` -> instalacja bazowa
4. `chroot` -> konfiguracja wewnatrz
5. Kernel + bootloader + desktop + uzytkownicy
6. Finalizacja

### Struktura plikow

```
install.sh              — Entry point, parsowanie argumentow, orchestracja
configure.sh            — Wrapper: exec install.sh --configure

lib/
├── protection.sh       — Guard: sprawdza $_ALPINE_INSTALLER
├── constants.sh        — Stale, sciezki, CONFIG_VARS[]
├── logging.sh          — elog/einfo/ewarn/eerror/die/die_trace
├── utils.sh            — try() (text fallback, LIVE_OUTPUT), checkpoint_*/validate/migrate, cleanup_target_disk, try_resume_from_disk, infer_config_from_partition
├── dialog.sh           — Wrapper gum/dialog/whiptail, primitives, wizard runner, bundled gum extraction
├── config.sh           — config_save/load/set/get/dump/diff (${VAR@Q}), validate_config()
├── hardware.sh         — detect_cpu/gpu(multi-GPU/hybrid)/disks/esp/installed_oses, detect_asus_rog, detect_bluetooth/fingerprint/thunderbolt/sensors/webcam/wwan, serialize/deserialize_detected_oses, get_hardware_summary()
├── disk.sh             — Dwufazowe: plan -> execute, mount/unmount, LUKS, shrink helpers (disk_plan_shrink via parted)
├── bootstrap.sh        — apk --root --initdb, apk_install, apk_update, enable_community_repo, enable_testing_repo
├── chroot.sh           — Manual bind mounts, plain chroot, DNS copy
├── system.sh           — timezone, hostname, keymap, fstab, mkinitfs, networking (NetworkManager+OpenRC), users (shadow+doas), finalize (OpenRC services)
├── bootloader.sh       — GRUB (grub-mkconfig) lub systemd-boot (manual entries)
├── desktop.sh          — KDE/GNOME/XFCE/Sway/niri, SDDM/GDM/LightDM/greetd, PipeWire, elogind, GPU drivers, extras
├── swap.sh             — zram (OpenRC init script), swap partition
├── hooks.sh            — maybe_exec 'before_X' / 'after_X'
└── preset.sh           — preset_export/import (hardware overlay)

tui/
├── welcome.sh          — Prerequisites (root, UEFI, siec)
├── preset_load.sh      — skip/file/browse
├── hw_detect.sh        — detect_all_hardware + summary
├── disk_select.sh      — dysk + scheme (auto/dual-boot/manual) + _shrink_wizard()
├── filesystem_select.sh — ext4/btrfs/xfs + LUKS encryption
├── swap_config.sh      — zram/partition/none
├── network_config.sh   — hostname
├── locale_config.sh    — timezone + keymap
├── bootloader_select.sh — GRUB vs systemd-boot
├── kernel_select.sh    — lts/edge
├── gpu_config.sh       — AMD(radv)/Intel(anv)/NVIDIA(nouveau) — all open-source
├── desktop_config.sh   — KDE/GNOME/XFCE/Sway/niri/none + apps + flatpak/printing/bluetooth
├── user_config.sh      — root pwd, user, grupy, SSH
├── extra_packages.sh   — checklist (extras + conditional hw items + niri/hyprland) + wolne pole apk packages
├── preset_save.sh      — eksport
├── summary.sh          — validate_config + podsumowanie + YES + countdown
└── progress.sh         — resume detection + infobox/live output + fazowa instalacja

data/
├── gpu_database.sh     — GPU recommendation + microcode packages
├── dialogrc            — Dark TUI theme (loaded by DIALOGRC in init_dialog)
└── gum.tar.gz          — Bundled gum v0.17.0 binary (static ELF x86-64, ~4.5 MB)

presets/                — desktop-amd.conf, desktop-intel.conf, desktop-nvidia-open.conf
hooks/                  — *.sh.example
```

### Kluczowe moduly

#### lib/bootstrap.sh
- `apk --root ${MOUNTPOINT} --initdb` do instalacji bazowej (zamiast chimera-bootstrap)
- `apk_install()` — wrapper na `apk add` w chroot
- `apk_install_if_available()` — sprawdza dostepnosc w repo
- `enable_community_repo()` / `enable_testing_repo()` — zarzadzanie repozytoriami

#### lib/system.sh — wielofunkcyjny modul
- `kernel_install()` — `apk add linux-lts` lub `linux-edge` + linux-firmware + microcode + `mkinitfs`
- `install_networking()` — NetworkManager + `rc-update add networkmanager default`
- `system_create_users()` — shadow (useradd), doas (nie sudo), SSH
- `generate_fstab()` — manualna generacja (Alpine nie ma genfstab)
- `system_finalize()` — wlaczanie uslug OpenRC (devfs, dmesg, mdev, hwdrivers, hwclock, modules, sysctl, hostname, bootmisc, syslog, eudev)

#### lib/bootloader.sh
- GRUB: `grub grub-efi` + `grub-install --target=x86_64-efi` + `grub-mkconfig -o /boot/grub/grub.cfg`
- systemd-boot: `efibootmgr` + manual loader.conf + boot entries
- Oba z wsparciem LUKS i dual-boot

#### lib/desktop.sh — 6 srodowisk
- **KDE Plasma**: plasma-desktop + sddm + elogind
- **GNOME**: gnome-shell + gdm + elogind
- **XFCE**: xfce4 + lightdm + elogind
- **Sway**: sway + greetd + waybar + wofi + foot
- **niri**: niri + niri-portalsconf + greetd + waybar + fuzzel + foot
- **none**: bez desktopu (console only)
- Wspolne: PipeWire + elogind + GPU drivers (mesa-vulkan-*)

### Konwencje (identyczne jak w Gentoo/Chimera/Void/NixOS)

- Ekrany TUI: `screen_*()` zwracaja 0=next, 1=back, 2=abort
- `try` — interaktywne recovery na bledach, text fallback bez dialog, `LIVE_OUTPUT=1` via tee
- Checkpointy — wznowienie po awarii, `checkpoint_validate` weryfikuje artefakty, `checkpoint_migrate_to_target` przenosi na dysk docelowy
- `cleanup_target_disk` — odmontowuje partycje i swap przed partycjonowaniem
- `--resume` — skanuje dyski (`try_resume_from_disk`), 0=config+checkpoints, 1=tylko checkpoints (inference), 2=nic
- `infer_config_from_partition` — odczytuje konfiguracje z fstab, hostname, localtime, conf.d, crypttab
- `${VAR@Q}` — bezpieczny quoting w configach
- `(( var++ )) || true` — pod set -e
- `_ALPINE_INSTALLER` — guard w protection.sh
- `chroot_exec` — wrapper na plain chroot

### Roznice vs Chimera i inne installery

| | Alpine | Chimera | Gentoo | NixOS |
|---|--------|---------|--------|-------|
| Bootstrap | apk --root --initdb | chimera-bootstrap | stage3 + emerge | nixos-install |
| Pkg mgr | apk add | apk add | emerge | deklaratywny (nix) |
| Init | OpenRC (rc-update) | dinit (dinitctl) | systemd/OpenRC | systemd |
| Kernel | apk add linux-lts | apk add linux-lts | genkernel/dist-kernel | nixos-generate-config |
| Initramfs | mkinitfs | update-initramfs | dracut/genkernel | nixos-generate-config |
| Bootloader | grub-mkconfig | update-grub | grub-mkconfig | systemd-boot |
| Users | shadow + doas | useradd + doas | useradd + sudo | deklaratywne |
| GPU | open-source only | open-source only | proprietary OK | proprietary OK |
| Session | elogind | Turnstile | systemd-logind | systemd-logind |
| Service mgmt | rc-update add | dinitctl enable | systemctl/rc-update | deklaratywne |
| Desktopy | 6 (KDE/GNOME/XFCE/Sway/niri/none) | 2 (KDE/GNOME) | 2 (KDE/GNOME) | 2 (KDE/GNOME) |

### Alpine Linux specyfika

- `rc-update add <service> default` — wlaczanie uslug w runlevel default
- `rc-update add <service> boot` — wlaczanie uslug w runlevel boot
- `rc-update add <service> sysinit` — wlaczanie uslug w runlevel sysinit
- `doas` zamiast `sudo` — konfiguracja w `/etc/doas.d/wheel.conf`
- `mkinitfs` — generowanie initramfs (Alpine-specyficzny)
- `grub-mkconfig -o /boot/grub/grub.cfg` — regeneracja konfiguracji GRUB
- `elogind` — session manager (zamiast systemd-logind i Turnstile)
- `greetd` — login manager dla Sway/niri (lekka alternatywa dla SDDM/GDM)
- `eudev` — device manager (zamiast systemd-udevd)
- `shadow` — pelne useradd/chpasswd (busybox wersje sa ograniczone)
- Brak init system choice — zawsze OpenRC
- Brak CPU march flags — binarne paczki, nie kompilowane
- `linux-lts` / `linux-edge` — dwa warianty kernela
- `/etc/apk/repositories` — konfiguracja repozytoriow (main, community, testing)

### niri support

niri dostepny w Alpine `community` repo od v3.23 (edge od wczesniej). Pakiety:
- `niri` — compositor (5.1 MB pkg, 12.4 MB installed)
- `niri-portalsconf` — xdg-desktop-portal configuration

Instalacja w desktop.sh: `_install_niri()` + greetd + waybar + fuzzel + mako + foot + xdg-desktop-portal-gnome.

Takze dostepne jako dodatkowy compositor z extra_packages.sh (ENABLE_NIRI flag).

### gum TUI backend

Third TUI backend alongside `dialog` and `whiptail`. Static binary bundled as `data/gum.tar.gz` (gum v0.17.0, ~4.5 MB). Zero network dependencies.

- Detection priority: gum > dialog > whiptail. Opt-out: `GUM_BACKEND=0`
- Desc→tag mapping via parallel arrays (gum 0.17.0 `--label-delimiter` is broken)
- Phantom ESC detection: `EPOCHREALTIME` with 150ms threshold, 3 retries then text fallback
- Terminal response handling: `COLORFGBG="15;0"`, `stty -echo`, `_gum_drain_tty()`

### Hybrid GPU detection

`detect_gpu()` scans ALL GPUs from `lspci -nn` (not just `head -1`). Classification:
- NVIDIA = always dGPU; Intel = always iGPU; AMD — if NVIDIA also present then iGPU, otherwise single
- PCI slot heuristic: bus `00` = iGPU, `01+` = dGPU
- When 2 GPUs: `HYBRID_GPU=yes`, `IGPU_*`, `DGPU_*` set
- Alpine uses open-source GPU drivers only — no PRIME offload config needed

### Peripheral detection

6 detection functions in `lib/hardware.sh`, called from `detect_all_hardware()`:
- `detect_bluetooth()` — `/sys/class/bluetooth/hci*`
- `detect_fingerprint()` — USB vendor IDs (06cb, 27c6, 147e, 138a, 04f3)
- `detect_thunderbolt()` — sysfs + lspci
- `detect_sensors()` — IIO sysfs
- `detect_webcam()` — `/sys/class/video4linux/video*/name`
- `detect_wwan()` — `lspci -nnd 8086:7360`

### CONFIG_VARS

```
DESKTOP_ENV, TARGET_DISK, PARTITION_SCHEME, FILESYSTEM, BTRFS_SUBVOLUMES
LUKS_ENABLED, LUKS_PARTITION, SWAP_TYPE, SWAP_SIZE_MIB
HOSTNAME, LOCALE, TIMEZONE, KEYMAP, KERNEL_TYPE, BOOTLOADER_TYPE
GPU_VENDOR, GPU_DEVICE_ID, GPU_DEVICE_NAME, GPU_DRIVER
HYBRID_GPU, IGPU_VENDOR, IGPU_DEVICE_NAME, DGPU_VENDOR, DGPU_DEVICE_NAME
DESKTOP_EXTRAS, ENABLE_FLATPAK, ENABLE_PRINTING, ENABLE_BLUETOOTH, ENABLE_SSH
BLUETOOTH_DETECTED, FINGERPRINT_DETECTED, ENABLE_FINGERPRINT
THUNDERBOLT_DETECTED, ENABLE_THUNDERBOLT, SENSORS_DETECTED, ENABLE_SENSORS
WEBCAM_DETECTED, WWAN_DETECTED, ENABLE_WWAN
ROOT_PASSWORD_HASH, USERNAME, USER_PASSWORD_HASH, USER_GROUPS
ENABLE_HYPRLAND, ENABLE_NIRI, ENABLE_GAMING, EXTRA_PACKAGES
ESP_PARTITION, ESP_REUSE, ROOT_PARTITION, SWAP_PARTITION
WINDOWS_DETECTED, LINUX_DETECTED, DETECTED_OSES_SERIALIZED
SHRINK_PARTITION, SHRINK_PARTITION_FSTYPE, SHRINK_NEW_SIZE_MIB
ALPINE_MIRROR
```

## Jak dodawac opcje

1. Dodaj zmienna do `CONFIG_VARS[]` w `lib/constants.sh`
2. Dodaj ekran TUI lub rozszerz istniejacy
3. Dodaj logike w odpowiednim module lib/
4. Dodaj test
