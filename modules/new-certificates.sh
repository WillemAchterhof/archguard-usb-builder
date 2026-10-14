#!/usr/bin/env bash

# ==============================================================================
# ArchGuard USB Builder - New Custom Certificates
# ==============================================================================
# /modules/new-certificates.sh
#
# Menu option 9: build a USB with a brand-new set of Secure Boot certificates
# without touching the certificates of this machine.
#
# Responsibilities:
#   - Check that sbctl is installed
#   - Move the current certificate directory to <dir>.old
#   - Create new certificates with sbctl
#   - Ask whether the USB should be created with the new certificates
#   - Run create_custom_iso_and_write_usb when the answer is yes
#   - Always restore the previous certificates and remove the new ones
#     (after yes, after no, after a failure and after Ctrl+C)
#
# Required globals (selected before the menu loop starts):
#   AG_USB_DISK
#   AG_AGKEYS_PASSPHRASE   (asked again here when a previous build consumed it)
#
# Required functions:
#   msg  success  warn  fatal  create_custom_iso_and_write_usb
#
# Certificate directory:
#   /var/lib/sbctl       must match the paths used by create-iso.sh (signing)
#                        and create-key-storage.sh (AGKEYS copy)
#
# Notes:
#   - The new private keys only exist on the USB (AGKEYS) afterwards.
#   - If a previous run was interrupted, <dir>.old still holds the original
#     certificates and this module refuses to start until that is resolved.
#   - The restore is also called from cleanup() (lib/common.sh) so that a
#     fatal() during the USB build still restores the original certificates.
#     It is idempotent.
#   - No EXIT trap is used on purpose: create-key-storage.sh and
#     create-boot-storage.sh set and clear their own EXIT traps.
# ==============================================================================

readonly CERT_DIR="/var/lib/sbctl"
readonly CERT_BACKUP_DIR="/var/lib/sbctl.old"

readonly CERT_REQUIRED_FILES=(
    GUID
    keys/PK/PK.key
    keys/PK/PK.pem
    keys/KEK/KEK.key
    keys/KEK/KEK.pem
    keys/db/db.key
    keys/db/db.pem
)

# 1 while the new certificates are installed and the originals sit in .old
CERT_SWAPPED=0
# 1 when there were original certificates to put back
CERT_HAD_ORIGINAL=0


check_certificate_requirements(){
    if ! command -v sbctl >/dev/null 2>&1; then
        warn "sbctl is not installed. Install it first (pacman -S sbctl)."
        return 1
    fi

    if [[ -e "$CERT_BACKUP_DIR" ]]; then
        warn "$CERT_BACKUP_DIR already exists."
        warn "A previous run was probably interrupted. Your original"
        warn "certificates may be in $CERT_BACKUP_DIR."
        warn "Restore them manually, then try again:"
        warn "  sudo rm -rf $CERT_DIR && sudo mv $CERT_BACKUP_DIR $CERT_DIR"
        return 1
    fi

    return 0
}


# Put the original certificates back and remove the new ones.
# Safe to call repeatedly, including from cleanup() and the signal trap.
restore_certificates(){
    (( CERT_SWAPPED == 1 )) || return 0

    msg "Restoring the previous certificates..."

    # Never delete the only copy: with originals expected, .old must exist.
    if (( CERT_HAD_ORIGINAL == 1 )) && [[ ! -d "$CERT_BACKUP_DIR" ]]; then
        warn "Backup directory is missing: $CERT_BACKUP_DIR"
        warn "Refusing to remove $CERT_DIR."
        return 1
    fi

    if [[ -e "$CERT_DIR" || -L "$CERT_DIR" ]]; then
        sudo rm -rf -- "$CERT_DIR" || {
            warn "Could not remove the new certificates: $CERT_DIR"
            warn "Your original certificates are still in: $CERT_BACKUP_DIR"
            return 1
        }
    fi

    if (( CERT_HAD_ORIGINAL == 1 )); then
        sudo mv -- "$CERT_BACKUP_DIR" "$CERT_DIR" || {
            warn "Could not restore the original certificates."
            warn "They are still in: $CERT_BACKUP_DIR"
            return 1
        }
    fi

    CERT_SWAPPED=0
    CERT_HAD_ORIGINAL=0

    trap - INT TERM

    success "Previous certificates restored; new certificates removed."
}


