#!/usr/bin/env bash
set -Eeuo pipefail

# ==============================================================================
#  ArchGuard USB Builder - Orchestrator
# ==============================================================================
# /orchestrator.sh

# ==============================================================================
# Initialization
# ==============================================================================

DIR_MAIN="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DIR_LIB="$DIR_MAIN/lib"
DIR_MODULES="$DIR_MAIN/modules"

# ==============================================================================
# Global Libraries
# ==============================================================================

source "$DIR_LIB/logging.sh"
source "$DIR_LIB/common.sh"
source "$DIR_LIB/errors.sh"

trap 'trap_err' ERR

# ==============================================================================
# Modules
# ==============================================================================

source "$DIR_MAIN/modules/select-disk.sh"
source "$DIR_MAIN/modules/confirm-destruction.sh"
source "$DIR_MAIN/modules/create-iso.sh"
source "$DIR_MAIN/modules/create-usb.sh"
source "$DIR_MAIN/modules/create-key-storage.sh"
source "$DIR_MAIN/modules/create-boot-storage.sh"
source "$DIR_MAIN/modules/backup-configuration-files.sh"

# ==============================================================================
# Functions
# ==============================================================================

create_custom_iso_and_write_usb(){
    confirm_usb_overwrite
    run_build_iso
    run_create_usb
    create_key_storage
    create_boot_storage
}

#create_new_custom_certificate(){
#       
#}

# ==============================================================================
# Render Menu
# ==============================================================================

main_menu() {
    local choice

    start_sudo_keepalive
    run_selectdisk

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
        echo "  9) Create new Custom Certificates"
        echo
        echo "  0) Exit"
        echo
        echo "=================================="

        read -r -p "Select an option: " choice

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
            9)
                new_custom_certificate
                ;;
            0)
                echo "Exiting ArchGuard USB Builder."
                cleanup
                return 0
                ;;
            *)
                echo "Invalid option. Please try again."
                sleep 1
                ;;
        esac

        if [[ "$choice" != "0" ]]; then
            echo
            read -r -p "Press Enter to return to the main menu..." _
        fi
    done
}

main_menu "$@"