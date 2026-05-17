#!/usr/bin/env bash
# desktop.sh — Desktop environments for Alpine Linux
# Supported: KDE Plasma, GNOME, XFCE, Sway, niri, none
# All use OpenRC services and elogind for session management
source "${LIB_DIR}/protection.sh"

# desktop_install — Install selected desktop environment
desktop_install() {
    local de="${DESKTOP_ENV:-kde}"

    if [[ "${de}" == "none" ]]; then
        einfo "No desktop environment selected"
        return 0
    fi

    # Install GPU drivers first (shared)
    _install_gpu_drivers

    # Shared base: fonts, polkit, session management. Needed by every DE.
    _install_common_desktop

    case "${de}" in
        kde)   _install_kde ;;
        gnome) _install_gnome ;;
        xfce)  _install_xfce ;;
        sway)  _install_sway ;;
        niri)  _install_niri ;;
    esac

    # Shared: PipeWire, Bluetooth, optional extras
    _install_pipewire
    _install_bluetooth
    _install_extras

    einfo "Desktop installation complete"
}

# _install_common_desktop — Packages/services every desktop needs out of box:
# fonts (a bare Alpine has no scalable fonts → tofu everywhere), polkit, and
# elogind session management.
_install_common_desktop() {
    einfo "Installing common desktop base (fonts, polkit, elogind)..."

    apk_install "Installing fonts" \
        font-dejavu font-noto font-noto-emoji ttf-liberation \
        fontconfig

    # polkit + elogind authentication agent backend (shared by all DEs).
    apk_install "Installing polkit" polkit polkit-elogind

    # elogind: seat/session manager (replaces systemd-logind). Must be in the
    # boot runlevel so a seat exists before display managers / greetd start.
    apk_install "Installing elogind" elogind
    chroot_exec "rc-update add elogind boot" 2>/dev/null || true
    chroot_exec "rc-update add polkit default" 2>/dev/null || true

    # dbus is installed/enabled in install_networking; ensure it is present
    # even if networking somehow ran without it.
    apk_install_if_available dbus
    chroot_exec "rc-update add dbus default" 2>/dev/null || true
}

# _install_xorg — X server stack for X11 desktops / display managers.
# SDDM and LightDM run on X by default; without xorg-server the greeter cannot
# start and there is no login screen at all.
_install_xorg() {
    apk_install "Installing Xorg" \
        xorg-server xf86-input-libinput xf86-video-fbdev \
        xinit xrandr setxkbmap xwayland mesa-dri-gallium
}

# --- KDE Plasma ---

_install_kde() {
    einfo "Installing KDE Plasma desktop..."

    # SDDM (default Plasma greeter) runs on X — Xorg stack is mandatory.
    _install_xorg

    apk_install "Installing KDE Plasma" \
        plasma-desktop plasma-workspace plasma-pa plasma-nm \
        kde-cli-tools kscreen polkit-kde-agent-1
    apk_install "Installing SDDM" sddm sddm-breeze

    _install_kde_apps
    _install_kde_lang

    # Enable SDDM via OpenRC
    try "Enabling SDDM" \
        chroot_exec "rc-update add sddm default"

    _configure_plasma

    einfo "KDE Plasma installed"
}

_install_kde_apps() {
    local extras="${DESKTOP_EXTRAS:-}"

    apk_install "Installing basic KDE apps" \
        konsole dolphin

    if [[ -n "${extras}" ]]; then
        local cleaned
        cleaned=$(echo "${extras}" | tr -d '"')
        local pkg
        for pkg in ${cleaned}; do
            apk_install_if_available "${pkg}"
        done
    fi
}

_install_kde_lang() {
    local locale="${LOCALE:-en_US.UTF-8}"
    local lang="${locale%%_*}"

    if [[ "${lang}" == "en" ]]; then
        einfo "English locale — no extra language packs needed"
        return 0
    fi

    einfo "Installing KDE language packs for: ${lang}"

    # Alpine has no legacy `kde-l10n`; translations ship as per-component
    # *-lang subpackages.
    local -a lang_pkgs=(
        plasma-desktop-lang
        plasma-workspace-lang
        kde-cli-tools-lang
        dolphin-lang
        konsole-lang
    )

    local pkg
    for pkg in "${lang_pkgs[@]}"; do
        apk_install_if_available "${pkg}"
    done
}

