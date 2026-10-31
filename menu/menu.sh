
#!/usr/bin/env bash

# ==============================================================================
# ArchGuard USB Builder - Menu Controller
# ==============================================================================
# /menu/menu.sh

# ==============================================================================
# Menu State
# ==============================================================================

declare -gA MENU_OPTIONS=()
declare -ga MENU_ORDER=()

# ==============================================================================
# Menu Initialization
# ==============================================================================

menu_initialize() {

    MENU_OPTIONS=()
    MENU_ORDER=()

}

# ==============================================================================
# Menu Loop
# ==============================================================================

run_menu() {

    local choice

    menu_initialize

    while true; do

        menu_render

        if ! IFS= read -r -p "Select an option: " choice; then
            return 0
        fi

        case "$choice" in

            q|Q)
                return 0
                ;;

            *)
                menu_handle_input "$choice"
                ;;

        esac

    done
}
