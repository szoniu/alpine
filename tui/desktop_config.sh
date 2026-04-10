#!/usr/bin/env bash
# tui/desktop_config.sh — Desktop environment selection + apps + extras
source "${LIB_DIR}/protection.sh"

# _app_state — Return "on" if app is in DESKTOP_EXTRAS, "off" otherwise
_app_state() {
    local app="$1" default="$2"
    if [[ -z "${DESKTOP_EXTRAS:-}" ]]; then
        echo "${default}"
    elif echo "${DESKTOP_EXTRAS}" | tr -d '"' | grep -qw "${app}"; then
        echo "on"
    else
        echo "off"
    fi
}

screen_desktop_config() {
    # Desktop environment selection
    local de
    de=$(dialog_menu "Desktop Environment" \
        "kde"   "KDE Plasma 6 — Full-featured desktop (SDDM)" \
        "gnome" "GNOME — Modern desktop (GDM)" \
        "xfce"  "XFCE — Lightweight traditional desktop (LightDM)" \
        "sway"  "Sway — Tiling Wayland compositor (greetd)" \
        "niri"  "niri — Scrollable-tiling Wayland compositor (greetd)" \
        "none"  "No desktop — Console only") \
        || return "${TUI_BACK}"

    DESKTOP_ENV="${de}"
    export DESKTOP_ENV

    # DE-specific app selection
    case "${de}" in
        kde)   _select_kde_apps   || return "${TUI_BACK}" ;;
        gnome) _select_gnome_apps || return "${TUI_BACK}" ;;
        xfce)  _select_xfce_apps  || return "${TUI_BACK}" ;;
        sway)  _select_sway_apps  || return "${TUI_BACK}" ;;
        niri)  _select_niri_apps  || return "${TUI_BACK}" ;;
        none)  DESKTOP_EXTRAS="" ; export DESKTOP_EXTRAS ;;
    esac

    # Optional extras (shared between DEs) — skip for console-only
    if [[ "${de}" != "none" ]]; then
        _select_extras || return "${TUI_BACK}"
    fi

    einfo "Desktop: ${DESKTOP_ENV}, extras: ${DESKTOP_EXTRAS}"
    return "${TUI_NEXT}"
}

_select_kde_apps() {
    dialog_msgbox "KDE Plasma" \
        "KDE Plasma 6 will be installed.\n\n\
Includes:\n\
  * Plasma Desktop + Wayland\n\
  * SDDM display manager\n\
  * PipeWire audio\n\
  * Konsole terminal + Dolphin file manager\n\n\
You can select additional applications on the next screen." \
        || return 1

    local apps
    apps=$(dialog_checklist "KDE Applications" \
        "kate"        "Kate — advanced text editor"       "$(_app_state kate on)" \
        "firefox"     "Firefox — web browser"             "$(_app_state firefox on)" \
        "gwenview"    "Gwenview — image viewer"           "$(_app_state gwenview on)" \
        "okular"      "Okular — document viewer"          "$(_app_state okular on)" \
        "ark"         "Ark — archive manager"             "$(_app_state ark on)" \
        "spectacle"   "Spectacle — screenshot tool"       "$(_app_state spectacle on)" \
        "kcalc"       "KCalc — calculator"                "$(_app_state kcalc off)" \
        "elisa"       "Elisa — music player"              "$(_app_state elisa off)" \
        "vlc"         "VLC — media player"                "$(_app_state vlc off)" \
        "libreoffice" "LibreOffice — office suite"        "$(_app_state libreoffice off)" \
        "thunderbird" "Thunderbird — email client"        "$(_app_state thunderbird off)") \
        || return 1

    DESKTOP_EXTRAS="${apps}"
    export DESKTOP_EXTRAS
}

_select_gnome_apps() {
    dialog_msgbox "GNOME" \
        "GNOME will be installed.\n\n\
Includes:\n\
  * GNOME Shell + Wayland\n\
  * GDM display manager\n\
  * PipeWire audio\n\
  * Nautilus file manager + GNOME Console\n\n\
You can select additional applications on the next screen." \
        || return 1

    local apps
    apps=$(dialog_checklist "GNOME Applications" \
        "firefox"          "Firefox — web browser"             "$(_app_state firefox on)" \
        "gnome-text-editor" "Text Editor"                      "$(_app_state gnome-text-editor on)" \
        "evince"           "Evince — document viewer"          "$(_app_state evince on)" \
        "loupe"            "Loupe — image viewer"              "$(_app_state loupe on)" \
        "gnome-calculator" "Calculator"                        "$(_app_state gnome-calculator on)" \
        "gnome-weather"    "Weather"                           "$(_app_state gnome-weather off)" \
        "gnome-clocks"     "Clocks"                            "$(_app_state gnome-clocks off)" \
        "vlc"              "VLC — media player"                "$(_app_state vlc off)" \
        "libreoffice"      "LibreOffice — office suite"        "$(_app_state libreoffice off)" \
        "thunderbird"      "Thunderbird — email client"        "$(_app_state thunderbird off)") \
        || return 1

    DESKTOP_EXTRAS="${apps}"
    export DESKTOP_EXTRAS
}