_configure_plasma() {
    einfo "Configuring Plasma defaults..."

    # SDDM theme
    chroot_exec "mkdir -p /etc/sddm.conf.d"
    chroot_exec "cat > /etc/sddm.conf.d/alpine.conf << 'SDDMEOF'
[Theme]
Current=breeze

[General]
InputMethod=
SDDMEOF"

    # Plasma language for new users via skel
    local locale="${LOCALE:-en_US.UTF-8}"
    local lang="${locale%%_*}"
    if [[ "${lang}" != "en" ]]; then
        chroot_exec "mkdir -p /etc/skel/.config"
        chroot_exec "cat > /etc/skel/.config/plasma-localerc << PLEOF
[Formats]
LANG=${locale}

[Translations]
LANGUAGE=${lang}
PLEOF"
    fi

    # dbus
    try "Enabling dbus" \
        chroot_exec "rc-update add dbus default" 2>/dev/null || true

    einfo "Plasma defaults configured"
}

# --- GNOME ---

_install_gnome() {
    einfo "Installing GNOME desktop..."

    # GDM/GNOME run on Wayland but need Xorg for the X11 session + Xwayland.
    _install_xorg

    apk_install "Installing GNOME" \
        gnome-shell gnome-session gnome-control-center gnome-terminal \
        nautilus gnome-tweaks adwaita-icon-theme gnome-keyring \
        xdg-desktop-portal-gnome xdg-user-dirs
    apk_install "Installing GDM" gdm

    # dconf + accountsservice needed for locale/session configuration
    apk_install_if_available dconf
    apk_install_if_available accountsservice

    _install_gnome_apps
    _install_gnome_lang

    # Enable GDM via OpenRC
    try "Enabling GDM" \
        chroot_exec "rc-update add gdm default"

    _configure_gnome

    einfo "GNOME installed"
}

_install_gnome_apps() {
    local extras="${DESKTOP_EXTRAS:-}"

    if [[ -n "${extras}" ]]; then
        local cleaned
        cleaned=$(echo "${extras}" | tr -d '"')
        local pkg
        for pkg in ${cleaned}; do
            apk_install_if_available "${pkg}"
        done
    fi
}

_install_gnome_lang() {
    local locale="${LOCALE:-en_US.UTF-8}"
    local lang="${locale%%_*}"

    if [[ "${lang}" == "en" ]]; then
        einfo "English locale — no extra language packs needed"
        return 0
    fi

    einfo "Installing GNOME language packs for: ${lang}"

    local -a lang_pkgs=(
        gnome-shell-lang
        glib-lang
        gtk4.0-lang
        nautilus-lang
        gnome-control-center-lang
    )

    local pkg
    for pkg in "${lang_pkgs[@]}"; do
        apk_install_if_available "${pkg}"
    done
}

_configure_gnome() {
    einfo "Configuring GNOME defaults..."

    # dbus
    try "Enabling dbus" \
        chroot_exec "rc-update add dbus default" 2>/dev/null || true

    # GNOME locale — set via AccountsService for GDM + GNOME session
    local locale="${LOCALE:-en_US.UTF-8}"
    local lang="${locale%%_*}"

    if [[ "${lang}" != "en" ]]; then
        chroot_exec "mkdir -p /etc/dconf/profile"
        chroot_exec "cat > /etc/dconf/profile/user << 'DCONFEOF'
user-db:user
system-db:local
DCONFEOF"
        chroot_exec "mkdir -p /etc/dconf/db/local.d"
        chroot_exec "cat > /etc/dconf/db/local.d/00-locale << LOCEOF
[system/locale]
region='${locale}'
format-locale='${locale}'
LOCEOF"
        chroot_exec "dconf update" 2>/dev/null || true

        chroot_exec "mkdir -p /etc/skel/.config"
        chroot_exec "cat > /etc/skel/.config/gnome-initial-setup-done << 'GISEOF'
yes
GISEOF"
    fi

    einfo "GNOME defaults configured"
}

# --- XFCE ---

_install_xfce() {
    einfo "Installing XFCE desktop..."

    # XFCE is X11-only and LightDM runs on X — Xorg stack is mandatory.
    _install_xorg

    apk_install "Installing XFCE" \
        xfce4 xfce4-terminal xfce4-screensaver mousepad \
        thunar thunar-volman ristretto xfce4-pulseaudio-plugin \
        xfce4-power-manager network-manager-applet
    apk_install "Installing LightDM" lightdm lightdm-gtk-greeter

    _install_xfce_apps

    # Enable LightDM via OpenRC
    try "Enabling LightDM" \
        chroot_exec "rc-update add lightdm default"

    # dbus
    try "Enabling dbus" \
        chroot_exec "rc-update add dbus default" 2>/dev/null || true

    einfo "XFCE installed"
}

