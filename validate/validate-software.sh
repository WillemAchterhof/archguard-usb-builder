#!/usr/bin/env bash
# ArchGuard USB Builder - Software Configuration Validation
# /validate/validate-software.sh

validate_software() {
    local package
    local -a package_groups=(
        ARCHGUARD_BASE
        SYSTEM_SUPPORT
        PLASMA
        KVM_PACKAGES
        EXTRA_PACKAGES
    )
    local -a missing_packages=()

    msg "Checking software package availability..."

    if ! command -v pacman >/dev/null 2>&1; then
        msg "Pacman is not available."
        return 1
    fi

    for group in "${package_groups[@]}"; do
        # Skip optional groups that are not defined.
        declare -p "$group" &>/dev/null || continue

        local -n packages="$group"

        for package in "${packages[@]}"; do
            if ! pacman -Si "$package" &>/dev/null; then
                missing_packages+=("$package")
            fi
        done

        unset -n packages
    done

    if (( ${#missing_packages[@]} > 0 )); then
        msg "The following packages were not found in the repositories:"

        for package in "${missing_packages[@]}"; do
            msg "  - $package"
        done

        return 1
    fi

    success "All software packages are available."
    return 0
}
