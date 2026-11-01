#!/usr/bin/env bash

# ------------------------------------------------------------------------------
# Desktop Environment
# ------------------------------------------------------------------------------
# /menu/modules/environment.sh

MENU_DESKTOP_ENV="hyprland"

MENU_OPTIONS[a]="menu_select_environment|Desktop Environment|MENU_DESKTOP_ENV"
MENU_OPTIONS[A]="menu_select_custom|Desktop Environment (custom)|MENU_DESKTOP_ENV"

MENU_KEY="a"

menu_select_environment()
{
    case "$MENU_DESKTOP_ENV" in
        hyprland)
            MENU_DESKTOP_ENV="plasma"
            ;;
        plasma)
            MENU_DESKTOP_ENV="gnome"
            ;;
        gnome)
            MENU_DESKTOP_ENV="skip"
            ;;
        skip)
            MENU_DESKTOP_ENV="hyprland"
            ;;
        *)
            MENU_DESKTOP_ENV="hyprland"
            ;;
    esac
}
