#!/usr/bin/env bash

# ==============================================================================
# ArchGuard USB Builder - Temporary Secure Boot Certificates
# ==============================================================================
# /modules/write-usb.sh

create_custom_iso_and_write_usb() {
    local newcert="n"

    printf "\nCreate USB with new temporary certificates? [y/N]: "
    read -r newcert

    if [[ "$newcert" =~ ^[Yy]$ ]]; then
        if ! create_new_custom_certificate; then
            warn "Could not create temporary certificates."
            return 1
        fi
    fi

    confirm_usb_overwrite || {
        if (( CERT_SWAPPED == 1 )); then
            restore_original_custom_certificate ||
                fatal "Certificate restoration failed."
        fi
        return 0
    }

    run_build_iso || {
        local status=$?
        if (( CERT_SWAPPED == 1 )); then
            restore_original_custom_certificate ||
                fatal "Certificate restoration failed."
        fi
        return "$status"
    }

    run_create_usb || {
        local status=$?
        if (( CERT_SWAPPED == 1 )); then
            restore_original_custom_certificate ||
                fatal "Certificate restoration failed."
        fi
        return "$status"
    }

    create_key_storage || {
        local status=$?
        if (( CERT_SWAPPED == 1 )); then
            restore_original_custom_certificate ||
                fatal "Certificate restoration failed."
        fi
        return "$status"
    }

    create_boot_storage || {
        local status=$?
        if (( CERT_SWAPPED == 1 )); then
            restore_original_custom_certificate ||
                fatal "Certificate restoration failed."
        fi
        return "$status"
    }

    if (( CERT_SWAPPED == 1 )); then
        restore_original_custom_certificate ||
            fatal "Certificate restoration failed."
    fi

    success "USB creation workflow completed."
}