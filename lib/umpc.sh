#!/usr/bin/env bash
# umpc.sh — Runtime quirks for UMPCs (GPD Pocket/Win, Chuwi MiniBook X).
# Panel rotation for console + Wayland session is handled via GRUB cmdline
# in bootloader.sh. This module installs:
#   - ALC287 Auto-Mute disable (Pocket 4 speakers are silent without it)
#   - SDDM X11 greeter rotation (Xorg ignores the kernel panel_orientation
#     quirk, so the login screen alone stays portrait without this)
#   - POST-INSTALL note for gpd-fan-daemon (no Alpine package yet)
#
# Alpine is OpenRC-only and driven from the OUTER installer process: unlike the
# Gentoo module (which runs inside the chroot with absolute paths), every file
# write here goes through chroot_exec, and packages through apk_install. Paths
# in the chroot_exec heredocs are therefore relative to the chroot root.
source "${LIB_DIR}/protection.sh"

# umpc_apply_quirks — Entry point called from the umpc_quirks phase.
umpc_apply_quirks() {
    [[ "${UMPC_DETECTED:-0}" == "1" ]] || return 0

    einfo "Applying UMPC runtime quirks for ${UMPC_VENDOR} ${UMPC_MODEL}..."

    if [[ "${UMPC_ALC287_QUIRK:-0}" == "1" ]]; then
        _umpc_install_alc287_unmute
    fi

    # SDDM's X11 greeter doesn't honor the kernel panel_orientation quirk
    # (only the console + Wayland session do), so the login screen stays
    # portrait. Rotate it explicitly via xrandr in Xsetup.
    if [[ -n "${UMPC_FBCON_ROTATE:-}" ]] && [[ "${UMPC_FBCON_ROTATE}" != "0" ]]; then
        _umpc_rotate_sddm_greeter
    fi

    if [[ "${UMPC_GPD_FAN:-0}" == "1" ]]; then
        _umpc_write_gpd_fan_note
    fi

    # Always emit a generic UMPC summary so users see what was done
    _umpc_append_summary
}

# _umpc_install_alc287_unmute — Auto-Mute Mode = Disabled at every boot.
# ALC287 on Pocket 4 (and many AMD Phoenix laptops) ships with Auto-Mute
# enabled by default, which routes audio nowhere unless a headphone jack
# is sensed correctly. The driver's jack detection is unreliable on this
# codec, so speakers stay silent. Fix: disable Auto-Mute via amixer at
# boot. amixer comes from alsa-utils, pulled in by the PipeWire/ALSA stack.
# On Alpine the boot hook is OpenRC's local.d (run by the 'local' service,
# enabled in system_finalize's default runlevel).
_umpc_install_alc287_unmute() {
    einfo "  Installing ALC287 Auto-Mute disable service..."

    # The script itself — runs amixer commands. Card index 0 is the usual
    # internal HDA on these devices. Tolerate failure if the control names
    # differ on this specific codec revision.
    chroot_exec "cat > /usr/local/sbin/alc287-unmute << 'SCRIPTEOF'
#!/bin/sh
# alc287-unmute — Disable ALC287 Auto-Mute Mode and unmute Master/Speaker.
# Installed by the Alpine installer for UMPCs with ALC287 quirks (GPD Pocket 4).
# Runs at every boot via OpenRC local.d.
set -u

# Wait briefly for the sound card to be enumerated (race with udev on boot).
for _ in 1 2 3 4 5; do
    if [ -e /proc/asound/card0 ]; then break; fi
    sleep 1
done

# Disable Auto-Mute (the actual fix). Tolerant of missing control.
amixer -c 0 sset 'Auto-Mute Mode' Disabled >/dev/null 2>&1 || true

# Unmute and raise common output controls. PipeWire sets userspace volumes
# separately; this just makes sure the hardware mixer isn't gating audio.
for ctl in 'Master' 'Speaker' 'Headphone' 'PCM'; do
    amixer -c 0 sset \"\${ctl}\" unmute >/dev/null 2>&1 || true
    amixer -c 0 sset \"\${ctl}\" '100%' >/dev/null 2>&1 || true
done

# Persist state so alsactl restore on next boot keeps it if alsa-restore runs.
alsactl store >/dev/null 2>&1 || true

exit 0
SCRIPTEOF"
    chroot_exec "chmod 0755 /usr/local/sbin/alc287-unmute"

    # OpenRC: drop into local.d which is run by the 'local' service. The
    # 'local' service is added to the default runlevel in system_finalize.
    chroot_exec "mkdir -p /etc/local.d"
    chroot_exec "cat > /etc/local.d/alc287-unmute.start << 'LOCALEOF'
#!/bin/sh
/usr/local/sbin/alc287-unmute
LOCALEOF"
    chroot_exec "chmod 0755 /etc/local.d/alc287-unmute.start"

    # Ensure the 'local' service runs local.d at boot (system_finalize also
    # adds it; idempotent here so the quirk works even if order changes).
    chroot_exec "rc-update add local default" 2>/dev/null || true
}

