#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# MasterDnsVPN Client Manager - Text Resources (Double-line Edition)
# Version: 2.0 - Fixed & Enhanced
# =============================================================================

# ── Colour Definitions ──────────────────────────────────────────────────────
RED='\e[1;31m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
CYAN='\e[1;36m'
WHITE='\e[1;37m'
NC='\e[0m'

# ── Box Characters (Double-line) ────────────────────────────────────────────
B_H="═"
B_V="║"
B_TL="╔"
B_TR="╗"
B_BL="╚"
B_BR="╝"
DASH="══════════════════════════════════════════════════"

# ═════════════════════════════════════════════════════════════════════════════
# 1. Main Menu
# ═════════════════════════════════════════════════════════════════════════════

MAIN_HEADER="
${GREEN}╔══════════════════════════════════════╗${NC}
${GREEN}║     MasterDnsVPN Client Manager     ║${NC}
${GREEN}╚══════════════════════════════════════╝${NC}"

MAIN_MENU_ITEMS="  1. Start Client
  2. Stop Client
  3. Edit Current Profile
  4. Edit Resolvers
  5. View Log
  6. Manage Profiles
  7. MTU Speed Test
  8. Multi-Connection
  9. Resolver Health Check
 10. Settings
 11. Exit"

MAIN_FOOTER="Nano: ${YELLOW}Ctrl+X${NC} then ${YELLOW}Y${NC} then ${YELLOW}Enter${NC} | Log: ${YELLOW}ENTER${NC}"
MAIN_PROMPT="Choose [1-11]: "

# ═════════════════════════════════════════════════════════════════════════════
# 2. Create Profile - Enhanced Version
# ═════════════════════════════════════════════════════════════════════════════

PROFILE_HEADER="${CYAN}══════ Create Profile ══════${NC}"

PROFILE_LIST="  0. Default
  1. high-mtu-window-blast
  2. deep-buffer-balanced-ultra (Recommended)
  3. stable-scan-daily-driver
  4. curated-pool-steady
  5. velocity-max-dl
  6. iron-steadfast-survival
  7. omni-balance
  8. Create ALL profiles at once
  9. Back"

PROFILE_DESC_HEADER="${WHITE}Description:${NC}"

PROFILE_DESC_1="${GREEN}1${NC}  FAST-DOWNLOAD  LOSSY-NETWORK  HIGH-DUPLICATION
    Aggressive ARQ, high-MTU, maximum duplication"

PROFILE_DESC_2="${GREEN}2${NC}  ULTRA-THROUGHPUT  SMART-ROUTING  DEEP-QUEUES
    Loss-Top-Random, deep buffers, relaxed auto-disable"

PROFILE_DESC_3="${GREEN}3${NC}  DAILY-USE  AUTO-DISCOVER  BALANCED
    Discovery-mode MTU scanning, asymmetric ZSTD, moderate ARQ"

PROFILE_DESC_4="${GREEN}4${NC}  VERIFIED-RESOLVERS  RELIABLE  CONSISTENT
    Curated pool, conservative RTO, relaxed failover"

PROFILE_DESC_5="${GREEN}5${NC}  MAX-SPEED  CLEAN-NETWORK  LOW-LATENCY
    Zero-duplication, asymmetric MTU, 8000-window, no compression"

PROFILE_DESC_6="${GREEN}6${NC}  HOSTILE-NETWORK  NEVER-DROPS  MAX-RESILIENCE
    MTU 20/40, 4x duplication, micro-ARQ, 15s RTO, 3000 retries"

PROFILE_DESC_7="${GREEN}7${NC}  ALL-ROUNDER  MID-MTU  ADAPTIVE
    Loss-Then-Latency, mid-MTU, ZSTD download, moderate ARQ"

PROFILE_DESC_8="${GREEN}8${NC}  CREATE ALL 8 PROFILES AT ONCE
    Uses your domain/key, creates all profiles with prefix names"

PROFILE_PROMPT="Choose [0-9]: "

