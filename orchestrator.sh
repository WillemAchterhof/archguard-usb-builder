#!/usr/bin/env bash
# /menu/main-menu.sh

# ArchGuard USB Builder - Main Menu

main_menu() {
    local choice

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
            0)
                echo "Exiting ArchGuard USB Builder."
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

main_menu