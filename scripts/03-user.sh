#!/bin/bash

# ==============================================================================
# 03-user.sh - User Creation & Configuration
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-utils.sh"

check_root

log "Starting Phase 3: User Configuration..."

# ------------------------------------------------------------------------------
# 1. User Detection / Creation Logic
# ------------------------------------------------------------------------------
section "Step 1/3" "User Account Setup"

# Attempt to detect existing user with UID 1000
EXISTING_USER=$(awk -F: '$3 == 1000 {print $1}' /etc/passwd)
MY_USERNAME=""
SKIP_CREATION=false

if [ -n "$EXISTING_USER" ]; then
    info_kv "Detected User" "$EXISTING_USER" "(UID 1000)"
    log "Using existing user configuration."
    MY_USERNAME="$EXISTING_USER"
    SKIP_CREATION=true
else
    warn "No standard user found (UID 1000)."
    
    while true; do
        read -p "   Please enter new username: " INPUT_USER
        
        if [[ -z "$INPUT_USER" ]]; then
            warn "Username cannot be empty."
            continue
        fi

        # Confirmation
        read -p "   Create user '${BOLD}$INPUT_USER${NC}'? [Y/n] " CONFIRM
        CONFIRM=${CONFIRM:-Y}
        
        if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
            MY_USERNAME="$INPUT_USER"
            break
        else
            log "Cancelled. Please re-enter."
        fi
    done
fi

# ------------------------------------------------------------------------------
# 2. Create User & Sudo
# ------------------------------------------------------------------------------
section "Step 2/3" "Account & Privileges"

if [ "$SKIP_CREATION" = true ]; then
    log "User already exists. Checking permissions..."
    
    # Check if user is in wheel group
    if groups "$MY_USERNAME" | grep -q "\bwheel\b"; then
        success "User '$MY_USERNAME' is already in 'wheel' group."
    else
        log "Adding '$MY_USERNAME' to 'wheel' group..."
        exe usermod -aG wheel "$MY_USERNAME"
    fi
else
    log "Creating new user..."
    exe useradd -m -g wheel "$MY_USERNAME"
    
    log "Setting password for $MY_USERNAME..."
    # passwd is interactive, just run it directly
    passwd "$MY_USERNAME"
    
    if [ $? -eq 0 ]; then
        success "Password set successfully."
    else
        error "Failed to set password."
    fi
fi

# Configure Sudoers
log "Configuring sudoers for %wheel group..."
if grep -q "^# %wheel ALL=(ALL:ALL) ALL" /etc/sudoers; then
    exe sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
    success "Uncommented %wheel in /etc/sudoers."
elif grep -q "^%wheel ALL=(ALL:ALL) ALL" /etc/sudoers; then
    success "Sudo access already enabled."
else
    log "Appending %wheel rule to /etc/sudoers..."
    echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers
    success "Sudo access configured."
fi

# ------------------------------------------------------------------------------
# 3. Generate User Directories
# ------------------------------------------------------------------------------
section "Step 3/3" "User Directories (XDG)"

# [FIX] -S -> -Syu
exe pacman -Syu --noconfirm --needed xdg-user-dirs

log "Generating directories (Downloads, Music, etc)..."
if exe runuser -u "$MY_USERNAME" -- xdg-user-dirs-update; then
    success "Directories created for $MY_USERNAME."
else
    warn "Failed to generate directories (Session might be inactive)."
fi

log "Module 03 completed."