# _umpc_rotate_sddm_greeter — Rotate the SDDM X11 login greeter.
# The kernel panel_orientation quirk (set in the GRUB cmdline) rotates the
# fbcon console and is honored by the Plasma *Wayland* session, but SDDM's
# greeter runs on Xorg, which ignores panel_orientation — so the login
# screen alone stays portrait on a UMPC. Fix: rotate it with xrandr from
# Xsetup. Two gotchas learned on a GPD Pocket 4:
#   - Xorg names the panel "eDP" (NOT the DRM name "eDP-1") — auto-detect
#     the connected output instead of hardcoding it.
#   - xrandr is NOT pulled in by the Plasma meta package; without it Xsetup
#     fails silently (command not found) and nothing rotates.
# fbcon rotate value -> xrandr rotation: 1=right (90 CW), 2=inverted,
# 3=left (90 CCW). Verified: Pocket 4 fbcon=rotate:1 <-> xrandr right.
_umpc_rotate_sddm_greeter() {
    # Only meaningful when SDDM is the display manager (Plasma). GDM/greetd
    # Wayland greeters honor panel_orientation on their own. Alpine ships
    # KDE(SDDM)/GNOME(GDM)/XFCE(LightDM)/Sway+niri(greetd) — guard on SDDM.
    if ! chroot_exec "test -d /usr/share/sddm" 2>/dev/null; then
        einfo "  No SDDM present — skipping greeter rotation"
        return 0
    fi

    local rot
    case "${UMPC_FBCON_ROTATE}" in
        1) rot="right" ;;
        2) rot="inverted" ;;
        3) rot="left" ;;
        *) return 0 ;;
    esac

    einfo "  Rotating SDDM greeter (xrandr --rotate ${rot})..."

    # xrandr is required and not pulled by the Plasma meta package.
    apk_install "Installing xrandr (SDDM greeter rotation)" xrandr

    chroot_exec "mkdir -p /usr/share/sddm/scripts"
    chroot_exec "cat > /usr/share/sddm/scripts/Xsetup << XSETUPEOF
#!/bin/sh
# Xsetup — rotate the SDDM X11 greeter to match the UMPC panel.
# Xorg names the internal panel \"eDP\" (not the DRM \"eDP-1\"), so detect
# the connected output rather than hardcoding it. Written by the Alpine
# installer (umpc_quirks) for UMPCs with a rotated panel.
_out=\\\$(xrandr | awk '/ connected/{print \\\$1; exit}')
[ -n \"\\\${_out}\" ] && xrandr --output \"\\\${_out}\" --rotate ${rot}
XSETUPEOF"
    chroot_exec "chmod 0755 /usr/share/sddm/scripts/Xsetup"
    einfo "  SDDM greeter rotation configured (output auto-detected, --rotate ${rot})"
}

