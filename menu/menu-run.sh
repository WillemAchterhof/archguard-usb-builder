#!/usr/bin/env bash

# ------------------------------------------------------------------------------
# Menu Module Loader
# ------------------------------------------------------------------------------
# /menu/menu-run.sh


# Variables
MENU_MODULES="$ROOT_MENU/modules"

# Menu Dependencies
declare -A MENU_OPTIONS


source "$MENU_MODULES/menu-select_custom.sh"

for module in "$MENU_MODULES"/menu-*.sh; do
    [[ "$module" == "$MENU_MODULES/menu-select_custom.sh" ]] && continue

    source "$module"
    MENU_ORDER+=("$MENU_KEY")
done

# Sort Menu Order
mapfile -t MENU_ORDER < <(
    printf '%s\n' "${MENU_ORDER[@]}" | sort
)

# Menu Handling
source "$ROOT_MENU/menu-input.sh"
source "$ROOT_MENU/menu-render.sh"