render_profile_screen() {
    printf "%b\n\n" "$PROFILE_HEADER"
    printf "%s\n\n" "$PROFILE_LIST"
    printf "%b\n" "$PROFILE_DESC_HEADER"
    printf "${CYAN}%s${NC}\n" "$DASH"
    printf "%b\n\n" "$PROFILE_DESC_1"
    printf "%b\n\n" "$PROFILE_DESC_2"
    printf "%b\n\n" "$PROFILE_DESC_3"
    printf "%b\n\n" "$PROFILE_DESC_4"
    printf "%b\n\n" "$PROFILE_DESC_5"
    printf "%b\n\n" "$PROFILE_DESC_6"
    printf "%b\n\n" "$PROFILE_DESC_7"
    printf "%b\n\n" "$PROFILE_DESC_8"
    printf "${CYAN}%s${NC}\n" "$DASH"
    printf "\n%s" "$PROFILE_PROMPT"
}

# ── New: Get base name from user ────────────────────────────────────────────
GET_BASE_NAME_PROMPT="${WHITE}Enter a base name for the profile(s) (e.g. myconfig):${NC}"

# ── New: First run recommended profile ───────────────────────────────────────
FIRST_RUN_RECOMMENDED="${GREEN} Option 2 (deep-buffer-balanced-ultra) or Create ALL profiles at once and test them ${NC}"

# ═════════════════════════════════════════════════════════════════════════════
# 3. Profile Sub-menus
# ═════════════════════════════════════════════════════════════════════════════

PROFILE_MENU="${CYAN}══════ Profiles ══════${NC}\n\n  1. Create\n  2. Load\n  3. Delete\n  4. Back\n\nChoose [1-4]: "
LOAD_PROFILE_HEADER="${CYAN}══════ Load Profile ══════${NC}"
DELETE_PROFILE_HEADER="${CYAN}══════ Delete Profile ══════${NC}"

# ═════════════════════════════════════════════════════════════════════════════
# 4. MTU Speed Test - Enhanced
# ═════════════════════════════════════════════════════════════════════════════

MTU_INFO_BOX="
${CYAN}╔══════════════════════════════════════════════════╗${NC}
${CYAN}║         MTU Speed Test - Information            ║${NC}
${CYAN}╚══════════════════════════════════════════════════╝${NC}"

MTU_INFO_TEXT="
${WHITE}Tests download speed for each MTU range ONE at a time.${NC}

  - Sequential testing for maximum accuracy
  - Shows live resolver stats while testing
  - Downloads 2MB file through each proxy
  - [L] View Log  [S] Skip  [Q] Abort

${WHITE}Sample proxy for Hiddify:${NC}
  ${CYAN}socks://Og@127.0.0.1:18000#port=18000${NC}"

MTU_START_PROMPT="${YELLOW}Start? (y/n): ${NC}"

MTU_STEP_BOX="
${GREEN}╔══════════════════════════════════════════════════╗${NC}
${GREEN}║         MTU Speed Test - Step %d/6               ║${NC}
${GREEN}╚══════════════════════════════════════════════════╝${NC}"

MTU_RESULTS_HEADER="${CYAN}══════ MTU Speed Test Results ══════${NC}"
MTU_BEST_MSG="${GREEN}Best: Port %d${NC} [UP:%d-%d DOWN:%d-%d] %d bytes"

# ═════════════════════════════════════════════════════════════════════════════
# 5. Resolver Health Check
# ═════════════════════════════════════════════════════════════════════════════

HEALTH_INFO_BOX="
${CYAN}╔══════════════════════════════════════════════════╗${NC}
${CYAN}║       Resolver Health Check & Cleaner           ║${NC}
${CYAN}╚══════════════════════════════════════════════════╝${NC}"

HEALTH_INFO_TEXT="
${WHITE}This tool will:${NC}
  1. Stress test resolvers using a network probe
  2. Weak resolvers will be auto-disabled by the client
  3. Shows probe time for each request
  4. Tracks live resolver count"

HEALTH_RUNNING_BOX="
${GREEN}╔══════════════════════════════════════════════════╗${NC}
${GREEN}║       Resolver Health Check - Running           ║${NC}
${GREEN}╚══════════════════════════════════════════════════╝${NC}"

