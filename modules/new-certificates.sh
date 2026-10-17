#!/usr/bin/env bash

# ==============================================================================
# ArchGuard USB Builder - Temporary Secure Boot Certificates
# ==============================================================================
# /modules/new-certificates.sh
#
# Menu option 9:
#   1. Check that sbctl is installed.
#   2. Preserve the current /var/lib/sbctl directory as /var/lib/sbctl.old.
#   3. Generate and verify a temporary set of certificates.
#   4. If that worked, call create_custom_iso_and_write_usb.
#   5. Remove the temporary certificates and restore the original set
#      (always: after success, after a failed build, after Ctrl+C).
#   6. Return to the caller, which is the main_menu loop.
#
# This module manages certificates only. USB selection, preparation, ISO
# building, and writing are handled by create_custom_iso_and_write_usb.
#
# Returning to the menu:
#   This function is called from inside the main_menu loop, so it simply
#   returns and the loop shows the menu again. It must NOT call main_menu():
#   that starts a nested menu (and main_menu runs start_sudo_keepalive and
#   run_selectdisk again). It also returns 0 after handled problems, because a
#   non-zero return from a menu action trips the ERR trap and ends the program.
#
# Why the build runs in a subshell:
#   The workflow calls fatal(), which ends its shell with exit. In a subshell
#   only the subshell ends, so this module can restore the certificates.
#   Inside the subshell the global side effects of fatal() -> cleanup() are
#   switched off (project removal, killing the menu's sudo keepalive, removing
#   the menu session's packages), so the menu can carry on afterwards.
#
# Expected functions supplied by the application:
#   msg, success, warn, fatal, create_custom_iso_and_write_usb
#   start_sudo_keepalive (optional)
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

# Transaction state used to make restoration safe and repeatable.
CERT_SWAPPED=0
CERT_HAD_ORIGINAL=0
CERT_BUILD_STATUS=0


# ------------------------------------------------------------------------------
# Preflight checks
# ------------------------------------------------------------------------------

check_certificate_requirements() {
    if ! command -v sbctl >/dev/null 2>&1; then
        warn "sbctl is not installed. Install it with: sudo pacman -S --needed sbctl"
        return 1
    fi

    # Include broken symlinks: never overwrite a backup from an interrupted run.
    if [[ -e "$CERT_BACKUP_DIR" || -L "$CERT_BACKUP_DIR" ]]; then
        warn "Certificate backup already exists: $CERT_BACKUP_DIR"
        warn "A previous run may have been interrupted. Inspect and recover it before retrying."
        return 1
    fi

    return 0
}


# ------------------------------------------------------------------------------
# Restore original certificates and remove temporary certificates
# ------------------------------------------------------------------------------

restore_certificates() {
    (( CERT_SWAPPED == 1 )) || return 0

    msg "Restoring the original certificate state..."

    # Never remove the active directory if we need to restore an original
    # directory but its backup has gone missing.
    if (( CERT_HAD_ORIGINAL == 1 )) && [[ ! -d "$CERT_BACKUP_DIR" ]]; then
        warn "Original certificate backup is missing: $CERT_BACKUP_DIR"
        warn "Refusing to remove $CERT_DIR."
        return 1
    fi

    # Remove the temporary certificate directory, if it exists.
    if [[ -e "$CERT_DIR" || -L "$CERT_DIR" ]]; then
        if ! sudo rm -rf -- "$CERT_DIR"; then
            warn "Could not remove temporary certificates: $CERT_DIR"
            warn "The original certificates, if any, should remain at $CERT_BACKUP_DIR."
            return 1
        fi
    fi

    # Restore the original directory only if one existed before this operation.
    if (( CERT_HAD_ORIGINAL == 1 )); then
        if ! sudo mv -- "$CERT_BACKUP_DIR" "$CERT_DIR"; then
            warn "Could not restore the original certificates. Backup remains at $CERT_BACKUP_DIR."
            return 1
        fi
    fi

    CERT_SWAPPED=0
    CERT_HAD_ORIGINAL=0
    trap - INT TERM

    success "Certificate restoration completed."
    return 0
}


# ------------------------------------------------------------------------------
# Signal handler
# ------------------------------------------------------------------------------

# INT (Ctrl+C): restore, then let the interrupted code path run to its end.
# The interrupted command has already stopped, so the function falls through
# its normal error handling and returns to the menu.
# TERM: restore, then really terminate.
certificate_interrupt() {
    local signal="${1:-INT}"

    printf '\n'
    warn "Certificate operation interrupted. Attempting to restore the original certificates..."

    if ! restore_certificates; then
        warn "AUTOMATIC RESTORATION FAILED. Do not delete either certificate path."
        warn "Inspect: $CERT_DIR"
        warn "Inspect: $CERT_BACKUP_DIR"
    fi

    if [[ "$signal" == "TERM" ]]; then
        exit 143
    fi
}


# ------------------------------------------------------------------------------
# Preserve the original certificate directory
# ------------------------------------------------------------------------------

backup_current_certificates() {
    CERT_HAD_ORIGINAL=0

    if [[ -e "$CERT_DIR" || -L "$CERT_DIR" ]]; then
        msg "Backing up current certificates to $CERT_BACKUP_DIR..."

        if ! sudo mv -- "$CERT_DIR" "$CERT_BACKUP_DIR"; then
            warn "Failed to back up the current certificates."
            return 1
        fi

        CERT_HAD_ORIGINAL=1
    else
        msg "No existing certificate directory found; there is no original directory to restore."
    fi

    # Set state and traps only after the backup operation has completed.
    CERT_SWAPPED=1
    trap 'certificate_interrupt INT' INT
    trap 'certificate_interrupt TERM' TERM
    return 0
}


