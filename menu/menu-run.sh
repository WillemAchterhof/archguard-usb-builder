#!/usr/bin/env bash

# ==============================================================================
# ArchGuard USB Builder - Menu Loader
# ==============================================================================
# /menu/menu-run.sh

# ==============================================================================
# Menu Variables
# ==============================================================================

# MENU_BASE="$DIR_MENU/base"
# MENU_SOFTWARE="$DIR_MENU/software"

# ==============================================================================
# Load Shared Menu Components
# ==============================================================================

# source "$DIR_MENU/menu.sh"
# source "$DIR_MENU/render.sh"
# source "$DIR_MENU/input.sh"

# ==============================================================================
# Load Submenu Entry Points
# ==============================================================================

source "$DIR_MENU/check-agboot.sh"
source "$DIR_MENU/base-edit.sh"
source "$DIR_MENU/base-run.sh"
source "$DIR_MENU/software-edit.sh"
source "$DIR_MENU/software-run.sh"