# _umpc_write_gpd_fan_note — Append manual install instructions for
# gpd-fan-daemon to /root/POST-INSTALL-NOTES.txt. No Alpine package exists,
# so we cannot auto-install. Without the daemon, fans run on ACPI defaults —
# usable but louder than Windows. The daemon enable step is documented as a
# hand-written OpenRC service (upstream ships a systemd unit only).
_umpc_write_gpd_fan_note() {
    einfo "  Writing GPD fan daemon POST-INSTALL note..."

    chroot_exec "mkdir -p /root"
    chroot_exec "touch /root/POST-INSTALL-NOTES.txt"
    chroot_exec "chmod 0600 /root/POST-INSTALL-NOTES.txt"

    chroot_exec "cat >> /root/POST-INSTALL-NOTES.txt << NOTEEOF

=== GPD Fan Control (${UMPC_MODEL}) ===

The installer did NOT install a userspace fan daemon — there is no Alpine
package for gpd-fan-daemon yet. Fans currently run on ACPI table defaults:
usable, but louder/more aggressive than under Windows.

To set up smarter fan curves manually post-install:

1. Kernel module (gpd-fan) — needs kernel headers + build tools:
     # apk add linux-${KERNEL_TYPE:-lts}-dev build-base
     git clone https://github.com/Cryolitia/gpd-fan-driver
     cd gpd-fan-driver && make && make install
     modprobe gpd_fan

2. Userspace daemon (gpd-fan-daemon):
     # apk add rust cargo
     git clone https://github.com/Cryolitia/gpd-fan-daemon
     cd gpd-fan-daemon
     cargo build --release
     install -m 0755 target/release/gpd-fan-daemon /usr/local/sbin/

NOTEEOF"

    # OpenRC: document a hand-written openrc-run service (upstream is systemd).
    chroot_exec "cat >> /root/POST-INSTALL-NOTES.txt << 'NOTEEOF'
3. Enable the daemon (OpenRC) — upstream ships only a systemd unit,
   so create an openrc-run service. Paste this block flush-left:

cat > /etc/init.d/gpd-fan-daemon << 'EOF'
#!/sbin/openrc-run
name=\"gpd-fan-daemon\"
description=\"GPD fan curve daemon\"
command=\"/usr/local/sbin/gpd-fan-daemon\"
command_background=\"yes\"
pidfile=\"/run/gpd-fan-daemon.pid\"

depend() {
	after modules
}
EOF
chmod 0755 /etc/init.d/gpd-fan-daemon
rc-update add gpd-fan-daemon default
rc-service gpd-fan-daemon start

For temperature/fan monitoring without the daemon:
     # apk add lm-sensors
     sensors-detect --auto
     sensors

NOTEEOF"
}

# _umpc_append_summary — Document everything we applied so the user can
# audit it after reboot.
_umpc_append_summary() {
    chroot_exec "mkdir -p /root"
    chroot_exec "touch /root/POST-INSTALL-NOTES.txt"
    chroot_exec "chmod 0600 /root/POST-INSTALL-NOTES.txt"

    chroot_exec "cat >> /root/POST-INSTALL-NOTES.txt << NOTEEOF

=== UMPC Quirks Applied (${UMPC_VENDOR} ${UMPC_MODEL}) ===

NOTEEOF"

    if [[ -n "${UMPC_PANEL_ORIENTATION:-}" ]]; then
        chroot_exec "cat >> /root/POST-INSTALL-NOTES.txt << NOTEEOF
- Panel rotation: added to /etc/default/grub:
    fbcon=rotate:${UMPC_FBCON_ROTATE} video=${UMPC_VIDEO_CONNECTOR}:panel_orientation=${UMPC_PANEL_ORIENTATION}
  If rotation is wrong: try left_side_up instead of right_side_up, or
  change fbcon=rotate to 3. Edit /etc/default/grub, then
  'grub-mkconfig -o /boot/grub/grub.cfg'.

NOTEEOF"
    fi

    if [[ "${UMPC_ALC287_QUIRK:-0}" == "1" ]]; then
        chroot_exec "cat >> /root/POST-INSTALL-NOTES.txt << NOTEEOF
- ALC287 speakers: alc287-unmute service installed
  (/usr/local/sbin/alc287-unmute, runs at every boot via local.d)
  If still quiet: 'alsamixer' -> F6 select card -> unmute everything,
  then 'alsactl store'.

NOTEEOF"
    fi
}
