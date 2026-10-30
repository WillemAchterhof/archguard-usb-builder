#!/usr/bin/env bash

# ------------------------------------------------------------------------------
# Menu Renderer
# ------------------------------------------------------------------------------
# /menu/render.sh

menu_render()
{
    local option
    local definition
    local function
    local description
    local variable

    clear

    printf "================================================================================\n"
    printf " ArchGuard Post-Install\n"
    printf "================================================================================\n"
    printf "\n"
    printf " Press option key to cycle through options\n"
    printf " Press Shift + option key for manual entry\n"
    printf "\n"

    for option in "${MENU_ORDER[@]}"; do
        definition="${MENU_OPTIONS["$option"]:-}"

    definition="${MENU_OPTIONS["$option"]:-}"

    [[ -n "$definition" ]] || return 0

        IFS='|' read -r function description variable <<< "$definition"

        printf "   [%s] %-25s : %s\n" \
            "$option" \
            "$description" \
            "${!variable}"
    done

    printf "\n"
    printf "\n"
    printf " Actions\n"
    printf " ────────────────────────────────────────────────────────────────────────────────\n"
    printf "   [y] Install    [z] Exit\n"
    printf "\n"
    printf "================================================================================\n"
}
