
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


# ------------------------------------------------------------------------------
# Preflight checks
# ------------------------------------------------------------------------------

check_certificate_requirements() {
    if ! command -v sbctl >/dev/null 2>&1; then
        packages_install sbctl
    fi

    if ! command -v sbctl >/dev/null 2>&1; then
        fatal "Required command not found: sbctl"
    fi

    if [[ -e "$CERT_BACKUP_DIR" || -L "$CERT_BACKUP_DIR" ]]; then
        warn "Certificate backup already exists: $CERT_BACKUP_DIR"
        warn "A previous run may have been interrupted."
        warn "Inspect and recover it before retrying."
        return 1
    fi

    return 0
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
        msg "No existing certificate directory found."
        msg "There are no original certificates to restore."
    fi

    CERT_SWAPPED=1

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
# Create new temporary certificates
# ------------------------------------------------------------------------------

create_new_custom_certificate() {
    if ! check_certificate_requirements; then
        warn "Certificate requirements are not satisfied."
        return 1
    fi

    if ! backup_current_certificates; then
        warn "Could not preserve the original certificates."
        return 1
    fi

    if ! create_new_certificates; then
        warn "Temporary certificate creation or verification failed."

        if ! restore_original_custom_certificate; then
            fatal "Could not restore the original certificates."
        fi

        return 1
    fi

    success "New temporary certificates created and verified."

    return 0
}


# ------------------------------------------------------------------------------
# Restore the original certificate directory
# ------------------------------------------------------------------------------

restore_original_custom_certificate() {
    (( CERT_SWAPPED == 1 )) || return 0

    msg "Restoring the original certificate state..."

    # Protect the original backup.
    if (( CERT_HAD_ORIGINAL == 1 )) &&
       [[ ! -d "$CERT_BACKUP_DIR" ]]; then
        warn "Original certificate backup is missing: $CERT_BACKUP_DIR"
        warn "Refusing to remove $CERT_DIR."
        return 1
    fi

    # Remove temporary certificates.
    if [[ -e "$CERT_DIR" || -L "$CERT_DIR" ]]; then
        if ! sudo rm -rf -- "$CERT_DIR"; then
            warn "Could not remove temporary certificates."
            return 1
        fi
    fi

    # Restore original certificates.
    if (( CERT_HAD_ORIGINAL == 1 )); then
        if ! sudo mv -- "$CERT_BACKUP_DIR" "$CERT_DIR"; then
            warn "Could not restore the original certificates."
            warn "Backup remains at: $CERT_BACKUP_DIR"
            return 1
        fi
    fi

    CERT_SWAPPED=0
    CERT_HAD_ORIGINAL=0

    success "Original certificate state restored."

    return 0
}
