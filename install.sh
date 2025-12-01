#!/bin/bash

# ==============================================================================
# Shorin Arch Setup - Main Installer
# ==============================================================================

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$BASE_DIR/scripts"
STATE_FILE="$BASE_DIR/.install_progress"

source "$SCRIPTS_DIR/00-utils.sh"

# --- [CRITICAL FIX] Export DEBUG to child scripts ---
export DEBUG=${DEBUG:-0}

check_root
chmod +x "$SCRIPTS_DIR"/*.sh

# --- Banner Functions ---
banner1() {
cat << "EOF"
   _____ __  ______  ____  _____   __
  / ___// / / / __ \/ __ \/  _/ | / /
  \__ \/ /_/ / / / / /_/ // //  |/ / 
 ___/ / __  / /_/ / _, _// // /|  /  
/____/_/ /_/\____/_/ |_/___/_/ |_/   
EOF
}

banner2() {
cat << "EOF"
  ██████  ██   ██  ██████  ██████  ██ ███    ██ 
  ██      ██   ██ ██    ██ ██   ██ ██ ████   ██ 
  ███████ ███████ ██    ██ ██████  ██ ██ ██  ██ 
       ██ ██   ██ ██    ██ ██   ██ ██ ██  ██ ██ 
  ██████  ██   ██  ██████  ██   ██ ██ ██   ████ 
EOF
}

banner3() {
# Fixed typo: SHARIN -> SHORIN
cat << "EOF"
   ______ __ __   ___   ____   ____  _   _ 
  / ___/|  |  | /   \ |    \ |    || \ | |
 (   \_ |  |  ||     ||  D  ) |  | |  \| |
  \__  ||  _  ||  O  ||    /  |  | |     |
  /  \ ||  |  ||     ||    \  |  | | |\  |
  \    ||  |  ||     ||  .  \ |  | | | \ |
   \___||__|__| \___/ |__|\_||____||_| \_|
EOF
}

show_banner() {
    clear
    local r=$(( $RANDOM % 3 ))
    echo -e "${H_CYAN}"
    case $r in
        0) banner1 ;;
        1) banner2 ;;
        2) banner3 ;;
    esac
    echo -e "${NC}"
    echo -e "${DIM}   :: Arch Linux Automation Protocol :: v2.2 ::${NC}"
    
    if [ "$DEBUG" == "1" ]; then
        echo -e "\n${H_YELLOW}   [!] DEBUG MODE ENABLED: Forcing China Network Optimizations${NC}"
    fi
    echo ""
}

sys_info() {
    echo -e "${H_BLUE}╔════ SYSTEM DIAGNOSTICS ══════════════════════════════╗${NC}"
    echo -e "${H_BLUE}║${NC} Kernel:  $(uname -r)"
    echo -e "${H_BLUE}║${NC} User:    $(whoami)"
    echo -e "${H_BLUE}║${NC} Mode:    $([ "$DEBUG" == "1" ] && echo "${H_YELLOW}DEBUG (CN Force)${NC}" || echo "Standard")"
    echo -e "${H_BLUE}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# --- Main Logic ---

show_banner
sys_info

# Module List
MODULES=(
    "01-base.sh"
    "02-musthave.sh"
    "03-user.sh"
    "04-niri-setup.sh"
    "05-apps.sh"
)

if [ ! -f "$STATE_FILE" ]; then
    touch "$STATE_FILE"
fi

TOTAL_STEPS=${#MODULES[@]}
CURRENT_STEP=0

for module in "${MODULES[@]}"; do
    CURRENT_STEP=$((CURRENT_STEP + 1))
    script_path="$SCRIPTS_DIR/$module"
    
    if [ ! -f "$script_path" ]; then
        warn "Module not found: $module"
        continue
    fi

    box_title "Module ${CURRENT_STEP}/${TOTAL_STEPS}: $module" "${H_MAGENTA}"

    if grep -q "^${module}$" "$STATE_FILE"; then
        echo -e "${H_GREEN}✔${NC} Module marked as COMPLETED."
        read -p "$(echo -e ${H_YELLOW}"  Skip this module? [Y/n] "${NC})" skip_choice
        skip_choice=${skip_choice:-Y}
        
        if [[ "$skip_choice" =~ ^[Yy]$ ]]; then
            log "Skipping $module..."
            continue
        else
            log "Force re-running $module..."
            sed -i "/^${module}$/d" "$STATE_FILE"
        fi
    fi

    # Execute
    bash "$script_path"
    exit_code=$?

    if [ $exit_code -eq 0 ]; then
        echo "$module" >> "$STATE_FILE"
    else
        echo ""
        hr
        error "CRITICAL FAILURE IN MODULE: $module (Exit Code: $exit_code)"
        echo -e "${DIM}Fix the issue and re-run ./install.sh to resume.${NC}"
        hr
        exit 1
    fi
done

# --- End Screen ---
clear
show_banner
box_title "INSTALLATION COMPLETE" "${H_GREEN}"

echo -e "   ${BOLD}Congratulations!${NC}"
echo -e "   System deployment finished successfully."
hr

if [ -f "$STATE_FILE" ]; then
    rm "$STATE_FILE"
fi

echo -e "${H_YELLOW}>>> System requires a REBOOT.${NC}"

for i in {10..1}; do
    echo -ne "\r${DIM}Auto-rebooting in ${i} seconds... (Press 'n' to cancel)${NC}"
    read -t 1 -N 1 input
    if [[ "$input" == "n" || "$input" == "N" ]]; then
        echo -e "\n${H_BLUE}>>> Reboot cancelled.${NC}"
        exit 0
    fi
done

echo -e "\n${H_GREEN}>>> Rebooting now...${NC}"
reboot