_select_xfce_apps() {
    dialog_msgbox "XFCE" \
        "XFCE will be installed.\n\n\
Includes:\n\
  * XFCE Desktop\n\
  * LightDM display manager\n\
  * PipeWire audio\n\
  * Thunar file manager + xfce4-terminal\n\n\
You can select additional applications on the next screen." \
        || return 1

    local apps
    apps=$(dialog_checklist "XFCE Applications" \
        "thunar"       "Thunar — file manager"              "$(_app_state thunar on)" \
        "mousepad"     "Mousepad — text editor"             "$(_app_state mousepad on)" \
        "ristretto"    "Ristretto — image viewer"           "$(_app_state ristretto on)" \
        "firefox"      "Firefox — web browser"              "$(_app_state firefox on)" \
        "libreoffice"  "LibreOffice — office suite"         "$(_app_state libreoffice off)" \
        "thunderbird"  "Thunderbird — email client"         "$(_app_state thunderbird off)" \
        "vlc"          "VLC — media player"                 "$(_app_state vlc off)") \
        || return 1

    DESKTOP_EXTRAS="${apps}"
    export DESKTOP_EXTRAS
}

_select_sway_apps() {
    dialog_msgbox "Sway" \
        "Sway will be installed.\n\n\
Includes:\n\
  * Sway tiling Wayland compositor\n\
  * greetd login manager\n\
  * PipeWire audio\n\n\
You can select additional applications on the next screen." \
        || return 1

    local apps
    apps=$(dialog_checklist "Sway Applications" \
        "foot"     "foot — Wayland terminal"            "$(_app_state foot on)" \
        "firefox"  "Firefox — web browser"              "$(_app_state firefox on)" \
        "thunar"   "Thunar — file manager"              "$(_app_state thunar off)" \
        "imv"      "imv — image viewer"                 "$(_app_state imv off)") \
        || return 1

    DESKTOP_EXTRAS="${apps}"
    export DESKTOP_EXTRAS
}

_select_niri_apps() {
    dialog_msgbox "niri" \
        "niri will be installed.\n\n\
Includes:\n\
  * niri scrollable-tiling Wayland compositor\n\
  * greetd login manager\n\
  * PipeWire audio\n\n\
You can select additional applications on the next screen." \
        || return 1

    local apps
    apps=$(dialog_checklist "niri Applications" \
        "foot"     "foot — Wayland terminal"            "$(_app_state foot on)" \
        "firefox"  "Firefox — web browser"              "$(_app_state firefox on)" \
        "thunar"   "Thunar — file manager"              "$(_app_state thunar off)" \
        "imv"      "imv — image viewer"                 "$(_app_state imv off)") \
        || return 1

    DESKTOP_EXTRAS="${apps}"
    export DESKTOP_EXTRAS
}

_select_extras() {
    local _flatpak_state="off" _printing_state="off" _bluetooth_state="on"
    [[ "${ENABLE_FLATPAK:-no}" == "yes" ]] && _flatpak_state="on"
    [[ "${ENABLE_PRINTING:-no}" == "yes" ]] && _printing_state="on"
    [[ "${ENABLE_BLUETOOTH:-yes}" == "no" ]] && _bluetooth_state="off"

    local extras
    extras=$(dialog_checklist "Optional Features" \
        "flatpak"    "Flatpak — universal package manager" "${_flatpak_state}" \
        "printing"   "CUPS printing support"               "${_printing_state}" \
        "bluetooth"  "Bluetooth support"                   "${_bluetooth_state}") \
        || return 1

    ENABLE_FLATPAK="no"
    ENABLE_PRINTING="no"
    ENABLE_BLUETOOTH="no"

    local cleaned
    cleaned=$(echo "${extras}" | tr -d '"')
    local item
    for item in ${cleaned}; do
        case "${item}" in
            flatpak)    ENABLE_FLATPAK="yes" ;;
            printing)   ENABLE_PRINTING="yes" ;;
            bluetooth)  ENABLE_BLUETOOTH="yes" ;;
        esac
    done

    export ENABLE_FLATPAK ENABLE_PRINTING ENABLE_BLUETOOTH
}