HEALTH_SUMMARY_HEADER="${CYAN}══════ Health Check Summary ══════${NC}"

# ═════════════════════════════════════════════════════════════════════════════
# 6. Multi-Connection
# ═════════════════════════════════════════════════════════════════════════════

MULTI_INFO_HEADER="${CYAN}══════ Multi-Connection ══════${NC}"
MULTI_SAMPLE_PROXY="${WHITE}Sample:${NC}\n  ${CYAN}socks://Og@127.0.0.1:18000#port=18000${NC}"
MULTI_PROCEED="${YELLOW}Proceed? (y/n): ${NC}"

MULTI_PROFILE_SELECT_HEADER="${CYAN}══════ Multi-Connection: Select Profiles ══════${NC}"

MULTI_PROFILE_LIST="  0. Default
  1. high-mtu-window-blast       (FAST-DOWNLOAD LOSSY-NETWORK)
  2. deep-buffer-balanced-ultra  (ULTRA-THROUGHPUT SMART-ROUTING)
  3. stable-scan-daily-driver    (DAILY-USE AUTO-DISCOVER)
  4. curated-pool-steady         (VERIFIED-RESOLVERS RELIABLE)
  5. velocity-max-dl             (MAX-SPEED CLEAN-NETWORK)
  6. iron-steadfast-survival     (HOSTILE-NETWORK MAX-RESILIENCE)
  7. omni-balance                (ALL-ROUNDER MID-MTU ADAPTIVE)"

MULTI_RUN_ALL="${YELLOW}Run ALL 8 profiles? (y/n): ${NC}"
MULTI_SELECT_GUIDE="${WHITE}Enter profile numbers separated by commas (e.g. 0,2,5,7):${NC}"

MULTI_DASHBOARD_HEADER="${GREEN}══════ Multi-Connection Dashboard ══════${NC}"
MULTI_DASHBOARD_COLS="${WHITE}%-2s %-6s %-28s %8s %8s %8s %8s %6s${NC}"
MULTI_DASHBOARD_KEYS="${YELLOW}[V] View Log  [S] Stop All  [Q] Back to Menu${NC}"

MULTI_MENU="${CYAN}══════ Multi-Connection ══════${NC}\n\n  1. Different Profiles (up to 8)\n  2. Different MTU Ranges (6)\n  3. Back\n\nChoose [1-3]: "
MULTI_CUSTOM_PAR="${YELLOW}Set a custom MTU_TEST_PARALLELISM for these instances?${NC}\n  (leave empty to keep their current value):"

# ═════════════════════════════════════════════════════════════════════════════
# 7. Settings
# ═════════════════════════════════════════════════════════════════════════════

SETTINGS_HEADER="${CYAN}══════ Settings ══════${NC}"
SETTINGS_MENU="  1. Change MTU parallelism percentage (currently ${GREEN}%d%%${NC})
  2. toggle auto-manage parallelism
  3. Backup all configurations
  4. Restart Client (Stop + Start)
  5. Back"
SETTINGS_PROMPT="Choose [1-5]: "
SETTINGS_PCT_PROMPT="${WHITE}Enter new percentage (1-100):${NC}"
SETTINGS_BACKUP_DONE="${GREEN}Backup created: %s${NC}"
SETTINGS_BACKUP_FAILED="${RED}Backup failed!${NC}"
SETTINGS_RESTARTING="${YELLOW}Restarting client...${NC}"

# ═════════════════════════════════════════════════════════════════════════════
# 8. First-Run Prompts
# ═════════════════════════════════════════════════════════════════════════════

PARALLELISM_SETUP_HEADER="${CYAN}══════ MTU Parallelism Auto-Management ══════${NC}"
PARALLELISM_SETUP_PROMPT="${WHITE}Auto-manage MTU_TEST_PARALLELISM based on resolver count?${NC}\n${YELLOW}(y/n): ${NC}"

RESOLVERS_SETUP_HEADER="${CYAN}══════ Resolvers Setup ══════${NC}"
RESOLVERS_SETUP_PROMPT="${YELLOW}Do you want to enter your resolver list now?${NC}
  (y)es  - open the file for editing
  (n)o   - you can add them later via Menu -> Edit Resolvers"

