#!/usr/bin/env bash

# ------------------------------------------------------------------------------
# Menu Input
# ------------------------------------------------------------------------------
# /menu/input.sh

menu_handle_input()
{
    local option="$1"
    local menu_option
    local definition=""
    local function
    local description
    local argument

    [[ -n "$option" ]] || return 0

    for menu_option in "${MENU_ORDER[@]}"; do
        case "$option" in
            "$menu_option"|${menu_option^^})
                definition="${MENU_OPTIONS["$option"]:-}"
                break
                ;;
        esac
    done

    [[ -n "$definition" ]] || return 0

    IFS='|' read -r function description argument <<< "$definition"

    if [[ -n "$argument" ]]; then
        "$function" "$argument"
    else
        "$function"
    fi
}
