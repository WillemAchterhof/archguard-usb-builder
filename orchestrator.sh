#!/usr/bin/env bash

# ==============================================================================
# ArchGuard USB Builder - Orchestrator
# ==============================================================================
# /orchestrator.sh

# ==============================================================================
# Initialization
# ==============================================================================

DIR_MAIN="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DIR_LIB="$DIR_MAIN/lib"
DIR_MODULES="$DIR_MAIN/modules"
DIR_MENU="$DIR_MAIN/menu"

# ==============================================================================
# Global Libraries
# ==============================================================================

source "$DIR_LIB/logging.sh"
source "$DIR_LIB/common.sh"
source "$DIR_LIB/errors.sh"
source "$DIR_LIB/check-usb.sh"

trap 'trap_err' ERR
trap 'trap_int' INT TERM

# ==============================================================================
# Modules
# ==============================================================================

source "$DIR_MODULES/select-disk.sh"
source "$DIR_MODULES/confirm-destruction.sh"
source "$DIR_MODULES/create-iso.sh"
source "$DIR_MODULES/create-usb.sh"
source "$DIR_MODULES/create-key-storage.sh"
source "$DIR_MODULES/create-boot-storage.sh"
source "$DIR_MODULES/backup-configuration-files.sh"
source "$DIR_MODULES/new-certificates.sh"
source "$DIR_MENU/menu-run.sh"


# ==============================================================================
# Small Menu Functions
# ==============================================================================

toggle_custom_certificate() {
    if (( NEW_CERT == 1 )); then
        restore_original_custom_certificate
    else
        create_new_custom_certificate
    fi
}

create_custom_iso_and_write_usb() {

    confirm_usb_overwrite || return 0
    run_build_iso || return $?
    run_create_usb || return $?
    create_key_storage || return $?
    create_boot_storage || return $?

    success "USB creation workflow completed."
    return 0
}

select_new_usbdisk(){
    if run_selectdisk; then
        msg "USB disk selection updated."
    else
        msg "USB disk selection cancelled."
    fi
}

# ==============================================================================
# Render Menu
# ==============================================================================

main_menu() {
    local choice

    start_sudo_keepalive

    if ! run_selectdisk; then
        msg "Exiting ArchGuard USB Builder."
        cleanup
        return 0
    fi

    while true; do
        clear

        echo "=================================="
        echo "       ArchGuard USB Builder"
        echo "=================================="
        echo
        echo "  1) Create Custom ISO and Write to USB"
        echo "  2) Backup Configuration Files"
        echo "  3) Configuration Menu"
        echo
        
                if (( NEW_CERT == 1 )); then
                    echo "  c) Certificate: New"
                else
                    echo "  c) Certificate: Current"
                fi
        
        echo "  s) Select new USB"
        echo
        echo "  q) Exit"
        echo
        echo "=================================="

        if ! IFS= read -r -p "Select an option: " choice; then
            msg "Exiting ArchGuard USB Builder."
            cleanup
            return 0
        fi
        case "$choice" in
            1)
                create_custom_iso_and_write_usb
                ;;
            2)
                backup_configuration_files
                ;;
            3)
                configuration_menu
                ;;
            c)
                toggle_custom_certificate
                ;;
            s)
                select_new_usbdisk
                ;;
            q|Q)
                msg "Exiting ArchGuard USB Builder."
                cleanup
                return 0
                ;;
            *)
                continue
                ;;
        esac
        
                echo
                read -r -p "Press Enter to return to the main menu..." _ || true
            done
        }

main_menu "$@"
