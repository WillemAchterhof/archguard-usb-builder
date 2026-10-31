
#!/usr/bin/env bash

# ==============================================================================
# ArchGuard USB Builder - Menu Renderer
# ==============================================================================
# /menu/render.sh

menu_render() {

    clear

    printf "==================================\n"
    printf "       ArchGuard USB Builder\n"
    printf "==================================\n"
    printf "\n"

    for option in "${MENU_ORDER[@]}"; do

        definition="${MENU_OPTIONS["$option"]:-}"

        [[ -n "$definition" ]] || continue

        IFS='|' read -r function description variable <<< "$definition"

        printf "   [%s] %-25s : %s\n" \
            "$option" \
            "$description" \
            "${!variable-}"

    done

    printf "\n"
    printf "  q) Return to Main Menu\n"
    printf "\n"

    printf "==================================\n"

}
