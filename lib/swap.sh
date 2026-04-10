#!/usr/bin/env bash
# swap.sh — zram, swap partition/file configuration for Alpine Linux (OpenRC)
source "${LIB_DIR}/protection.sh"

# swap_setup — Configure swap based on SWAP_TYPE
swap_setup() {
    local swap_type="${SWAP_TYPE:-zram}"

    case "${swap_type}" in
        zram)
            swap_setup_zram
            ;;
        partition)
            einfo "Swap partition configured during disk setup"
            ;;
        none)
            einfo "No swap configured"
            ;;
    esac
}

# swap_setup_zram — Configure zram swap via OpenRC init script
swap_setup_zram() {
    einfo "Setting up zram swap..."

    # Install zram-init package if available
    apk_install_if_available zram-init

    local mem_kb
    mem_kb=$(awk '/MemTotal/{print $2}' /proc/meminfo 2>/dev/null) || mem_kb=0
    local zram_size_kb=$(( mem_kb / 2 ))
    local zram_size_mb=$(( zram_size_kb / 1024 ))
    [[ "${zram_size_mb}" -lt 256 ]] && zram_size_mb=256
    [[ "${zram_size_kb}" -lt 262144 ]] && zram_size_kb=262144

    # Create OpenRC init script for zram swap
    chroot_exec "cat > /etc/init.d/zram-swap << 'ZRAMEOF'
#!/sbin/openrc-run

description=\"zram compressed swap device\"

depend() {
    need localmount
    after modules
}

start() {
    ebegin \"Setting up zram swap\"
    modprobe zram 2>/dev/null
    echo zstd > /sys/block/zram0/comp_algorithm 2>/dev/null || true
    echo ZRAM_SIZE_KB > /sys/block/zram0/disksize
    mkswap /dev/zram0
    swapon -p 100 /dev/zram0
    eend \$?
}

stop() {
    ebegin \"Removing zram swap\"
    swapoff /dev/zram0 2>/dev/null
    echo 1 > /sys/block/zram0/reset 2>/dev/null
    eend \$?
}
ZRAMEOF"

    # Replace placeholder with actual size
    chroot_exec "sed -i 's/ZRAM_SIZE_KB/${zram_size_kb}K/' /etc/init.d/zram-swap"
    chroot_exec "chmod +x /etc/init.d/zram-swap"

    # Enable the service
    try "Enabling zram swap" \
        chroot_exec "rc-update add zram-swap boot"

    einfo "zram configured (${zram_size_mb}M, zstd)"
}