# ------------------------------------------------------------------------------
# Create and verify the temporary certificate set
# ------------------------------------------------------------------------------

create_new_certificates() {
    local file

    msg "Creating temporary Secure Boot certificates..."

    if ! sudo sbctl create-keys; then
        warn "sbctl create-keys failed."
        return 1
    fi

    for file in "${CERT_REQUIRED_FILES[@]}"; do
        if ! sudo test -f "$CERT_DIR/$file"; then
            warn "Required certificate file is missing: $CERT_DIR/$file"
            return 1
        fi
    done

    success "Temporary certificates created and verified."
    return 0
}


# ------------------------------------------------------------------------------
# Call the existing USB workflow in a subshell
# ------------------------------------------------------------------------------

run_isolated_usb_build() {
    local err_trap=""
    local errexit=0
    local packages_file
    local package
    local -a added=()

    CERT_BUILD_STATUS=0

    # After an interrupt the handler has already restored the originals.
    # Never build a USB from the original certificates.
    if (( CERT_SWAPPED != 1 )); then
        warn "The certificates are not in the temporary state; not building."
        CERT_BUILD_STATUS=1
        return 0
    fi

    packages_file="$(mktemp)" || {
        warn "Could not create a temporary file."
        CERT_BUILD_STATUS=1
        return 0
    }

    if [[ $- == *e* ]]; then
        errexit=1
    fi

    err_trap="$(trap -p ERR)"

    # Temporarily disable the parent's errexit/ERR handling so we can capture
    # the subshell status and still restore the original certificate directory.
    trap - ERR
    set +e

    (
        # fatal() runs cleanup() inside this subshell. Keep it away from the
        # menu session's resources.
        unset SUDO_KEEPALIVE_PID
        DIR_PROJECT=""
        PACKAGES_ADDED=()

        # Keep error handling active for the workflow.
        if [[ -n "$err_trap" ]]; then
            eval "$err_trap"
        fi
        if (( errexit == 1 )); then
            set -e
        fi

        create_custom_iso_and_write_usb

        # Hand the packages the workflow installed back to the menu session so
        # that the normal exit cleanup still removes them.
        if (( ${#PACKAGES_ADDED[@]} > 0 )); then
            printf '%s\n' "${PACKAGES_ADDED[@]}" > "$packages_file"
        fi
    )
    CERT_BUILD_STATUS=$?

    if (( errexit == 1 )); then
        set -e
    fi
    if [[ -n "$err_trap" ]]; then
        eval "$err_trap"
    fi

    if (( CERT_BUILD_STATUS == 0 )) && [[ -s "$packages_file" ]]; then
        mapfile -t added < "$packages_file"

        for package in "${added[@]}"; do
            if [[ -n "$package" ]]; then
                PACKAGES_ADDED+=("$package")
            fi
        done
    fi

    rm -f -- "$packages_file"

    return 0
}


# fatal() inside a failed build ran cleanup(), which drops the sudo credentials
# (sudo -K) for the whole terminal. Authenticate again and make sure the
# keepalive of the menu session is still running.
refresh_sudo_session() {
    sudo -v || warn "sudo authentication failed."

    if [[ -n "${SUDO_KEEPALIVE_PID:-}" ]] &&
       ! kill -0 "$SUDO_KEEPALIVE_PID" 2>/dev/null &&
       declare -F start_sudo_keepalive >/dev/null 2>&1; then
        start_sudo_keepalive
    fi
}


# ------------------------------------------------------------------------------
# Public entry point for menu option 9
# ------------------------------------------------------------------------------

create_new_custom_certificate() {
    local operation_status=0

    if ! check_certificate_requirements; then
        # Preflight failures are recoverable; leave the current menu intact.
        return 0
    fi

    if ! backup_current_certificates; then
        warn "Could not preserve the current certificates; nothing was changed."
        return 0
    fi

    if create_new_certificates; then
        if (( CERT_SWAPPED != 1 )); then
            # Ctrl+C arrived and the handler already restored the originals.
            warn "Interrupted before the USB build; nothing was built."
            operation_status=1
        else
            msg "Building the USB with the temporary certificates..."

            run_isolated_usb_build

            if (( CERT_BUILD_STATUS != 0 )); then
                warn "USB creation failed (exit status $CERT_BUILD_STATUS)."
                operation_status=1
            else
                success "USB created with the temporary certificates."
                msg "The temporary private keys now only exist on the USB (AGKEYS)."
            fi
        fi
    else
        operation_status=1
        warn "Temporary certificate creation failed."
    fi

    # After a failed build (cleanup() dropped the sudo credentials) or an
    # interrupt (Ctrl+C can stop the keepalive), make sure sudo works again.
    if (( operation_status != 0 )); then
        refresh_sudo_session
    fi

    # Always attempt restoration after the transaction has started, whether
    # certificate creation failed, the build failed, or everything worked.
    if ! restore_certificates; then
        warn "AUTOMATIC CERTIFICATE RESTORATION FAILED."
        warn "Do not delete either certificate path."
        warn "Inspect: $CERT_DIR"
        warn "Inspect: $CERT_BACKUP_DIR"
        fatal "Certificate restoration failed."
    fi

    if (( operation_status == 0 )); then
        success "Temporary certificate operation finished."
    else
        warn "Temporary certificate operation finished with errors; original certificates have been restored."
    fi

    # Back to the main menu: the caller's loop continues.
    return 0
}