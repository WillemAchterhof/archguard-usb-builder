
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

    local key
    local selected_option=""

    menu_initialize

    while true; do

        menu_render

        key=""

        if ! IFS= read -rsn1 key; then
            return 0
        fi

        case "$key" in

            z|Z)
                return 0
                ;;

            *)
                selected_option="$key"
                ;;

        esac

        # Wait for Enter
        key=""

        if ! IFS= read -rsn1 key; then
            return 0
        fi

        if [[ "$key" == "" ]]; then
            menu_handle_input "$selected_option"
        fi

    done
}