# ═════════════════════════════════════════════════════════════════════════════
# 9. Status Messages
# ═════════════════════════════════════════════════════════════════════════════

MSG_CLIENT_RUNNING="Status: ${GREEN}Running${NC} (PID %s)"
MSG_CLIENT_STOPPED="Status: ${RED}Stopped${NC}"
MSG_PROXY_READY="Proxy:  ${GREEN}Ready${NC}  |  Active resolvers: ${GREEN}%s${NC}  |  Streams: ${CYAN}%s${NC}"
MSG_PROXY_WAITING="Proxy:  ${YELLOW}Waiting...${NC}  |  Valid: ${GREEN}%s${NC}  |  Rejected: ${RED}%s${NC}"
MSG_PROXY_INACTIVE="Proxy:  ${RED}Not active${NC}"
MSG_AUTO_PAR_ON="Auto Parallelism: ${GREEN}ON${NC} (%d%%)"
MSG_AUTO_PAR_OFF="Auto Parallelism: ${RED}OFF${NC}"

MSG_DONE="${GREEN}Done!${NC}"
MSG_STARTED="${GREEN}Started${NC}"
MSG_LOADED="${GREEN}Loaded!${NC}"
MSG_DELETED="${GREEN}Deleted!${NC}"
MSG_STOPPING_ALL="${RED}Stopping all instances...${NC}"
MSG_ALL_STOPPED="${GREEN}All stopped.${NC}"
MSG_PAR_UPDATED="${GREEN}Parallelism updated: %d${NC}"

# Errors
ERR_FOLDER_NOT_FOUND="${RED}Error: Configuration/ folder not found.${NC}"
ERR_BINARY_NOT_FOUND="${RED}Binary not found.${NC}"
ERR_NO_CONFIG="${RED}No config.${NC}"
ERR_NO_RESOLVERS="${RED}No resolvers.${NC}"
ERR_NEED_CURL="${RED}Need curl: pkg install curl${NC}"
ERR_CLIENT_NOT_RUNNING="${RED}Client is not running!${NC}"
ERR_PROXY_NOT_READY="${RED}Proxy did not become ready after 60s. Aborting.${NC}"
ERR_INVALID_CHOICE="${RED}Invalid choice.${NC}"
ERR_INVALID_NUMBER="${RED}Invalid.${NC}"
ERR_REQUIRED="${RED}Required!${NC}"
ERR_TEMPLATE_NOT_FOUND="${RED}%s not found!${NC}"
ERR_NO_PROFILES="${YELLOW}No profiles found.${NC}"
ERR_NO_VALID_SELECTION="${RED}No valid profiles selected. Aborting.${NC}"
ERR_MISSING_DOMAIN_KEY="${RED}Active profile lacks valid domain/key.${NC}"
ERR_NANO_NOT_FOUND="${RED}nano not found! Install with: pkg install nano${NC}"

# Info / warning
INFO_STOPPING="${YELLOW}Stopping client...${NC}"
INFO_PROXY_WAITING="${YELLOW}Proxy is not ready yet. Waiting...${NC}"
INFO_PROXY_READY_NOW="${GREEN}Proxy is now ready!${NC}"
INFO_NO_NANO="${YELLOW}nano not found. Using vi instead.${NC}"
INFO_CREATING_ALL="${GREEN}Creating all 8 profiles with prefix: %s${NC}"
INFO_SKIP_EXISTING="${YELLOW}Skipping existing profile: %s${NC}"
INFO_CREATED="${GREEN}Created: %s${NC}"

# ═════════════════════════════════════════════════════════════════════════════
# 10. Helpers
# ═════════════════════════════════════════════════════════════════════════════

print_divider() {
    printf "${CYAN}%s${NC}\n" "$DASH"
}

print_mtu_step_box() {
    local step=$1
    printf "$MTU_STEP_BOX\n" "$step"
}

print_multi_col_headers() {
    printf "$MULTI_DASHBOARD_COLS\n" "#" "Port" "Profile" "Valid" "Reject" "Active" "Stream" "Proxy"
}
