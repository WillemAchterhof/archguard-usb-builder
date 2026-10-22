#!/usr/bin/env bash

# ==============================================================================
# ArchGuard USB Builder - Temporary Secure Boot Certificates
# ==============================================================================
# /modules/new-certificates.sh

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

CERT_SWAPPED=0
CERT_HAD_ORIGINAL=0
CERT_BUILD_STATUS=0


# ------------------------------------------------------------------------------
# Preflight checks
# ------------------------------------------------------------------------------

check_certificate_requirements() {
    if ! require_command sbctl
        packages_install sbctl

    fi

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

    if (( CERT_HAD_ORIGINAL == 1 )) && [[ ! -d "$CERT_BACKUP_DIR" ]]; then
        warn "Original certificate backup is missing: $CERT_BACKUP_DIR"
        warn "Refusing to remove $CERT_DIR."
        return 1
    fi

    if [[ -e "$CERT_DIR" || -L "$CERT_DIR" ]]; then
        if ! sudo rm -rf -- "$CERT_DIR"; then
            warn "Could not remove temporary certificates: $CERT_DIR"
            warn "The original certificates, if any, should remain at $CERT_BACKUP_DIR."
            return 1
        fi
    fi

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

    trap - ERR
    set +e

    (
        unset SUDO_KEEPALIVE_PID
        DIR_PROJECT=""
        PACKAGES_ADDED=()

        if [[ -n "$err_trap" ]]; then
            eval "$err_trap"
        fi
        if (( errexit == 1 )); then
            set -e
        fi

        create_custom_iso_and_write_usb

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
        return 0
    fi

    if ! backup_current_certificates; then
        warn "Could not preserve the current certificates; nothing was changed."
        return 0
    fi

    if create_new_certificates; then
        if (( CERT_SWAPPED != 1 )); then
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

    if (( operation_status != 0 )); then
        refresh_sudo_session
    fi
   
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

    return 0
}