#!/usr/bin/env bash

# ------------------------------------------------------------------------------
# Custom Menu Selection
# ------------------------------------------------------------------------------
# /menu/modules/menu-select_custom.sh

menu_select_custom()
{
    local variable="$1"
    local current_value
    local new_value

    current_value="${!variable}"

    while true; do
        read -rp "Custom value [$current_value]: " new_value

        [[ -z "$new_value" ]] && return

        if pacman -Ss "^${new_value}$" | grep -q .; then
            printf -v "$variable" '%s' "$new_value"
            return
        fi

        printf "Package '%s' was not found. Please enter a valid package.\n" "$new_value"
    done
}
