# Alpine Linux TUI Installer

Interaktywny installer Alpine Linux z interfejsem TUI (dialog). Przeprowadza za reke przez caly proces instalacji — od partycjonowania dysku po dzialajacy desktop KDE Plasma, GNOME, XFCE, Sway lub niri.

Alpine Linux: musl libc + OpenRC + apk + minimalistyczny i bezpieczny. Binarne paczki, instalacja w ~10-20 minut. Najlzejsza dystrybucja z pelnym wsparciem desktop.

## Krok po kroku

### 1. Przygotuj bootowalny pendrive

Pobierz Alpine Linux ISO:

- https://alpinelinux.org/downloads/ -> **Extended** (zalecany, ma firmware i dodatkowe narzedzia)

Nagraj na pendrive:

```bash
# UWAGA: /dev/sdX to pendrive, nie dysk systemowy!
sudo dd if=alpine-extended-*.iso of=/dev/sdX bs=4M status=progress
sync
```

Na Windows: [Rufus](https://rufus.ie) lub [balenaEtcher](https://etcher.balena.io).

### 2. Bootuj z pendrive

- BIOS/UEFI: F2, F12, lub Del przy starcie
- **Wylacz Secure Boot**
- Boot z USB w trybie **UEFI**
- Login: `root` (bez hasla)

### 3. Polacz sie z internetem

#### Kabel LAN

Powinno dzialac od razu:

```bash
ping -c 3 alpinelinux.org
```

#### WiFi

**`wpa_supplicant`** (dostepny na Alpine Live):

```bash
# Wlacz interfejs
ip link set wlan0 up

# Skanuj sieci
iwlist wlan0 scan | grep ESSID

# Polacz
wpa_passphrase 'NazwaSieci' 'TwojeHaslo' > /etc/wpa_supplicant.conf
wpa_supplicant -B -i wlan0 -c /etc/wpa_supplicant.conf
udhcpc -i wlan0
```

**`setup-interfaces`** (interaktywne narzedzie Alpine):

```bash
setup-interfaces
```

Sprawdz: `ping -c 3 alpinelinux.org`

### 4. Ustaw date (wazne!)

Live ISO moze miec nieprawidlowa date systemowa. Ustaw ja **przed** klonowaniem repo:

```bash
date -s "2026-04-10 12:00:00"
```

Bez poprawnej daty `git clone` moze nie dzialac (blad SSL "certificate is not yet valid").

### 5. Sklonuj repo i uruchom

```bash
apk add bash git
git clone https://github.com/szoniu/alpine.git
cd alpine
./install.sh
```

Albo bez git:

```bash
apk add bash
wget -O- https://github.com/szoniu/alpine/archive/main.tar.gz | tar xz
cd alpine-main
./install.sh
```

### 6. Po instalacji

Wyjmij pendrive, reboot. Zobaczysz bootloader (GRUB lub systemd-boot), potem ekran logowania (SDDM/GDM/LightDM/greetd zaleznie od DE).

Po zalogowaniu — aktualizacja systemu i pakietow:

```bash
doas apk upgrade
```

Instalacja nowych pakietow:

```bash
doas apk add pakiet
```

## Alternatywne uruchomienie

```bash
# Tylko konfiguracja (generuje plik .conf, nic nie instaluje)
./install.sh --configure

# Instalacja z gotowego configa (bez wizarda)
./install.sh --config moj-config.conf --install

# Wznow po awarii (skanuje dyski w poszukiwaniu checkpointow)
./install.sh --resume

# Dry-run — przechodzi caly flow BEZ dotykania dyskow
./install.sh --dry-run

# Z presetu (np. dla kolegi z AMD)
./install.sh --config presets/desktop-amd.conf --install
```

## Wymagania

- Komputer z **UEFI** (nie Legacy BIOS)
- **Secure Boot wylaczony**
- Minimum **10 GiB** wolnego miejsca na dysku (4 GiB dla console-only)
- Internet (LAN lub WiFi)
- Alpine Linux Live ISO (Extended zalecany); `dialog`/`whiptail` opcjonalny — installer ma zaszyty `gum`

## Co robi installer

| # | Ekran | Co konfigurujesz |
|---|-------|-------------------|
| 1 | Welcome | Sprawdzenie wymagan (root, UEFI, siec) |
| 2 | Preset | Opcjonalne zaladowanie gotowej konfiguracji |
| 3 | Hardware | Podglad wykrytego CPU, GPU (hybrid), dyskow, peryferiow, Windows/Linux |
| 4 | Dysk | Wybor dysku + schemat (auto/dual-boot/manual) |
| 5 | Filesystem | ext4 / btrfs / XFS + opcjonalne LUKS szyfrowanie |
| 6 | Swap | zram / partycja / brak |
| 7 | Siec | Hostname |
| 8 | Locale | Timezone + keymap |
| 9 | Bootloader | GRUB / systemd-boot |
| 10 | Kernel | LTS / Edge |
| 11 | GPU | AMD (RADV) / Intel (ANV) / NVIDIA (nouveau, open-source) |
| 12 | Desktop | KDE Plasma / GNOME / XFCE / Sway / niri / brak (console) |
| 13 | Uzytkownicy | Root, user, grupy, SSH |
| 14 | Pakiety | Dodatkowe pakiety apk + Hyprland / niri ecosystem + opcje sprzetowe |
| 15 | Preset save | Eksport konfiguracji |
| 16 | Podsumowanie | Przeglad + potwierdzenie YES + countdown |

Po potwierdzeniu installer:
1. Partycjonuje dysk (opcjonalnie z LUKS)
2. Instaluje system bazowy (`apk --root --initdb`)
3. Wchodzi do chroota
4. Instaluje kernel, bootloader, wybrane DE
5. Konfiguruje system (timezone, hostname, uzytkownicy, OpenRC services)
6. Wlacza uslugi OpenRC (SDDM/GDM/LightDM/greetd, NetworkManager, elogind, etc.)

## Srodowiska desktopowe

| DE | Display Manager | Opis |
|---|---|---|
| **KDE Plasma** | SDDM | Pelny desktop z Konsole, Dolphin, PipeWire |
| **GNOME** | GDM | Nowoczesny desktop z Nautilus, GNOME Terminal |
| **XFCE** | LightDM | Lekki tradycyjny desktop z Thunar, Mousepad |
| **Sway** | greetd | Tiling Wayland compositor (i3-compatible) z foot, waybar, wofi |
| **niri** | greetd | Scrollable-tiling Wayland compositor z foot, waybar, fuzzel |
| **brak** | — | Tylko konsola (serwer, router, kontener) |

### niri

[niri](https://github.com/YaLTeR/niri) to scrollable-tiling Wayland compositor napisany w Rust. Dostepny w Alpine **community** repo od v3.23. Instalacja:

```bash
apk add niri niri-portalsconf
```

Installer automatycznie konfiguruje niri z greetd (login manager), waybar, fuzzel (launcher), mako (powiadomienia), foot (terminal).

## Dual-boot z Windows/Linux

- Auto-wykrywanie ESP z Windows Boot Manager i innych Linuksow
- ESP nigdy nie jest formatowany przy reuse
- GRUB + os-prober automatycznie widzi Windows
- Wizard do zmniejszania partycji jesli brak wolnego miejsca (NTFS, ext4, btrfs)
- Ostrzezenia o istniejacych OS-ach na wybranych partycjach

## Presety

```
presets/desktop-amd.conf           # AMD + ext4 + GRUB
presets/desktop-intel.conf         # Intel + btrfs + systemd-boot
presets/desktop-nvidia-open.conf   # NVIDIA (open) + LUKS + GRUB
```

Presety przenosne — sprzet re-wykrywany przy imporcie.

## Typowe problemy

### `git clone` nie dziala (SSL certificate not yet valid)

Live ISO ma zla date. Napraw:

```bash
date -s "2026-04-10 12:00:00"
```

### DNS nie dziala (Temporary failure in name resolution)

```bash
echo "nameserver 8.8.8.8" >> /etc/resolv.conf
```

Installer probuje to naprawic automatycznie (ensure_dns), ale jesli nie — dodaj recznie.

### Instalacja przez SSH

Na Alpine Live mozesz podlaczyc sie przez SSH z innego komputera:

```bash
# Na Live ISO:
passwd root                     # Ustaw haslo roota
rc-service sshd start           # Uruchom SSH (OpenRC)

# Sprawdz IP:
ip -4 addr show | grep inet
```

Z innego komputera:

```bash
ssh -o PubkeyAuthentication=no root@ADRES_IP
```

> **Uwaga**: Jesli laptop jest na innej sieci (np. WiFi dla gosci), SSH nie zadziala. Oba urzadzenia musza byc w tej samej sieci LAN.

> **Tip**: Po restarcie Live ISO klucz SSH sie zmienia. Jesli `ssh` odmawia polaczenia ("WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED"), uruchom: `ssh-keygen -R ADRES_IP`

#### Uzyj tmux — ochrona przed zerwaniem sesji SSH

**Wazne:** Jesli polaczenie SSH sie zerwie, instalacja w zwyklej sesji zostanie przerwana. **Zawsze uruchamiaj installer w tmux:**

```bash
# Na Live ISO (po polaczeniu SSH):
apk add tmux
tmux new -s install

# Sklonuj repo i uruchom installer wewnatrz tmux
git clone https://github.com/szoniu/alpine.git
cd alpine
./install.sh
```

Jesli polaczenie SSH sie zerwie:
```bash
# Polacz sie ponownie i wroc do sesji
ssh -o PubkeyAuthentication=no root@ADRES_IP
tmux attach -t install
```

Instalacja bedzie nadal dzialac w tle — nic nie stracisz.

### Drugie TTY — twoj najlepszy przyjaciel

Podczas instalacji masz dostep do wielu konsol. Przelaczaj sie przez **Ctrl+Alt+F1**...**F6**:

- **TTY1** — installer (tu leci instalacja)
- **TTY2-6** — wolne konsole do debugowania

Na drugim TTY mozesz:

```bash
# Podglad co sie dzieje w czasie rzeczywistym
top

# Log installera
tail -f /tmp/alpine-installer.log                  # przed chroot
tail -f /media/root/tmp/alpine-installer.log       # w chroot

# Sprawdz czy cos nie zawieszilo sie
ps aux | grep -E "tee|apk|mkinitfs"
```

## Co jesli cos pojdzie nie tak

- **Blad** — menu: Retry / Shell / Continue / Log / Abort
- **Awaria** — checkpointy faz, wznowienie od ostatniego kroku
- **Log** — `/tmp/alpine-installer.log`
- **Wznowienie** — po awarii/restarcie: `./install.sh --resume` skanuje dyski, odzyskuje config i checkpointy, i wznawia od ostatniego ukonczonego kroku

## Roznice vs inne installery

| | Alpine | Chimera | Gentoo | NixOS |
|---|--------|---------|--------|-------|
| Czas | ~10-20 min | ~15-30 min | 3-8h | ~15-30 min |
| Pakiety | apk (binarne) | apk (binarne) | emerge (ze zrodel) | nix (binarne) |
| Init | OpenRC | dinit | systemd/OpenRC | systemd |
| libc | musl | musl | glibc | glibc |
| GPU | open-source | open-source | proprietary OK | proprietary OK |
| Desktopy | 6 opcji | 2 opcje | 2 opcje | 2 opcje |
| Min. dysk | 4-10 GiB | 20 GiB | 60 GiB | 20 GiB |

## Interfejs TUI

Installer ma trzy backendy TUI (w kolejnosci priorytetu):

1. **gum** (domyslny) — nowoczesny, zaszyty w repo jako `data/gum.tar.gz` (~4.5 MB). Ekstraowany automatycznie do `/tmp` na starcie. Zero dodatkowych zaleznosci.
2. **dialog** — klasyczny TUI, dostepny na wiekszosci live ISO
3. **whiptail** — fallback gdy brak `dialog`

Backend jest wybierany automatycznie. Zeby wymusic fallback na `dialog`/`whiptail`:

```bash
GUM_BACKEND=0 ./install.sh
```

### Aktualizacja gum

Zeby zaktualizowac bundlowana wersje gum:

```bash
# 1. Pobierz nowy tarball (podmien wersje)
curl -fSL -o data/gum.tar.gz \
  "https://github.com/charmbracelet/gum/releases/download/v0.18.0/gum_0.18.0_Linux_x86_64.tar.gz"

# 2. Zaktualizuj GUM_VERSION w lib/constants.sh (musi pasowac do nazwy podkatalogu w tarballi)
#    : "${GUM_VERSION:=0.18.0}"
```

## Hooki (zaawansowane)

Wlasne skrypty uruchamiane przed/po fazach instalacji:

```bash
cp hooks/before_install.sh.example hooks/before_install.sh
chmod +x hooks/before_install.sh
# Edytuj hook...
```

Dostepne hooki: `before_install`, `after_install`, `before_preflight`, `after_preflight`, `before_disks`, `after_disks`, `before_bootstrap`, `after_bootstrap`, `before_chroot_setup`, `after_chroot_setup`, `before_apk_update`, `after_apk_update`, `before_kernel`, `after_kernel`, `before_fstab`, `after_fstab`, `before_system_config`, `after_system_config`, `before_bootloader`, `after_bootloader`, `before_swap_setup`, `after_swap_setup`, `before_networking`, `after_networking`, `before_desktop`, `after_desktop`, `before_users`, `after_users`, `before_extras`, `after_extras`, `before_finalize`, `after_finalize`.

## Wykrywanie peryferiow

Installer automatycznie wykrywa sprzet i wyswietla go w ekranie Hardware:

| Peryferium | Metoda detekcji | Pakiet (opt-in w checklistie) |
|---|---|---|
| Bluetooth | `/sys/class/bluetooth/hci*` | automatycznie z desktopem |
| Czytnik linii papilarnych | USB vendor IDs (Synaptics, Goodix, AuthenTec, Validity, Elan) | `fprintd` |
| Thunderbolt | sysfs + lspci | `bolt` |
| Czujniki IIO (2-in-1) | `/sys/bus/iio/devices/` (accel, gyro, als) | `iio-sensor-proxy` |
| Kamera | `/sys/class/video4linux/video*/name` | — |
| WWAN LTE | lspci (Intel XMM7360) | `modemmanager` |

Wykryty sprzet pojawia sie jako opcje w ekranie "Dodatkowe pakiety" — widoczne tylko gdy odpowiedni sprzet zostal wykryty.

## Opcje CLI

```
./install.sh [OPCJE] [POLECENIE]

Polecenia:
  (domyslnie)      Pelna instalacja (wizard + install)
  --configure       Tylko wizard konfiguracyjny
  --install         Tylko instalacja (wymaga configa)
  --resume          Wznow po awarii (skanuje dyski)

Opcje:
  --config PLIK     Uzyj podanego pliku konfiguracji
  --dry-run         Symulacja bez destrukcyjnych operacji
  --force           Kontynuuj mimo nieudanych prereq
  --non-interactive Przerwij na kazdym bledzie (bez recovery menu)
  --help            Pokaz pomoc

Zmienne srodowiskowe:
  GUM_BACKEND=0     Wymusz fallback na dialog/whiptail (pomin gum)
```

## Struktura

```
install.sh              — Entry point
configure.sh            — Wrapper: tylko wizard
lib/                    — 16 modulow (constants, logging, dialog, hardware, disk, bootstrap...)
tui/                    — 17 ekranow TUI
data/                   — GPU database, dialogrc theme, gum binary cache
presets/                — Gotowe presety
hooks/                  — before/after hooks
```

## FAQ

**P: Jak dlugo trwa instalacja?**
~10-20 minut (binarne paczki). Zalezy od predkosci internetu i wybranego DE.

**P: Moge na VM?**
Tak, UEFI mode. VirtualBox: Settings -> System -> Enable EFI.

**P: Dlaczego nie ma sterownikow NVIDIA proprietary?**
Alpine Linux uzywa musl libc i nie wspiera proprietarnych sterownikow NVIDIA. Uzywany jest nouveau (open-source).

**P: Czym jest OpenRC?**
Init system Alpine Linux. Zamiast `systemctl` uzywasz `rc-service start/stop` i `rc-update add/del`.

**P: Czym jest doas?**
Alpine uzywa `doas` zamiast `sudo`. Skladnia: `doas apk add pakiet`.

**P: Czym jest niri?**
Scrollable-tiling Wayland compositor napisany w Rust. Dostepny w Alpine community repo od v3.23. Alternatywa dla Sway/Hyprland z unikatowym layoutem przewijanym.

**P: Moge uzyc innego live ISO niz Alpine?**
Tak, dowolne live ISO z Linuxem zadziala, pod warunkiem ze ma `bash`, `apk-tools`, `sfdisk`. Installer ma zaszyty `gum` jako backend TUI, wiec `dialog`/`whiptail` nie jest wymagany.

**P: Co jesli `gum` nie dziala?**
Installer automatycznie uzyje `dialog` lub `whiptail` jako fallback. Mozesz tez wymusic fallback: `GUM_BACKEND=0 ./install.sh`.

**P: Mam multi-boot (kilka Linuxów). Po aktualizacji kernela inne systemy zniknęły z GRUB.**
Ostatni zainstalowany GRUB jest master bootloaderem. Po aktualizacji kernela w dowolnym systemie trzeba odswiezyc GRUB:

```bash
doas grub-mkconfig -o /boot/grub/grub.cfg
```
