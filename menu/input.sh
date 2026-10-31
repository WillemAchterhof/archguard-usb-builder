
#!/usr/bin/env bash

# ==============================================================================
# ArchGuard USB Builder - Menu Input
# ==============================================================================
# /menu/input.sh

menu_handle_input() {

    local option="$1"

    case "$option" in

        *)
            return 0
            ;;

    esac

}