certificate_interrupt(){
    printf '\n'
    warn "Interrupted."

    restore_certificates || true

    exit 130
}


backup_current_certificates(){
    CERT_HAD_ORIGINAL=0

    if [[ -e "$CERT_DIR" ]]; then
        msg "Moving current certificates: $CERT_DIR -> $CERT_BACKUP_DIR"

        sudo mv -- "$CERT_DIR" "$CERT_BACKUP_DIR" \
            || fatal "Failed to move $CERT_DIR to $CERT_BACKUP_DIR."

        CERT_HAD_ORIGINAL=1
    else
        msg "No current certificates found in $CERT_DIR."
    fi

    # From here on the new certificates must be removed again, whatever
    # happens.
    CERT_SWAPPED=1

    trap 'certificate_interrupt' INT TERM
}


create_new_certificates(){
    local file

    msg "Creating new Secure Boot certificates..."

    sudo sbctl create-keys \
        || fatal "sbctl create-keys failed."

    for file in "${CERT_REQUIRED_FILES[@]}"; do
        sudo test -f "$CERT_DIR/$file" \
            || fatal "New certificate file is missing: $CERT_DIR/$file"
    done

    success "New certificates created."
}


# Ask for the AGKEYS passphrase again (a previous build consumes it).
prompt_agkeys_passphrase(){
    local passphrase
    local confirmation

    read -r -s -p \
        'Type a passphrase for the Secure Boot key storage and press ENTER: ' \
        passphrase
    printf '\n'

    if [[ -z "$passphrase" ]]; then
        warn "Passphrase cannot be empty."
        return 1
    fi

    read -r -s -p 'Confirm passphrase and press ENTER: ' confirmation
    printf '\n'

    if [[ "$passphrase" != "$confirmation" ]]; then
        unset passphrase confirmation
        warn "Passphrases do not match."
        return 1
    fi

    AG_AGKEYS_PASSPHRASE="$passphrase"
    unset passphrase confirmation
}


# Reset what a previous build in this session left behind.
prepare_usb_build_state(){
    if [[ -z "${AG_USB_DISK:-}" || ! -b "${AG_USB_DISK:-}" ]]; then
        warn "No USB disk selected (or it is no longer available)."
        return 1
    fi

    AG_AGKEYS_PART=""
    AG_AGBOOT_PART=""

    if [[ -z "${AG_AGKEYS_PASSPHRASE:-}" ]]; then
        prompt_agkeys_passphrase || return 1
    fi

    return 0
}


ask_create_usb_with_new_certificates(){
    local answer

    printf '\n'

    if [[ -n "${AG_USB_DISK:-}" ]]; then
        printf 'Target disk: %s (ALL DATA ON IT WILL BE DESTROYED)\n' \
            "$AG_USB_DISK"
    fi

    read -r -p \
        'Create the USB with the new certificates? [y/N] ' \
        answer || answer=""

    [[ "${answer,,}" == "y" || "${answer,,}" == "yes" ]]
}


new_custom_certificate(){
    # Soft aborts stay in the menu (return 0); real failures use fatal.
    check_certificate_requirements || return 0

    backup_current_certificates
    create_new_certificates

    if ask_create_usb_with_new_certificates && prepare_usb_build_state; then
        create_custom_iso_and_write_usb

        success "USB created with the new certificates."
        msg "The new private keys only exist on the USB (AGKEYS)."
    else
        msg "USB creation skipped."
    fi

    restore_certificates
}