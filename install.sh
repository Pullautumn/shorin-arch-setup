#!/bin/bash

# ==============================================================================
# Shorin Arch Setup - Main Installer (v3.3)
# ==============================================================================

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$BASE_DIR/scripts"
STATE_FILE="$BASE_DIR/.install_progress"

if [ -f "$SCRIPTS_DIR/00-utils.sh" ]; then
    source "$SCRIPTS_DIR/00-utils.sh"
else
    echo "Error: 00-utils.sh not found."
    exit 1
fi

export DEBUG=${DEBUG:-0}
export CN_MIRROR=${CN_MIRROR:-0}

check_root
chmod +x "$SCRIPTS_DIR"/*.sh

# ... (Banner Functions 省略，保持不变) ...
# ... (Show Banner & Dashboard 省略，保持不变) ...

# --- Main Execution ---

show_banner
sys_dashboard

MODULES=(
    "01-base.sh"
    "02-musthave.sh"
    "03-user.sh"
    "04-niri-setup.sh"
    "07-grub-theme.sh"
    "99-apps.sh"
)

if [ ! -f "$STATE_FILE" ]; then
    touch "$STATE_FILE"
fi

TOTAL_STEPS=${#MODULES[@]}
CURRENT_STEP=0

log "Initializing installer sequence..."
sleep 0.5

# --- [NEW] Global System Update ---
section "Pre-Flight" "System Synchronization"
log "Ensuring system is up-to-date before starting..."

# 使用 -Syu 确保数据库和系统包都是最新的
if exe pacman -Syu --noconfirm; then
    success "System Updated."
else
    error "System update failed. Check your network."
    exit 1
fi

# --- Module Loop ---
for module in "${MODULES[@]}"; do
    CURRENT_STEP=$((CURRENT_STEP + 1))
    script_path="$SCRIPTS_DIR/$module"
    
    if [ ! -f "$script_path" ]; then
        error "Module not found: $module"
        continue
    fi

    section "Module ${CURRENT_STEP}/${TOTAL_STEPS}" "$module"

    if grep -q "^${module}$" "$STATE_FILE"; then
        echo -e "   ${H_GREEN}✔${NC} Module previously completed."
        read -p "$(echo -e "   ${H_YELLOW}Skip this module? [Y/n] ${NC}")" skip_choice
        skip_choice=${skip_choice:-Y}
        
        if [[ "$skip_choice" =~ ^[Yy]$ ]]; then
            log "Skipping..."
            continue
        else
            log "Force re-running..."
            sed -i "/^${module}$/d" "$STATE_FILE"
        fi
    fi

    bash "$script_path"
    exit_code=$?

    if [ $exit_code -eq 0 ]; then
        echo "$module" >> "$STATE_FILE"
    else
        echo ""
        echo -e "${H_RED}╔════ CRITICAL FAILURE ════════════════════════════════╗${NC}"
        echo -e "${H_RED}║ Module '$module' failed with exit code $exit_code.${NC}"
        echo -e "${H_RED}║ Check log: $TEMP_LOG_FILE${NC}"
        echo -e "${H_RED}╚══════════════════════════════════════════════════════╝${NC}"
        write_log "FATAL" "Module $module failed with exit code $exit_code"
        exit 1
    fi
done

# ... (Completion & Reboot 逻辑省略，保持不变) ...