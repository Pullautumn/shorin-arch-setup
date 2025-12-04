#!/bin/bash

# ==============================================================================
# 07-grub-theme.sh - GRUB Bootloader Theming (Visual Enhanced & Optional)
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/00-utils.sh"

check_root

# ------------------------------------------------------------------------------
# 0. Pre-check: Is GRUB installed?
# ------------------------------------------------------------------------------
# 检测 grub-mkconfig 命令是否存在，如果不存在说明不是 GRUB 环境
if ! command -v grub-mkconfig >/dev/null 2>&1; then
    # 使用 warn 而不是 error，因为这可能是有意的 (例如用户使用 systemd-boot)
    echo ""
    warn "GRUB (grub-mkconfig) not found on this system."
    log "Skipping GRUB theme installation."
    exit 0
fi

section "Phase 7" "GRUB Theme Customization"

# ------------------------------------------------------------------------------
# 1. Detect Themes
# ------------------------------------------------------------------------------
log "Scanning for themes in 'grub-themes' folder..."

SOURCE_BASE="$PARENT_DIR/grub-themes"
DEST_DIR="/boot/grub/themes"

# Case 1: Repo folder missing
if [ ! -d "$SOURCE_BASE" ]; then
    warn "Directory 'grub-themes' not found in repo."
    exit 0
fi

# 扫描有效的主题目录 (包含 theme.txt 的目录)
# 使用数组存储路径和名称
mapfile -t FOUND_DIRS < <(find "$SOURCE_BASE" -mindepth 1 -maxdepth 1 -type d)
THEME_PATHS=()
THEME_NAMES=()

for dir in "${FOUND_DIRS[@]}"; do
    if [ -f "$dir/theme.txt" ]; then
        THEME_PATHS+=("$dir")
        THEME_NAMES+=("$(basename "$dir")")
    fi
done

