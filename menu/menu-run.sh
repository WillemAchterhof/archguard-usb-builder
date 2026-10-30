#!/usr/bin/env bash

# ------------------------------------------------------------------------------
# Menu Module Loader
# ------------------------------------------------------------------------------
# /menu/menu-run.sh

configuration_menu(){
    # Variables
    MENU_MODULES="$DIR_MENU/modules"
    
    # Menu Dependencies
    declare -A MENU_OPTIONS
    
    for module in "$MENU_MODULES"/*.sh; do
        source "$module"
        MENU_ORDER+=("$MENU_KEY")
    done
    
    # Sort Menu Order
    mapfile -t MENU_ORDER < <(
        printf '%s\n' "${MENU_ORDER[@]}" | sort
    )
    
    # Menu Handling
    source "$DIR_MENU/input.sh"
    source "$DIR_MENU/render.sh"
}
