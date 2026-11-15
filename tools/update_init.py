import sys
from pathlib import Path

init_path = Path("NovaOS_fixed/installer/init")
content = init_path.read_text(encoding="utf-8")

config_code = """
# -------------------------------------------------------------
# Hardware Resource & Environment Configuration
# -------------------------------------------------------------
INSTALLED_RAM_KB=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}')
[ -z "$INSTALLED_RAM_KB" ] && INSTALLED_RAM_KB=1048576
INSTALLED_RAM_MB=$((INSTALLED_RAM_KB / 1024))
REC_RAM_MB=1024
[ "$INSTALLED_RAM_MB" -gt 4096 ] && REC_RAM_MB=2048

echo ""
echo -e "${CYAN}${BOLD}================================================================${RESET}"
echo -e "${CYAN}${BOLD}             NovaOS Hardware & Resource Configuration           ${RESET}"
echo -e "${CYAN}${BOLD}================================================================${RESET}"

# RAM Allocation Prompt
echo ""
echo -e "${BOLD}1. Memory (RAM) Allocation:${RESET}"
echo "  Installed physical RAM: ${BOLD}${INSTALLED_RAM_MB} MB${RESET}"
echo "  Recommended allocation: ${GREEN}${REC_RAM_MB} MB${RESET} (NovaOS optimal range: 512 MB - 2048 MB)"
echo -n "  How much RAM would you like to allocate for NovaOS? [Default: ${REC_RAM_MB} MB]: "
read -r input_ram
[ -z "$input_ram" ] && input_ram="$REC_RAM_MB"
echo -e "  Allocated RAM: ${GREEN}${input_ram} MB${RESET}"

# Storage Allocation Prompt
sec=$(cat "/sys/block/$(basename "$TARGET_DEV")/size")
mb=$((sec / 2048))
REC_STORE_MB=2048
[ "$mb" -lt 2048 ] && REC_STORE_MB="$mb"

echo ""
echo -e "${BOLD}2. Storage Space Allocation:${RESET}"
echo "  Selected drive: ${BOLD}${TARGET_DEV}${RESET} (Total capacity: ${mb} MB)"
echo "  Recommended allocation: ${GREEN}${REC_STORE_MB} MB${RESET}"
echo -n "  How much storage to allocate for NovaOS? [Default: ${mb} MB (Full Disk)]: "
read -r input_store
[ -z "$input_store" ] && input_store="$mb"
echo -e "  Allocated Storage: ${GREEN}${input_store} MB${RESET}"

# Component Profile Prompt
echo ""
echo -e "${BOLD}3. System Profile & Components:${RESET}"
echo "  [1] NovaOS Full Desktop (Windows 10 Style GUI, Sound, Segoe UI, Explorer) - Recommended"
echo "  [2] NovaOS Workstation (Grounded Typography, Shell & Management Utilities)"
echo "  [3] NovaOS Core Minimal (Lightweight Kernel)"
echo -n "  Select profile [1-3] [Default: 1]: "
read -r input_profile
[ -z "$input_profile" ] && input_profile="1"

# RTC Clock Prompt
echo ""
echo -e "${BOLD}4. Real-Time Hardware Clock (RTC):${RESET}"
echo "  Hardware Clock Time: ${BOLD}$(date)${RESET}"
echo -n "  Is this date and time correct? [Y/n]: "
read -r time_confirm

echo ""
echo -e "${CYAN}${BOLD}================================================================${RESET}"
echo -e "${CYAN}${BOLD}                   Installation Summary                         ${RESET}"
echo -e "${CYAN}${BOLD}================================================================${RESET}"
echo "  Target Disk:      ${TARGET_DEV} (${mb} MB)"
echo "  RAM Allocated:    ${input_ram} MB (Installed: ${INSTALLED_RAM_MB} MB)"
echo "  Storage Assigned: ${input_store} MB"
echo "  Profile:          NovaOS Desktop Experience"
echo ""
"""

target = 'echo -e "Target disk capacity: ${BOLD}${mb} MB (${sec} sectors)${RESET}"\n'
if target not in content:
    target = 'echo -e "Target disk capacity: ${BOLD}${mb} MB (${sec} sectors)${RESET}"\r\n'

assert target in content, "Target not found in installer/init"
content = content.replace(target, target + config_code)
init_path.write_text(content, encoding="utf-8")
print("Successfully patched installer/init")