_install_xfce_apps() {
    local extras="${DESKTOP_EXTRAS:-}"

    if [[ -n "${extras}" ]]; then
        local cleaned
        cleaned=$(echo "${extras}" | tr -d '"')
        local pkg
        for pkg in ${cleaned}; do
            apk_install_if_available "${pkg}"
        done
    fi
}

# _setup_greetd_seat — seat management + greetd for wlroots compositors.
# Sway/niri need a seat: seatd (libseat) + the user in the `seat` group, plus
# elogind (enabled in _install_common_desktop, boot runlevel). Without this the
# compositor dies with "Cannot get DRM master" → black screen.
# $1 = session command run by agreety (e.g. "sway", "niri-session")
_setup_greetd_seat() {
    local session_cmd="$1"

    apk_install "Installing seatd" seatd
    chroot_exec "rc-update add seatd default" 2>/dev/null || true

    apk_install "Installing greetd" greetd greetd-agreety
    chroot_exec "rc-update add greetd default" 2>/dev/null || true

    chroot_exec "mkdir -p /etc/greetd"
    chroot_exec "cat > /etc/greetd/config.toml << GREETEOF
[terminal]
vt = 7

[default_session]
command = \"agreety --cmd ${session_cmd}\"
user = \"greetd\"
GREETEOF"
    # greetd reads its config as the greetd user.
    chroot_exec "chown -R greetd:greetd /etc/greetd 2>/dev/null || true"
}

# --- Sway ---

_install_sway() {
    einfo "Installing Sway compositor..."

    apk_install "Installing Sway" \
        sway swaylock swayidle swaybg foot \
        waybar wofi mako grim slurp wl-clipboard \
        brightnessctl xdg-desktop-portal-wlr polkit-elogind \
        xwayland

    _install_sway_apps

    # Seat management + graphical login (greetd + seatd).
    _setup_greetd_seat "sway"

    # Create Sway session file for display managers
    if ! chroot_exec "test -f /usr/share/wayland-sessions/sway.desktop" 2>/dev/null; then
        chroot_exec "mkdir -p /usr/share/wayland-sessions"
        chroot_exec "cat > /usr/share/wayland-sessions/sway.desktop << 'SWAYEOF'
[Desktop Entry]
Name=Sway
Comment=An i3-compatible Wayland compositor
Exec=sway
Type=Application
DesktopNames=sway
SWAYEOF"
    fi

    einfo "Sway installed"
}

_install_sway_apps() {
    local extras="${DESKTOP_EXTRAS:-}"

    if [[ -n "${extras}" ]]; then
        local cleaned
        cleaned=$(echo "${extras}" | tr -d '"')
        local pkg
        for pkg in ${cleaned}; do
            apk_install_if_available "${pkg}"
        done
    fi
}

# --- niri ---

_install_niri() {
    einfo "Installing niri compositor..."

    # niri is in Alpine community repo since v3.23
    enable_community_repo

    apk_install "Installing niri" niri
    apk_install_if_available niri-portalsconf

    # Install companion tools (niri is a compositor, needs supporting tools)
    apk_install "Installing niri companion tools" \
        waybar fuzzel mako grim slurp wl-clipboard \
        brightnessctl foot xdg-desktop-portal-gnome \
        polkit-elogind xwayland

    _install_niri_apps

    # Seat management + graphical login (greetd + seatd).
    _setup_greetd_seat "niri-session"

    # Create niri session file for display managers
    if ! chroot_exec "test -f /usr/share/wayland-sessions/niri.desktop" 2>/dev/null; then
        chroot_exec "mkdir -p /usr/share/wayland-sessions"
        chroot_exec "cat > /usr/share/wayland-sessions/niri.desktop << 'NIRIEOF'
[Desktop Entry]
Name=niri
Comment=A scrollable-tiling Wayland compositor
Exec=niri-session
Type=Application
DesktopNames=niri
NIRIEOF"
    fi

    einfo "niri installed"
}

_install_niri_apps() {
    local extras="${DESKTOP_EXTRAS:-}"

    if [[ -n "${extras}" ]]; then
        local cleaned
        cleaned=$(echo "${extras}" | tr -d '"')
        local pkg
        for pkg in ${cleaned}; do
            apk_install_if_available "${pkg}"
        done
    fi
}