# Case 2: No valid themes found
if [ ${#THEME_NAMES[@]} -eq 0 ]; then
    warn "No valid theme folders (containing theme.txt) found."
    exit 0
fi

# ------------------------------------------------------------------------------
# 2. Select Theme (TUI Menu)
# ------------------------------------------------------------------------------

# 如果只有一个主题，直接选中，跳过菜单
if [ ${#THEME_NAMES[@]} -eq 1 ]; then
    SELECTED_INDEX=0
    log "Only one theme detected. Auto-selecting: ${THEME_NAMES[0]}"
else
    # --- 动态计算菜单宽度 ---
    TITLE_TEXT="Select GRUB Theme (60s Timeout)"
    MAX_LEN=${#TITLE_TEXT}

    for name in "${THEME_NAMES[@]}"; do
        # 预估显示长度："[x] Name - Default" (大致增加 20 字符余量)
        ITEM_LEN=$((${#name} + 20))
        if (( ITEM_LEN > MAX_LEN )); then
            MAX_LEN=$ITEM_LEN
        fi
    done

    MENU_WIDTH=$((MAX_LEN + 4))

    # --- 渲染菜单 ---
    echo ""
    
    # 生成横线
    LINE_STR=""
    printf -v LINE_STR "%*s" "$MENU_WIDTH" ""
    LINE_STR=${LINE_STR// /─}

    # 顶部
    echo -e "${H_PURPLE}╭${LINE_STR}╮${NC}"

    # 标题居中
    TITLE_PADDING_LEN=$(( (MENU_WIDTH - ${#TITLE_TEXT}) / 2 ))
    RIGHT_PADDING_LEN=$((MENU_WIDTH - ${#TITLE_TEXT} - TITLE_PADDING_LEN))
    
    T_PAD_L=""; printf -v T_PAD_L "%*s" "$TITLE_PADDING_LEN" ""
    T_PAD_R=""; printf -v T_PAD_R "%*s" "$RIGHT_PADDING_LEN" ""
    
    echo -e "${H_PURPLE}│${NC}${T_PAD_L}${BOLD}${TITLE_TEXT}${NC}${T_PAD_R}${H_PURPLE}│${NC}"
    echo -e "${H_PURPLE}├${LINE_STR}┤${NC}"

    # 选项
    for i in "${!THEME_NAMES[@]}"; do
        NAME="${THEME_NAMES[$i]}"
        DISPLAY_IDX=$((i+1))
        
        COLOR_STR=""
        RAW_STR=""

        if [ "$i" -eq 0 ]; then
            RAW_STR=" [$DISPLAY_IDX] $NAME - Default"
            COLOR_STR=" ${H_CYAN}[$DISPLAY_IDX]${NC} ${NAME} - ${H_GREEN}Default${NC}"
        else
            RAW_STR=" [$DISPLAY_IDX] $NAME"
            COLOR_STR=" ${H_CYAN}[$DISPLAY_IDX]${NC} ${NAME}"
        fi

        PADDING=$((MENU_WIDTH - ${#RAW_STR}))
        PAD_STR=""; 
        if [ "$PADDING" -gt 0 ]; then
            printf -v PAD_STR "%*s" "$PADDING" ""
        fi
        
        echo -e "${H_PURPLE}│${NC}${COLOR_STR}${PAD_STR}${H_PURPLE}│${NC}"
    done

    # 底部
    echo -e "${H_PURPLE}╰${LINE_STR}╯${NC}"
    echo ""

    # --- 用户输入 ---
    read -t 60 -p "$(echo -e "   ${H_YELLOW}Enter choice [1-${#THEME_NAMES[@]}]: ${NC}")" USER_CHOICE
    if [ $? -ne 0 ]; then echo ""; fi # 处理超时换行
    
    # 默认值处理
    USER_CHOICE=${USER_CHOICE:-1}

    # 验证输入有效性
    if ! [[ "$USER_CHOICE" =~ ^[0-9]+$ ]] || [ "$USER_CHOICE" -lt 1 ] || [ "$USER_CHOICE" -gt "${#THEME_NAMES[@]}" ]; then
        log "Invalid choice or timeout. Defaulting to first option..."
        SELECTED_INDEX=0
    else
        SELECTED_INDEX=$((USER_CHOICE-1))
    fi
fi

# 确定最终选择
THEME_SOURCE="${THEME_PATHS[$SELECTED_INDEX]}"
THEME_NAME="${THEME_NAMES[$SELECTED_INDEX]}"

info_kv "Selected" "$THEME_NAME"

# ------------------------------------------------------------------------------
# 3. Install Theme Files
# ------------------------------------------------------------------------------
log "Installing theme files..."

# Ensure destination exists
if [ ! -d "$DEST_DIR" ]; then
    exe mkdir -p "$DEST_DIR"
fi

# Clean install: Remove old if exists (only specifically the folder we are installing)
if [ -d "$DEST_DIR/$THEME_NAME" ]; then
    log "Removing existing version..."
    exe rm -rf "$DEST_DIR/$THEME_NAME"
fi

# Copy
exe cp -r "$THEME_SOURCE" "$DEST_DIR/"

if [ -f "$DEST_DIR/$THEME_NAME/theme.txt" ]; then
    success "Theme installed to $DEST_DIR/$THEME_NAME"
else
    error "Failed to copy theme files."
    exit 1
fi

# ------------------------------------------------------------------------------
# 4. Configure /etc/default/grub
# ------------------------------------------------------------------------------
log "Configuring GRUB settings..."

GRUB_CONF="/etc/default/grub"
THEME_PATH="$DEST_DIR/$THEME_NAME/theme.txt"

if [ -f "$GRUB_CONF" ]; then
    # Update or Append GRUB_THEME
    if grep -q "^GRUB_THEME=" "$GRUB_CONF"; then
        log "Updating existing GRUB_THEME entry..."
        # Use # delimiter to avoid path clashes
        exe sed -i "s|^GRUB_THEME=.*|GRUB_THEME=\"$THEME_PATH\"|" "$GRUB_CONF"
    else
        log "Adding GRUB_THEME entry..."
        echo "GRUB_THEME=\"$THEME_PATH\"" >> "$GRUB_CONF"
        success "Entry appended."
    fi
    
    # Enable graphical output (Comment out console output)
    if grep -q "^GRUB_TERMINAL_OUTPUT=\"console\"" "$GRUB_CONF"; then
        log "Enabling graphical terminal..."
        exe sed -i 's/^GRUB_TERMINAL_OUTPUT="console"/#GRUB_TERMINAL_OUTPUT="console"/' "$GRUB_CONF"
    fi
    
    # Ensure GFXMODE is Auto
    if ! grep -q "^GRUB_GFXMODE=" "$GRUB_CONF"; then
        echo 'GRUB_GFXMODE=auto' >> "$GRUB_CONF"
    fi
    
    success "Configuration updated."
else
    error "$GRUB_CONF not found."
    exit 1
fi

# ------------------------------------------------------------------------------
# 5. Apply Changes
# ------------------------------------------------------------------------------
log "Generating new GRUB configuration..."

if exe grub-mkconfig -o /boot/grub/grub.cfg; then
    success "GRUB updated successfully."
else
    error "Failed to update GRUB."
    warn "You may need to run 'grub-mkconfig' manually."
fi

log "Module 07 completed."