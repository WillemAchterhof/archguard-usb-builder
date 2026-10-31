
#!/usr/bin/env bash

# ==============================================================================
# ArchGuard USB Builder - Configuration Menu
# ==============================================================================
# /menu/menu-run.sh

configuration_menu() {

    #require_archguard_usb || return 0

    # Load menu components
    source "$DIR_MENU/menu.sh"
    source "$DIR_MENU/render.sh"
    source "$DIR_MENU/input.sh"

    # Start menu
    run_menu
}