# --- Shared ---

# _install_gpu_drivers — Install GPU-specific open-source drivers
_install_gpu_drivers() {
    local vendor="${GPU_VENDOR:-unknown}"

    einfo "Installing GPU drivers for ${vendor} (open-source)..."

    apk_install "Installing Mesa" mesa mesa-dri-gallium

    if [[ "${HYBRID_GPU:-no}" == "yes" ]]; then
        einfo "Hybrid GPU setup: ${IGPU_VENDOR:-?} iGPU + ${DGPU_VENDOR:-?} dGPU"

        case "${IGPU_VENDOR:-}" in
            amd) _install_amd_drivers ;;
            intel) _install_intel_drivers ;;
        esac
        case "${DGPU_VENDOR:-}" in
            nvidia) _install_nvidia_open ;;
            amd) _install_amd_drivers ;;
        esac
    else
        case "${vendor}" in
            nvidia) _install_nvidia_open ;;
            amd)    _install_amd_drivers ;;
            intel)  _install_intel_drivers ;;
            *)      einfo "No specific GPU driver to install" ;;
        esac
    fi

    apk_install "Installing Vulkan loader" vulkan-loader
}

_install_nvidia_open() {
    einfo "Installing NVIDIA open-source drivers (nouveau)..."
    # Alpine has no `mesa-vulkan-nouveau`. nouveau GL is provided by the
    # gallium DRI driver (installed in _install_gpu_drivers); add the swrast
    # Vulkan ICD as a software fallback so Vulkan apps still run.
    apk_install_if_available mesa-vulkan-swrast
    apk_install_if_available linux-firmware-nvidia
    apk_install_if_available xf86-video-nouveau
    ewarn "Note: Alpine does not support NVIDIA proprietary drivers."
    ewarn "Using nouveau (open-source). Vulkan falls back to software (slow)."
}

_install_amd_drivers() {
    einfo "Installing AMD GPU drivers..."
    apk_install_if_available mesa-vulkan-ati
    apk_install_if_available linux-firmware-amdgpu
    einfo "AMD GPU drivers installed (RADV Vulkan)"
}

_install_intel_drivers() {
    einfo "Installing Intel GPU drivers..."
    apk_install_if_available mesa-vulkan-intel
    apk_install_if_available linux-firmware-intel
    einfo "Intel GPU drivers installed (ANV Vulkan)"
}

# _install_pipewire — Install PipeWire audio system
_install_pipewire() {
    einfo "Installing PipeWire audio..."
    apk_install "Installing PipeWire" \
        pipewire wireplumber pipewire-pulse pipewire-alsa \
        pipewire-jack alsa-utils

    # rtkit gives PipeWire realtime priority (glitch-free audio).
    apk_install_if_available rtkit

    # Alpine's pipewire package does not ship XDG autostart files. Without an
    # autostart there is no sound on any desktop. Add session-agnostic entries
    # that every DE's autostart honours.
    chroot_exec "mkdir -p /etc/xdg/autostart"
    chroot_exec "cat > /etc/xdg/autostart/pipewire.desktop << 'PWEOF'
[Desktop Entry]
Type=Application
Name=PipeWire Media System
Exec=/usr/bin/pipewire
X-GNOME-Autostart-Phase=Initialization
PWEOF"
    chroot_exec "cat > /etc/xdg/autostart/wireplumber.desktop << 'WPEOF'
[Desktop Entry]
Type=Application
Name=WirePlumber Session Manager
Exec=/usr/bin/wireplumber
X-GNOME-Autostart-Phase=Initialization
WPEOF"
    chroot_exec "cat > /etc/xdg/autostart/pipewire-pulse.desktop << 'PPEOF'
[Desktop Entry]
Type=Application
Name=PipeWire PulseAudio
Exec=/usr/bin/pipewire-pulse
X-GNOME-Autostart-Phase=Initialization
PPEOF"

    einfo "PipeWire installed (XDG autostart configured)"
}

# _install_bluetooth — Auto-install Bluetooth support if hardware detected
_install_bluetooth() {
    if [[ "${BLUETOOTH_DETECTED:-0}" == "1" ]] || [[ "${ENABLE_BLUETOOTH:-no}" == "yes" ]]; then
        einfo "Installing Bluetooth support..."
        apk_install "Installing Bluetooth" bluez bluez-openrc
        try "Enabling Bluetooth" \
            chroot_exec "rc-update add bluetooth default" 2>/dev/null || true
        ENABLE_BLUETOOTH="yes"
        export ENABLE_BLUETOOTH
    fi
}

