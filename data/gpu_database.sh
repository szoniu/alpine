#!/usr/bin/env bash
# data/gpu_database.sh — GPU recommendation for Alpine Linux
# Alpine Linux uses open-source drivers
source "${LIB_DIR}/protection.sh"

# get_gpu_recommendation — Return driver|firmware recommendation
# Usage: get_gpu_recommendation "vendor_id" "device_id"
# Returns: "driver|firmware_pkg|notes"
get_gpu_recommendation() {
    local vendor_id="$1"
    local device_id="$2"

    case "${vendor_id}" in
        "10de")
            # NVIDIA — nouveau (open-source)
            echo "nouveau|linux-firmware-nvidia|Open-source only (nouveau)"
            ;;
        "1002")
            # AMD — RADV (Vulkan) + AMDGPU kernel driver
            # Best GPU support on Alpine Linux
            echo "radv|linux-firmware-amdgpu|Recommended (full open-source support)"
            ;;
        "8086")
            # Intel — ANV (Vulkan) + i915/xe kernel driver
            echo "anv||Intel integrated graphics"
            ;;
        *)
            echo "mesa||Generic Mesa drivers"
            ;;
    esac
}

# get_gpu_packages — Return list of apk packages for GPU
# Usage: get_gpu_packages "vendor"
get_gpu_packages() {
    local vendor="$1"

    case "${vendor}" in
        nvidia)
            echo "mesa mesa-dri-gallium vulkan-loader mesa-vulkan-nouveau linux-firmware-nvidia"
            ;;
        amd)
            echo "mesa mesa-dri-gallium vulkan-loader mesa-vulkan-ati linux-firmware-amdgpu"
            ;;
        intel)
            echo "mesa mesa-dri-gallium vulkan-loader mesa-vulkan-intel"
            ;;
        *)
            echo "mesa mesa-dri-gallium"
            ;;
    esac
}

# get_hybrid_gpu_recommendation — Return GPU packages for hybrid iGPU+dGPU setup
# Usage: get_hybrid_gpu_recommendation "igpu_vendor" "dgpu_vendor"
get_hybrid_gpu_recommendation() {
    local igpu="$1" dgpu="$2"
    local pkgs=""

    case "${igpu}" in
        intel) pkgs="mesa mesa-dri-gallium vulkan-loader mesa-vulkan-intel" ;;
        amd)   pkgs="mesa mesa-dri-gallium vulkan-loader mesa-vulkan-ati linux-firmware-amdgpu" ;;
    esac

    case "${dgpu}" in
        nvidia) pkgs+=" mesa-vulkan-nouveau linux-firmware-nvidia" ;;
        amd)    pkgs+=" mesa-vulkan-ati linux-firmware-amdgpu" ;;
    esac

    echo "${pkgs}"
}

# get_microcode_package — Return CPU microcode package name
# Usage: get_microcode_package "cpu_vendor"
get_microcode_package() {
    local vendor="$1"

    case "${vendor}" in
        GenuineIntel)
            echo "intel-ucode"
            ;;
        AuthenticAMD)
            echo "amd-ucode"
            ;;
        *)
            echo ""
            ;;
    esac
}