# _install_printing — Auto-install printing support
_install_printing() {
    if [[ "${ENABLE_PRINTING:-no}" == "yes" ]]; then
        einfo "Installing printing support..."
        apk_install "Installing CUPS" cups cups-filters
        try "Enabling CUPS" \
            chroot_exec "rc-update add cupsd default" 2>/dev/null || true
    fi
}

# _install_extras — Install optional extras (Flatpak, printing)
_install_extras() {
    if [[ "${ENABLE_FLATPAK:-no}" == "yes" ]]; then
        einfo "Installing Flatpak..."
        apk_install "Installing Flatpak" flatpak
        chroot_exec "flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo" 2>/dev/null || true
    fi

    _install_printing
}

# install_hyprland_ecosystem — Hyprland + waybar, wofi, mako, grim, slurp, wl-clipboard, brightnessctl
install_hyprland_ecosystem() {
    if [[ "${ENABLE_HYPRLAND:-no}" != "yes" ]]; then
        return 0
    fi
    einfo "Installing Hyprland ecosystem..."

    # Ensure community repo is enabled
    enable_community_repo

    # Check if hyprland is available
    if ! chroot_exec "apk search -e hyprland" >> "${LOG_FILE}" 2>&1; then
        ewarn "Hyprland is not available in Alpine repos"
        ewarn "It may need to be built from source after installation"
        ewarn "Skipping Hyprland — installing compatible tools only"

        local -a standalone_pkgs=(waybar wofi mako grim slurp wl-clipboard brightnessctl)
        local pkg
        for pkg in "${standalone_pkgs[@]}"; do
            apk_install_if_available "${pkg}"
        done
        return 0
    fi

    local -a pkgs=(hyprland hyprpaper hypridle hyprlock
        waybar wofi mako grim slurp wl-clipboard brightnessctl
        xdg-desktop-portal-hyprland)
    local pkg
    for pkg in "${pkgs[@]}"; do
        apk_install_if_available "${pkg}"
    done

    # Ensure Hyprland session file exists for display manager session selector
    if ! chroot_exec "test -f /usr/share/wayland-sessions/hyprland.desktop" 2>/dev/null; then
        einfo "Creating Hyprland session file for display manager..."
        chroot_exec "mkdir -p /usr/share/wayland-sessions"
        chroot_exec "cat > /usr/share/wayland-sessions/hyprland.desktop << 'HYPREOF'
[Desktop Entry]
Name=Hyprland
Comment=An intelligent dynamic tiling Wayland compositor
Exec=Hyprland
Type=Application
DesktopNames=Hyprland
HYPREOF"
    fi

    einfo "Hyprland ecosystem installed"
}

# install_niri_standalone — Install niri as additional compositor (from extra_packages)
install_niri_standalone() {
    if [[ "${ENABLE_NIRI:-no}" != "yes" ]]; then
        return 0
    fi
    # If niri is already the main DE, skip
    if [[ "${DESKTOP_ENV:-}" == "niri" ]]; then
        return 0
    fi
    einfo "Installing niri as additional compositor..."
    enable_community_repo
    apk_install_if_available niri
    apk_install_if_available niri-portalsconf
    einfo "niri installed as additional compositor"
}

# install_gaming — Gaming support (Steam via Flatpak, gamescope)
install_gaming() {
    if [[ "${ENABLE_GAMING:-no}" != "yes" ]]; then
        return 0
    fi
    einfo "Installing gaming support..."

    apk_install_if_available gamescope

    # Steam via Flatpak (native Steam not available on musl)
    if [[ "${ENABLE_FLATPAK:-no}" == "yes" ]]; then
        einfo "Steam will be available via Flatpak after first login:"
        einfo "  flatpak install flathub com.valvesoftware.Steam"
    fi

    einfo "Gaming support installed"
}

# install_extra_packages — Install user-specified extra packages
install_extra_packages() {
    if [[ -n "${EXTRA_PACKAGES:-}" ]]; then
        einfo "Installing extra packages: ${EXTRA_PACKAGES}"
        local pkg
        for pkg in ${EXTRA_PACKAGES}; do
            if [[ ! "${pkg}" =~ ^[a-zA-Z0-9][a-zA-Z0-9_./-]*$ ]]; then
                ewarn "Skipping invalid package name: ${pkg}"
                continue
            fi
            apk_install_if_available "${pkg}"
        done
    fi
}
