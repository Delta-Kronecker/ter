#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# MasterDnsVPN Client Manager for Termux – Main Script (Enhanced & Fixed)
# Version: 2.2 - Fixed binary detection & added profile descriptions
# =============================================================================

# ── Safety settings (disable dangerous defaults) ────────────────────────────
set +e +u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MASTER_DNS_DIR="$SCRIPT_DIR/Configuration"

# ── Source resources ────────────────────────────────────────────────────────
RESOURCES_FILE="$SCRIPT_DIR/masterdns_resources.sh"
if [[ ! -f "$RESOURCES_FILE" ]]; then
    printf '\e[1;31mError: masterdns_resources.sh not found.\e[0m\n'
    printf 'Expected: %s\n' "$RESOURCES_FILE"
    exit 1
fi
source "$RESOURCES_FILE"

if [[ ! -d "$MASTER_DNS_DIR" ]]; then
    printf "%b\n" "$ERR_FOLDER_NOT_FOUND"
    printf 'Expected: %s\n' "$MASTER_DNS_DIR"
    exit 1
fi

cd "$MASTER_DNS_DIR"

# ── Trap for clean exit ─────────────────────────────────────────────────────
cleanup_on_exit() {
    kill_all_clients 2>/dev/null || true
    exit 0
}
trap cleanup_on_exit INT TERM

#######################################
# 1. Paths & constants - FIXED
#######################################

# Auto-detect binary in CURRENT directory (Configuration/)
CLIENT_BIN=""
# First try exact pattern with version
for bin in MasterDnsVPN_Client_Termux_ARM64_v* MasterDnsVPN_Client_Termux_ARM64; do
    if [[ -f "$bin" ]]; then
        CLIENT_BIN="./$bin"
        break
    fi
done
# If still not found, try any MasterDnsVPN_Client file
if [[ -z "$CLIENT_BIN" ]]; then
    for bin in MasterDnsVPN_Client*; do
        if [[ -f "$bin" && -x "$bin" ]]; then
            CLIENT_BIN="./$bin"
            break
        fi
    done
fi
# Last resort
[[ -z "$CLIENT_BIN" ]] && CLIENT_BIN="./MasterDnsVPN_Client_Termux_ARM64"

CONFIG_FILE="./client_config.toml"
RESOLVERS_FILE="./client_resolvers.txt"

DEFAULT_CONFIG="./Default.toml"
HIGH_MTU_WINDOW_BLAST="./high-mtu-window-blast.toml"
DEEP_BUFFER_BALANCED_ULTRA="./deep-buffer-balanced-ultra.toml"
STABLE_SCAN_DAILY_DRIVER="./stable-scan-daily-driver.toml"
CURATED_POOL_STEADY="./curated-pool-steady.toml"
VELOCITY_MAX_DL="./velocity-max-download.toml"
IRON_STEADFAST_SURVIVAL="./iron-steadfast-survival.toml"
OMNI_BALANCE="./omni-balance.toml"

PID_FILE="$PWD/client.pid"
LOG_FILE="$PWD/client.log"
LOG_BACKUP="$PWD/client.log.old"
PROFILES_DIR="$PWD/profiles"
MULTI_DIR="$PWD/multi_connection"
MTU_TEST_DIR="$PWD/mtu_test"
AUTO_MTU_FLAG="$PWD/auto_mtu_parallelism.flag"
PARALLELISM_FILE="$PWD/parallelism_percent.txt"

mkdir -p "$PROFILES_DIR"

# Profile template names mapping with descriptions
declare -A TEMPLATE_NAMES_MAP=(
    [0]="Default"
    [1]="high-mtu-window-blast"
    [2]="deep-buffer-balanced-ultra"
    [3]="stable-scan-daily-driver"
    [4]="curated-pool-steady"
    [5]="velocity-max-dl"
    [6]="iron-steadfast-survival"
    [7]="omni-balance"
)

declare -A TEMPLATE_DESC_MAP=(
    [0]="Standard configuration"
    [1]="FAST-DOWNLOAD | Aggressive ARQ, high-MTU, maximum duplication"
    [2]="ULTRA-THROUGHPUT | Loss-Top-Random, deep buffers, relaxed auto-disable"
    [3]="DAILY-USE | Discovery-mode MTU scanning, asymmetric ZSTD"
    [4]="VERIFIED-RESOLVERS | Curated pool, conservative RTO"
    [5]="MAX-SPEED | Zero-duplication, 8000-window, no compression"
    [6]="MAX-RESILIENCE | MTU 20/40, 4x duplication, 3000 retries"
    [7]="ALL-ROUNDER | Loss-Then-Latency, mid-MTU, ZSTD download"
)

declare -A TEMPLATE_FILES_MAP=(
    [0]="$DEFAULT_CONFIG"
    [1]="$HIGH_MTU_WINDOW_BLAST"
    [2]="$DEEP_BUFFER_BALANCED_ULTRA"
    [3]="$STABLE_SCAN_DAILY_DRIVER"
    [4]="$CURATED_POOL_STEADY"
    [5]="$VELOCITY_MAX_DL"
    [6]="$IRON_STEADFAST_SURVIVAL"
    [7]="$OMNI_BALANCE"
)

#######################################
# 2. Helper functions
#######################################

# Check for empty resolvers and warn user
check_resolvers_warning() {
    if [[ ! -f "$RESOLVERS_FILE" || ! -s "$RESOLVERS_FILE" ]]; then
        printf "\n${YELLOW}⚠ WARNING: No resolvers found in $RESOLVERS_FILE${NC}\n"
        printf "${WHITE}The client needs working DNS resolvers to function.${NC}\n"
        printf "${WHITE}You can add resolvers via Menu → Edit Resolvers (option 4)${NC}\n"
        printf "${WHITE}Example resolvers: 8.8.8.8, 1.1.1.1, 9.9.9.9${NC}\n\n"
        printf "${YELLOW}Press ENTER to continue...${NC}"
        read -r
    fi
}

check_nano() {
    if ! command -v nano &>/dev/null; then
        if command -v vi &>/dev/null; then
            printf "%b\n" "$INFO_NO_NANO"
            return 1
        else
            printf "%b\n" "$ERR_NANO_NOT_FOUND"
            return 2
        fi
    fi
    return 0
}

open_editor() {
    local file="$1"
    if check_nano; then
        nano "$file"
    elif command -v vi &>/dev/null; then
        vi "$file"
    else
        printf "%b\n" "$ERR_NANO_NOT_FOUND"
        return 1
    fi
    return 0
}

count_resolvers() {
    [[ -f "$RESOLVERS_FILE" ]] && grep -cve '^\s*$' "$RESOLVERS_FILE" 2>/dev/null || echo 0
}

calculate_parallelism() {
    local c=$1
    local v=$(( (c * PARALLELISM_PERCENT + 99) / 100 ))
    [[ $v -lt 1 ]] && v=1
    echo "$v"
}

update_active_config_parallelism() {
    local v=$1
    [[ -f "$CONFIG_FILE" ]] && sed -i "s|^MTU_TEST_PARALLELISM = .*|MTU_TEST_PARALLELISM = $v|" "$CONFIG_FILE" 2>/dev/null
}

update_all_configs_parallelism() {
    local c=$(count_resolvers)
    local v=$(calculate_parallelism "$c")
    update_active_config_parallelism "$v"
    echo "$v"
}

set_auto_parallelism() {
    local state=$1
    echo "$state" > "$AUTO_MTU_FLAG"
    if [[ "$state" == "yes" ]]; then
        update_all_configs_parallelism >/dev/null
    fi
}

auto_parallelism_enabled() {
    [[ -f "$AUTO_MTU_FLAG" ]] && grep -q "yes" "$AUTO_MTU_FLAG" 2>/dev/null && return 0
    return 1
}

show_parallelism_setup() {
    clear
    printf "%b\n\n" "$PARALLELISM_SETUP_HEADER"
    printf "%b" "$PARALLELISM_SETUP_PROMPT"
    read -r ch
    if [[ "$ch" == "y" || "$ch" == "Y" ]]; then
        set_auto_parallelism "yes"
        printf "\n${GREEN}Enabled.${NC}\n"
    else
        set_auto_parallelism "no"
        printf "\n${YELLOW}Manual mode.${NC}\n"
    fi
    sleep 2
}

#######################################
# 3. Config validation
#######################################

has_valid_config() {
    [[ ! -f "$CONFIG_FILE" ]] && return 1
    local d=$(grep '^DOMAINS = \[' "$CONFIG_FILE" 2>/dev/null | sed -n 's/.*\["\(.*\)"\].*/\1/p')
    local k=$(grep '^ENCRYPTION_KEY = "' "$CONFIG_FILE" 2>/dev/null | sed -n 's/.*"\(.*\)".*/\1/p')
    [[ -z "$d" || -z "$k" || "$d" == "v.domain.com" || "$k" == *"smoke-test-key"* ]] && return 1
    return 0
}

get_domain_from_config() {
    grep '^DOMAINS = \[' "$CONFIG_FILE" 2>/dev/null | sed -n 's/.*\["\(.*\)"\].*/\1/p'
}

get_key_from_config() {
    grep '^ENCRYPTION_KEY = "' "$CONFIG_FILE" 2>/dev/null | sed -n 's/.*"\(.*\)".*/\1/p'
}

#######################################
# 4. Process management
#######################################

is_running() {
    [[ -f "$PID_FILE" ]] && {
        pid=$(cat "$PID_FILE")
        kill -0 "$pid" 2>/dev/null && return 0 || { rm -f "$PID_FILE"; return 1; }
    } || return 1
}

get_valid() {
    tail -200 "$LOG_FILE" 2>/dev/null | grep -E 'valid=[0-9]+' | tail -1 | sed -n 's/.*valid=\([0-9]\+\).*/\1/p' || echo 0
}

get_rejected() {
    tail -200 "$LOG_FILE" 2>/dev/null | grep -E 'rejected=[0-9]+' | tail -1 | sed -n 's/.*rejected=\([0-9]\+\).*/\1/p' || echo 0
}

get_active() {
    local v=$(tail -200 "$LOG_FILE" 2>/dev/null | grep -E 'Total Active:|Remaining:|Active resolvers:' | tail -1 | sed -n 's/.*\(Total Active\|Remaining\|Active resolvers\): *\([0-9]\+\).*/\2/p')
    [[ -z "$v" ]] && v=$(get_valid)
    echo "$v"
}

get_stream() {
    tail -200 "$LOG_FILE" 2>/dev/null | grep 'Stream ID:' | tail -1 | sed -n 's/.*Stream ID: *\([0-9]\+\).*/\1/p' || echo 0
}

proxy_ready() {
    tail -50 "$LOG_FILE" 2>/dev/null | grep -q "SOCKS5 Proxy server is listening" && echo "yes" || echo "no"
}

kill_all_clients() {
    [[ -f "$PID_FILE" ]] && {
        kill "$(cat "$PID_FILE")" 2>/dev/null
        sleep 1
        kill -9 "$(cat "$PID_FILE")" 2>/dev/null
        rm -f "$PID_FILE"
    }
    pkill -f "$(basename "$CLIENT_BIN")" 2>/dev/null || true
    sleep 1
}

start_client() {
    # Check if binary exists
    if [[ ! -f "${CLIENT_BIN#./}" ]] && [[ ! -f "$CLIENT_BIN" ]]; then
        printf "%b\n" "$ERR_BINARY_NOT_FOUND"
        printf "Looking for: %s\n" "$CLIENT_BIN"
        printf "Available files in $(pwd):\n"
        ls -la MasterDnsVPN* 2>/dev/null || echo "  None found"
        sleep 3
        return 1
    fi
    
    kill_all_clients
    chmod +x "$CLIENT_BIN" 2>/dev/null || true
    [[ -f "$LOG_FILE" ]] && mv -f "$LOG_FILE" "$LOG_BACKUP" 2>/dev/null || true
    > "$LOG_FILE"
    nohup "$CLIENT_BIN" -config "$CONFIG_FILE" < /dev/null >> "$LOG_FILE" 2>&1 &
    printf '%s' "$!" > "$PID_FILE"
    disown "$!"
    sleep 2
}

stop_client() { kill_all_clients; }

restart_client() {
    printf "%b\n" "$SETTINGS_RESTARTING"
    stop_client
    sleep 2
    start_client
    printf "%b\n" "$MSG_DONE"
    sleep 1
}

show_log_view() {
    clear
    printf "── Log (press Q to exit) ──\n\n"
    if [[ -f "$LOG_FILE" ]]; then
        tail -n 50 -f "$LOG_FILE" 2>/dev/null & tp=$!
        while true; do
            read -rsn1 -t 0.5 key 2>/dev/null
            if [[ "$key" == "q" || "$key" == "Q" ]]; then
                kill "$tp" 2>/dev/null || true
                break
            fi
        done
        wait "$tp" 2>/dev/null || true
    else
        printf "No log.\n"
        read -r
    fi
}

#######################################
# 5. Profile management - Enhanced
#######################################

list_profiles() { ls "$PROFILES_DIR" 2>/dev/null | grep '\.toml$' | sed 's/\.toml$//' || true; }

profile_exists() {
    local name="$1"
    [[ -f "$PROFILES_DIR/${name}.toml" ]] && return 0
    return 1
}

create_single_profile() {
    local template_idx="$1"
    local base_name="$2"
    local domain="$3"
    local key="$4"
    
    local template_file="${TEMPLATE_FILES_MAP[$template_idx]}"
    local template_name="${TEMPLATE_NAMES_MAP[$template_idx]}"
    local profile_name="${base_name}-${template_name}"
    
    if [[ ! -f "$template_file" ]]; then
        printf "  ${RED}Template not found: %s${NC}\n" "$template_name"
        return 1
    fi
    
    if profile_exists "$profile_name"; then
        printf "  ${YELLOW}Skip existing: %s${NC}\n" "$profile_name"
        return 0
    fi
    
    cp "$template_file" "$PROFILES_DIR/${profile_name}.toml"
    sed -i "s|^DOMAINS = \[.*\]|DOMAINS = [\"$domain\"]|" "$PROFILES_DIR/${profile_name}.toml"
    sed -i "s|^ENCRYPTION_KEY = \".*\"|ENCRYPTION_KEY = \"$key\"|" "$PROFILES_DIR/${profile_name}.toml"
    
    [[ -f "$RESOLVERS_FILE" ]] && cp "$RESOLVERS_FILE" "$PROFILES_DIR/${profile_name}.resolvers.txt"
    
    printf "  ${GREEN}Created: %s${NC}\n" "$profile_name"
    return 0
}

create_all_profiles() {
    printf "\n${CYAN}══════ Create All 8 Profiles ══════${NC}\n\n"
    
    printf "%b\n" "$GET_BASE_NAME_PROMPT"
    printf "> "
    read -r base_name
    [[ -z "$base_name" ]] && { printf "%b\n" "$ERR_REQUIRED"; return 1; }
    
    printf "\n${WHITE}Domain:${NC}\n> "
    read -r domain
    [[ -z "$domain" ]] && { printf "%b\n" "$ERR_REQUIRED"; return 1; }
    
    printf "\n${WHITE}Encryption Key:${NC}\n> "
    read -r key
    [[ -z "$key" ]] && { printf "%b\n" "$ERR_REQUIRED"; return 1; }
    
    printf "\n${GREEN}Creating profiles...${NC}\n\n"
    
    local created=0
    for idx in 0 1 2 3 4 5 6 7; do
        if create_single_profile "$idx" "$base_name" "$domain" "$key"; then
            ((created++))
        fi
    done
    
    printf "\n${GREEN}Created %d profiles.${NC}\n" "$created"
    sleep 2
    return 0
}

create_profile() {
    clear
    render_profile_screen
    
    if [[ ! -f "$CONFIG_FILE" ]] || ! has_valid_config; then
        printf "\n%b\n" "$FIRST_RUN_RECOMMENDED"
    fi
    
    read -r tc
    
    if [[ "$tc" == "8" ]]; then
        create_all_profiles
        return $?
    fi
    
    if [[ "$tc" == "9" ]]; then
        return 0
    fi
    
    if [[ ! "$tc" =~ ^[0-7]$ ]]; then
        printf "\n%b\n" "$ERR_INVALID_CHOICE"
        sleep 2
        return 1
    fi
    
    local template_file="${TEMPLATE_FILES_MAP[$tc]}"
    local template_name="${TEMPLATE_NAMES_MAP[$tc]}"
    
    if [[ ! -f "$template_file" ]]; then
        printf "\n${RED}Template not found: %s${NC}\n" "$template_name"
        sleep 2
        return 1
    fi
    
    printf "\n${WHITE}Enter a name for this profile:${NC}\n> "
    read -r name
    [[ -z "$name" ]] && { printf "%b\n" "$ERR_REQUIRED"; sleep 2; return 1; }
    
    printf "\n${WHITE}Domain:${NC}\n> "
    read -r domain
    [[ -z "$domain" ]] && { printf "%b\n" "$ERR_REQUIRED"; sleep 2; return 1; }
    
    printf "\n${WHITE}Encryption Key:${NC}\n> "
    read -r key
    [[ -z "$key" ]] && { printf "%b\n" "$ERR_REQUIRED"; sleep 2; return 1; }
    
    cp "$template_file" "$CONFIG_FILE"
    sed -i "s|^DOMAINS = \[.*\]|DOMAINS = [\"$domain\"]|" "$CONFIG_FILE"
    sed -i "s|^ENCRYPTION_KEY = \".*\"|ENCRYPTION_KEY = \"$key\"|" "$CONFIG_FILE"
    
    cp "$CONFIG_FILE" "$PROFILES_DIR/${name}.toml"
    [[ -f "$RESOLVERS_FILE" ]] && cp "$RESOLVERS_FILE" "$PROFILES_DIR/${name}.resolvers.txt"
    
    if auto_parallelism_enabled; then
        local v=$(update_all_configs_parallelism)
        printf "\n"$MSG_PAR_UPDATED"\n" "$v"
    fi
    
    printf "\n"$MSG_DONE"\n"
    sleep 2
    return 0
}

load_profile() {
    clear
    printf "%b\n\n" "$LOAD_PROFILE_HEADER"
    local profiles=($(list_profiles))
    if [[ ${#profiles[@]} -eq 0 ]]; then
        printf "%b\n" "$ERR_NO_PROFILES"
        printf "\n${WHITE}How to create a profile:${NC}\n"
        printf "  1. Go to Manage Profiles (option 6)\n"
        printf "  2. Select 'Create' (option 1)\n"
        printf "  3. Choose a template type (0-7)\n"
        printf "  4. Enter a name, domain, and encryption key\n\n"
        sleep 5
        return
    fi
    is_running && { printf "%b\n" "$INFO_STOPPING"; stop_client; }
    
    printf "Available profiles:\n\n"
    printf "%-3s %-30s %s\n" "#" "Name" "Description"
    printf "──────────────────────────────────────────────────────────────────────\n"
    for i in "${!profiles[@]}"; do
        printf "  %-2d %-30s\n" $((i+1)) "${profiles[$i]}"
    done
    printf "\n  %-2d Back\n\n" $(( ${#profiles[@]} + 1 ))
    
    printf "Select profile number: "
    read -r num
    
    if [[ "$num" =~ ^[0-9]+$ ]] && [[ $num -ge 1 ]] && [[ $num -le ${#profiles[@]} ]]; then
        local selected="${profiles[$((num-1))]}"
        cp "$PROFILES_DIR/${selected}.toml" "$CONFIG_FILE"
        if [[ -f "$PROFILES_DIR/${selected}.resolvers.txt" ]]; then
            cp "$PROFILES_DIR/${selected}.resolvers.txt" "$RESOLVERS_FILE"
        fi
        printf "\n"$MSG_LOADED"\n"
    elif [[ $num -eq $(( ${#profiles[@]} + 1 )) ]]; then
        return
    else
        printf "\n"$ERR_INVALID_NUMBER"\n"
    fi
    sleep 2
}

delete_profile() {
    clear
    printf "%b\n\n" "$DELETE_PROFILE_HEADER"
    local profiles=($(list_profiles))
    if [[ ${#profiles[@]} -eq 0 ]]; then
        printf "%b\n" "$ERR_NO_PROFILES"
        sleep 2
        return
    fi
    
    printf "Profiles:\n\n"
    for i in "${!profiles[@]}"; do
        printf "  %d. %s\n" $((i+1)) "${profiles[$i]}"
    done
    printf "  %d. Back\n\nDelete:\n> " $(( ${#profiles[@]} + 1 ))
    read -r num
    
    if [[ "$num" =~ ^[0-9]+$ ]] && [[ $num -ge 1 ]] && [[ $num -le ${#profiles[@]} ]]; then
        local selected="${profiles[$((num-1))]}"
        rm -f "$PROFILES_DIR/${selected}.toml" "$PROFILES_DIR/${selected}.resolvers.txt" 2>/dev/null
        printf "\n"$MSG_DELETED"\n"
    elif [[ $num -eq $(( ${#profiles[@]} + 1 )) ]]; then
        return
    else
        printf "\n"$ERR_INVALID_NUMBER"\n"
    fi
    sleep 2
}

profile_menu() {
    clear
    printf "%b" "$PROFILE_MENU"
    read -r c
    case "$c" in
        1) create_profile ;;
        2) load_profile ;;
        3) delete_profile ;;
        4) return ;;
    esac
}

#######################################
# 6. MTU Speed Test (unchanged, keep existing)
#######################################

# ... (MTU Speed Test functions remain the same as before)
# I'm keeping them as is to save space, but they should be copied from your original

get_test_valid() {
    tail -200 "$MTU_TEST_DIR/test/client.log" 2>/dev/null | grep -E 'valid=[0-9]+' | tail -1 | sed -n 's/.*valid=\([0-9]\+\).*/\1/p' || echo 0
}

get_test_rejected() {
    tail -200 "$MTU_TEST_DIR/test/client.log" 2>/dev/null | grep -E 'rejected=[0-9]+' | tail -1 | sed -n 's/.*rejected=\([0-9]\+\).*/\1/p' || echo 0
}

get_test_active() {
    local v=$(tail -200 "$MTU_TEST_DIR/test/client.log" 2>/dev/null | grep -E 'Total Active:|Remaining:' | tail -1 | sed -n 's/.*\(Total Active\|Remaining\): *\([0-9]\+\).*/\2/p')
    [[ -z "$v" ]] && v=$(get_test_valid)
    echo "$v"
}

get_test_stream() {
    tail -200 "$MTU_TEST_DIR/test/client.log" 2>/dev/null | grep 'Stream ID:' | tail -1 | sed -n 's/.*Stream ID: *\([0-9]\+\).*/\1/p' || echo 0
}

test_proxy_ready() {
    tail -50 "$MTU_TEST_DIR/test/client.log" 2>/dev/null | grep -q "SOCKS5 Proxy server is listening" && echo "yes" || echo "no"
}

start_mtu_speed_test() {
    [[ ! -f "$CLIENT_BIN" ]] && { printf "%b\n" "$ERR_BINARY_NOT_FOUND"; sleep 2; return; }
    [[ ! -f "$CONFIG_FILE" ]] && { printf "%b\n" "$ERR_NO_CONFIG"; sleep 2; return; }
    [[ ! -f "$RESOLVERS_FILE" || ! -s "$RESOLVERS_FILE" ]] && { printf "%b\n" "$ERR_NO_RESOLVERS"; sleep 2; return; }
    command -v curl &>/dev/null || { printf "%b\n" "$ERR_NEED_CURL"; sleep 3; return; }
    
    clear
    printf "%b\n\n" "$MTU_INFO_BOX"
    printf "%b\n\n" "$MTU_INFO_TEXT"
    printf "%b" "$MTU_START_PROMPT"
    read -r c
    [[ "$c" != "y" && "$c" != "Y" ]] && return
    
    kill_all_clients
    
    PORTS=(18001 18002 18003 18004 18005 18006)
    MIN_UP=(30 50 70 90 110 130)
    MAX_UP=(50 70 90 110 130 150)
    MIN_DOWN=(60 260 460 660 860 1060)
    MAX_DOWN=(300 500 700 900 1100 1300)
    
    declare -A total_bytes
    declare -A final_valid
    declare -A final_rejected
    for i in 1 2 3 4 5 6; do
        total_bytes[$i]=0
        final_valid[$i]=0
        final_rejected[$i]=0
    done
    abort_all=0
    
    for i in 1 2 3 4 5 6; do
        [[ $abort_all -eq 1 ]] && break
        idx=$((i-1))
        port=${PORTS[$idx]}
        
        rm -rf "$MTU_TEST_DIR"; mkdir -p "$MTU_TEST_DIR/test"
        cp "$CLIENT_BIN" "$MTU_TEST_DIR/test/"
        cp "$CONFIG_FILE" "$MTU_TEST_DIR/test/client_config.toml"
        cp "$RESOLVERS_FILE" "$MTU_TEST_DIR/test/client_resolvers.txt"
        sed -i "s|^LISTEN_PORT = .*|LISTEN_PORT = $port|" "$MTU_TEST_DIR/test/client_config.toml"
        sed -i "s|^MIN_UPLOAD_MTU = .*|MIN_UPLOAD_MTU = ${MIN_UP[$idx]}|" "$MTU_TEST_DIR/test/client_config.toml"
        sed -i "s|^MAX_UPLOAD_MTU = .*|MAX_UPLOAD_MTU = ${MAX_UP[$idx]}|" "$MTU_TEST_DIR/test/client_config.toml"
        sed -i "s|^MIN_DOWNLOAD_MTU = .*|MIN_DOWNLOAD_MTU = ${MIN_DOWN[$idx]}|" "$MTU_TEST_DIR/test/client_config.toml"
        sed -i "s|^MAX_DOWNLOAD_MTU = .*|MAX_DOWNLOAD_MTU = ${MAX_DOWN[$idx]}|" "$MTU_TEST_DIR/test/client_config.toml"
        
        cd "$MTU_TEST_DIR/test"
        chmod +x "$CLIENT_BIN" 2>/dev/null || true
        nohup "$CLIENT_BIN" -config "./client_config.toml" < /dev/null >> "./client.log" 2>&1 &
        tp=$!
        cd "$MASTER_DNS_DIR"
        
        proxy_ok=0
        bytes=0
        skipped=0
        dl_start=0
        dl_timeout=0
        curl_pid=""
        
        while true; do
            clear
            print_mtu_step_box "$i"
            printf "\n${WHITE}Port %d: UP[%d-%d] DOWN[%d-%d]${NC}\n\n" "$port" "${MIN_UP[$idx]}" "${MAX_UP[$idx]}" "${MIN_DOWN[$idx]}" "${MAX_DOWN[$idx]}"
            
            v=$(get_test_valid)
            r=$(get_test_rejected)
            a=$(get_test_active)
            s=$(get_test_stream)
            pr=$(test_proxy_ready)
            ps="${RED}Waiting...${NC}"
            [[ "$pr" == "yes" ]] && ps="${GREEN}Ready ✓${NC}"
            printf "Resolvers: ${GREEN}%s${NC}/${RED}%s${NC} | Active: ${CYAN}%s${NC} | Streams: ${CYAN}%s${NC} | Proxy: %b\n" "$v" "$r" "$a" "$s" "$ps"
            
            if [[ $proxy_ok -eq 1 ]]; then
                now=$(date +%s)
                el=$((now - dl_start))
                rem=$((dl_timeout - el))
                [[ $rem -lt 0 ]] && rem=0
                sz=$(wc -c < "$MTU_TEST_DIR/test/download.tmp" 2>/dev/null || echo 0)
                printf "Download: ${GREEN}%d${NC} bytes | Time: %ds/%ds\n" "$sz" "$el" "$dl_timeout"
                if [[ $el -ge $dl_timeout ]]; then
                    proxy_ok=2
                    break
                fi
                if ! kill -0 "$curl_pid" 2>/dev/null; then
                    proxy_ok=2
                    break
                fi
            fi
            
            printf "\n${YELLOW}[L] View Log  [S] Skip  [Q] Abort${NC}\n"
            [[ $proxy_ok -eq 0 ]] && printf "Waiting for proxy (30-60s)...\n"
            printf "> "
            read -rsn1 -t 1 key 2>/dev/null || true
            case "$key" in
                l|L)
                    clear
                    printf "── Test Log (Q to exit) ──\n\n"
                    if [[ -f "$MTU_TEST_DIR/test/client.log" ]]; then
                        tail -n 50 -f "$MTU_TEST_DIR/test/client.log" 2>/dev/null & ltp=$!
                        while true; do
                            read -rsn1 -t 0.5 lkey 2>/dev/null
                            if [[ "$lkey" == "q" || "$lkey" == "Q" ]]; then
                                kill "$ltp" 2>/dev/null || true
                                break
                            fi
                        done
                        wait "$ltp" 2>/dev/null || true
                    else
                        printf "No log yet.\n"
                        read -r
                    fi
                    ;;
                s|S)
                    skipped=1
                    break
                    ;;
                q|Q)
                    abort_all=1
                    break
                    ;;
            esac
            
            if [[ $proxy_ok -eq 0 ]] && [[ "$(test_proxy_ready)" == "yes" ]]; then
                proxy_ok=1
                dl_timeout=90
                dl_start=$(date +%s)
                rm -f "$MTU_TEST_DIR/test/download.tmp"
                curl -x "socks5h://127.0.0.1:$port" -o "$MTU_TEST_DIR/test/download.tmp" -s --max-time "$dl_timeout" \
                    "https://speed.cloudflare.com/__down?bytes=2097152" 2>/dev/null &
                curl_pid=$!
            fi
        done
        
        if [[ $proxy_ok -eq 2 ]]; then
            wait "$curl_pid" 2>/dev/null || true
            if [[ -f "$MTU_TEST_DIR/test/download.tmp" ]]; then
                actual_size=$(wc -c < "$MTU_TEST_DIR/test/download.tmp" 2>/dev/null || echo 0)
                if [[ $actual_size -ge 2097152 ]]; then
                    bytes=2097152
                    printf "\n${GREEN}Download complete: %d bytes${NC}\n" "$bytes"
                else
                    bytes=$actual_size
                    printf "\n${YELLOW}Download incomplete: %d/%d bytes${NC}\n" "$bytes" "2097152"
                fi
            else
                printf "\n${RED}Download failed!${NC}\n"
            fi
            sleep 1
        fi
        
        final_valid[$i]=$(get_test_valid)
        final_rejected[$i]=$(get_test_rejected)
        total_bytes[$i]=$((total_bytes[$i] + bytes))
        
        kill "$tp" 2>/dev/null || true
        sleep 1
        kill -9 "$tp" 2>/dev/null || true
        rm -rf "$MTU_TEST_DIR"
    done
    
    clear
    printf "%b\n\n" "$MTU_RESULTS_HEADER"
    printf "${WHITE}Port    UP MTU      DOWN MTU     Resolvers      Downloaded${NC}\n"
    printf "──────────────────────────────────────────────────────────────\n"
    best_step=0
    best_bytes=0
    for i in 1 2 3 4 5 6; do
        idx=$((i-1))
        tb=${total_bytes[$i]}
        v=${final_valid[$i]}
        r=${final_rejected[$i]}
        printf "  %-5d  %-11s  %-12s  ${GREEN}%-4s${NC}/${RED}%-4s${NC}  ${GREEN}%d bytes${NC}\n" \
            "${PORTS[$idx]}" "${MIN_UP[$idx]}-${MAX_UP[$idx]}" "${MIN_DOWN[$idx]}-${MAX_DOWN[$idx]}" "$v" "$r" "$tb"
        if [[ $tb -gt $best_bytes ]]; then
            best_bytes=$tb
            best_step=$i
        fi
    done
    if [[ $best_step -gt 0 ]]; then
        bi=$((best_step-1))
        printf "\n"$MTU_BEST_MSG"\n" "${PORTS[$bi]}" "${MIN_UP[$bi]}" "${MAX_UP[$bi]}" "${MIN_DOWN[$bi]}" "${MAX_DOWN[$bi]}" "$best_bytes"
    fi
    printf "\n${YELLOW}Press ENTER to return...${NC}"
    read -r
}

#######################################
# 7. Resolver Health Check (keep existing)
#######################################

# ... (Resolver Health Check functions remain the same)
# I'm keeping them as is to save space

start_resolver_health_check() {
    clear
    printf "%b\n\n" "$HEALTH_INFO_BOX"
    printf "%b\n\n" "$HEALTH_INFO_TEXT"
    
    if ! command -v curl &>/dev/null; then
        printf "%b\n" "$ERR_NEED_CURL"
        sleep 3
        return
    fi
    if ! is_running; then
        printf "%b\n" "$ERR_CLIENT_NOT_RUNNING"
        printf "${YELLOW}Start the client first (Option 1).${NC}\n"
        sleep 3
        return
    fi
    if [[ "$(proxy_ready)" != "yes" ]]; then
        printf "%b\n" "$INFO_PROXY_WAITING"
        local wait_count=0
        while [[ "$(proxy_ready)" != "yes" && $wait_count -lt 60 ]]; do
            sleep 1
            ((wait_count++))
        done
        if [[ "$(proxy_ready)" != "yes" ]]; then
            printf "%b\n" "$ERR_PROXY_NOT_READY"
            sleep 3
            return
        fi
        printf "%b\n" "$INFO_PROXY_READY_NOW"
    fi
    
    printf "${WHITE}Select test type:${NC}\n"
    printf "  1. Download from Cloudflare (custom size)\n"
    printf "  2. TCP ping to Telegram (149.154.167.92:443)\n"
    printf "  3. Back\n\nChoose [1-3]: "
    read -r test_type
    case "$test_type" in
        1) ;;
        2) ;;
        3) return ;;
        *) printf "%b\n" "$ERR_INVALID_CHOICE"
           sleep 2
           return
           ;;
    esac
    
    local file_size_bytes=0 file_size_kb=0
    if [[ "$test_type" == "1" ]]; then
        printf "${WHITE}Enter file size in KB (e.g. 100, 500, 1024):${NC}\n> "
        read -r file_size_kb
        if [[ ! "$file_size_kb" =~ ^[0-9]+$ || "$file_size_kb" -lt 10 ]]; then
            printf "${RED}Invalid size. Must be a number >= 10 KB.${NC}\n"
            sleep 2
            return
        fi
        file_size_bytes=$(( file_size_kb * 1024 ))
    fi
    
    printf "${WHITE}Enter request timeout in seconds (e.g. 10):${NC}\n> "
    read -r req_timeout
    [[ ! "$req_timeout" =~ ^[0-9]+$ || "$req_timeout" -lt 1 ]] && {
        printf "${RED}Invalid timeout.${NC}\n"
        sleep 2
        return
    }
    
    printf "${WHITE}Enter interval in milliseconds (e.g. 500, min 200):${NC}\n> "
    read -r interval_ms
    [[ ! "$interval_ms" =~ ^[0-9]+$ || "$interval_ms" -lt 200 ]] && {
        printf "${RED}Invalid interval.${NC}\n"
        sleep 2
        return
    }
    
    local interval_sec=$(awk "BEGIN {printf \"%.3f\", $interval_ms / 1000}")
    local tmpdir="${TMPDIR:-/tmp}/mdv_health_$$"
    rm -rf "$tmpdir"
    mkdir -p "$tmpdir"
    local launched_file="$tmpdir/launched"
    local stop_file="$tmpdir/stop"
    echo 0 > "$launched_file"
    echo 0 > "$stop_file"
    
    local MAX_CONCURRENT=10
    count_running() { pgrep -f 'curl.*(__down|149\.154\.167\.92)' 2>/dev/null | wc -l; }
    
    (
        while [[ $(<"$stop_file") -eq 0 ]]; do
            local running=$(count_running)
            if [[ $running -lt $MAX_CONCURRENT ]]; then
                local idx=$( ( flock -x 200; read -r num < "$launched_file"; echo $((num+1)) > "$launched_file"; echo $num ) 200>"$tmpdir/lock" )
                local ts=$(date +%s.%N 2>/dev/null || date +%s)
                (
                    if [[ "$test_type" == "1" ]]; then
                        output=$(curl -x "socks5h://127.0.0.1:18000" \
                            -o /dev/null -s \
                            -w "%{http_code} %{size_download} %{time_total}" \
                            --connect-timeout "$req_timeout" --max-time "$req_timeout" \
                            "https://speed.cloudflare.com/__down?bytes=$file_size_bytes" 2>/dev/null)
                        http_code=$(echo "$output" | awk '{print $1}')
                        size=$(echo "$output" | awk '{print $2}')
                        latency=$(echo "$output" | awk '{print $3}')
                        echo "$idx $ts $http_code $latency $size" > "$tmpdir/result_$idx.tmp" 2>/dev/null
                    else
                        output=$(curl -x "socks5h://127.0.0.1:18000" \
                            -o /dev/null -s \
                            -w "%{http_code} %{time_total}" \
                            --connect-timeout "$req_timeout" --max-time "$req_timeout" \
                            -k "https://149.154.167.92:443" 2>/dev/null)
                        http_code=$(echo "$output" | awk '{print $1}')
                        latency=$(echo "$output" | awk '{print $2}')
                        if [[ -n "$http_code" && "$http_code" =~ ^[0-9]+$ && "$latency" =~ ^[0-9.]+$ ]]; then
                            if (( $(echo "$latency > 0" | awk '{print ($1 > 0)}') )) && (( $(echo "$latency <= $req_timeout" | awk '{print ($1 <= '$req_timeout')}') )); then
                                echo "$idx $ts 200 $latency 0" > "$tmpdir/result_$idx.tmp" 2>/dev/null
                            else
                                echo "$idx $ts 000 $latency 0" > "$tmpdir/result_$idx.tmp" 2>/dev/null
                            fi
                        else
                            echo "$idx $ts 000 $latency 0" > "$tmpdir/result_$idx.tmp" 2>/dev/null
                        fi
                    fi
                    mv "$tmpdir/result_$idx.tmp" "$tmpdir/result_$idx" 2>/dev/null
                ) &
            fi
            sleep "$interval_sec" 2>/dev/null || sleep 0.2
        done
    ) &
    local fire_pid=$!
    
    LAST_ACTIVE_COUNT=""
    get_live_active_count() {
        local a=$(tail -200 "$LOG_FILE" 2>/dev/null | grep -E 'Total Active:|Remaining:' | tail -1 | sed 's/.*\(Total Active\|Remaining\): *//; s/[^0-9]//g')
        if [[ -n "$a" ]]; then
            LAST_ACTIVE_COUNT="$a"
            echo "$a"
        else
            [[ -z "$LAST_ACTIVE_COUNT" ]] && LAST_ACTIVE_COUNT=$(count_resolvers)
            echo "$LAST_ACTIVE_COUNT"
        fi
    }
    
    local initial_active=$(get_live_active_count)
    
    clear
    printf "%b\n\n" "$HEALTH_RUNNING_BOX"
    printf "Test type: ${CYAN}%s${NC}\n" "$([[ "$test_type" == "1" ]] && echo "Cloudflare download ${file_size_kb}KB" || echo "Telegram HTTPS ping")"
    printf "Timeout: ${CYAN}%ss${NC}   Interval: ${CYAN}%s ms${NC}   Max concurrent: ${CYAN}%d${NC}\n" "$req_timeout" "$interval_ms" "$MAX_CONCURRENT"
    printf "Proxy: ${CYAN}127.0.0.1:18000${NC}\n\n"
    printf "${WHITE}Press ${YELLOW}[Q]${WHITE} to stop, ${YELLOW}[B]${WHITE} to back to menu.${NC}\n\n"
    printf "${WHITE}%-6s %-10s %-4s | %-10s${NC}\n" "Req#" "Time" "OK?" "Active Rsolv"
    printf "────────────────────────────────────────\n"
    
    local success=0 failed=0 total_latency=0 processed=0
    local start_time=$(date +%s)
    local last_active=$initial_active
    
    while true; do
        read -rsn1 -t 0.1 key 2>/dev/null || true
        if [[ "$key" == "q" || "$key" == "Q" ]]; then
            echo 1 > "$stop_file"
            break
        elif [[ "$key" == "b" || "$key" == "B" ]]; then
            echo 1 > "$stop_file"
            break
        fi
        
        local files=("$tmpdir"/result_*)
        if [[ -f "${files[0]}" ]]; then
            for f in "${files[@]}"; do
                [[ -f "$f" ]] || continue
                local idx ts http_code latency size
                read -r idx ts http_code latency size < "$f"
                rm -f "$f"
                ((processed++))
                
                local current_active=$(get_live_active_count)
                local active_change=""
                if [[ $current_active -lt $last_active ]]; then
                    active_change="${RED}↓${current_active}${NC}"
                elif [[ $current_active -gt $last_active ]]; then
                    active_change="${GREEN}↑${current_active}${NC}"
                else
                    active_change="${CYAN}=${current_active}${NC}"
                fi
                last_active=$current_active
                
                local ok_flag=0
                if [[ "$test_type" == "1" ]]; then
                    [[ "$http_code" == "200" && $size -ge $file_size_bytes ]] && ok_flag=1
                else
                    [[ "$http_code" =~ ^[0-9]+$ && "$http_code" -ge 100 && "$latency" != "0.000" ]] && ok_flag=1
                fi
                
                if [[ $ok_flag -eq 1 ]]; then
                    local status_icon="YES" status_color="${GREEN}"
                    ((success++))
                    total_latency=$(awk "BEGIN {printf \"%.3f\", $total_latency + $latency}" 2>/dev/null || echo "$total_latency")
                else
                    local status_icon="NO" status_color="${RED}"
                    ((failed++))
                fi
                
                printf "${status_color}%-6s %-10s %-4s${NC} | %b\n" "$idx" "${latency}s" "$status_icon" "$active_change"
            done
        fi
        
        if [[ $(<"$stop_file") -eq 1 ]] && ! kill -0 "$fire_pid" 2>/dev/null && ! ls "$tmpdir"/result_* &>/dev/null; then
            break
        fi
        sleep 0.2
    done
    
    echo 1 > "$stop_file"
    kill "$fire_pid" 2>/dev/null || true
    wait "$fire_pid" 2>/dev/null || true
    sleep 0.5
    pkill -f 'curl.*(__down|149\.154\.167\.92)' 2>/dev/null || true
    sleep 0.5
    
    local remaining_files=("$tmpdir"/result_*)
    if [[ -f "${remaining_files[0]}" ]]; then
        for f in "${remaining_files[@]}"; do
            [[ -f "$f" ]] || continue
            local idx ts http_code latency size
            read -r idx ts http_code latency size < "$f"
            rm -f "$f"
            ((processed++))
            local current_active=$(get_live_active_count)
            local active_change="${CYAN}=${current_active}${NC}"
            last_active=$current_active
            local ok_flag=0
            if [[ "$test_type" == "1" ]]; then
                [[ "$http_code" == "200" && $size -ge $file_size_bytes ]] && ok_flag=1
            else
                [[ "$http_code" =~ ^[0-9]+$ && "$http_code" -ge 100 && "$latency" != "0.000" ]] && ok_flag=1
            fi
            if [[ $ok_flag -eq 1 ]]; then
                status_icon="YES" status_color="${GREEN}"
                ((success++))
                total_latency=$(awk "BEGIN {printf \"%.3f\", $total_latency + $latency}" 2>/dev/null || echo "$total_latency")
            else
                status_icon="NO" status_color="${RED}"
                ((failed++))
            fi
            printf "${status_color}%-6s %-10s %-4s${NC} | %b\n" "$idx" "${latency}s" "$status_icon" "$active_change"
        done
    fi
    rm -rf "$tmpdir"
    
    local end_time=$(date +%s)
    local total_time=$((end_time - start_time))
    [[ $total_time -lt 1 ]] && total_time=1
    local final_active=$(get_live_active_count)
    
    clear
    printf "\n%b\n\n" "$HEALTH_SUMMARY_HEADER"
    printf "Test type:       ${CYAN}%s${NC}\n" "$([[ "$test_type" == "1" ]] && echo "Cloudflare download ${file_size_kb}KB" || echo "Telegram HTTPS ping (149.154.167.92:443)")"
    printf "Total requests:  ${CYAN}%d${NC}\n" "$processed"
    printf "Successful:      ${GREEN}%d${NC}\n" "$success"
    printf "Failed:          ${RED}%d${NC}\n" "$failed"
    printf "Duration:        ${CYAN}%d seconds${NC}\n" "$total_time"
    printf "Avg rate:        ${CYAN}%.1f req/sec${NC}\n" "$(awk "BEGIN {printf \"%.1f\", $processed / $total_time}")"
    if [[ $success -gt 0 ]]; then
        local avg_latency=$(awk "BEGIN {printf \"%.0f\", $total_latency / $success}" 2>/dev/null || echo "0")
        printf "Avg time (OK):   ${CYAN}%s ms${NC}\n" "$avg_latency"
    fi
    printf "Active (start):  ${CYAN}%s${NC}\n" "$initial_active"
    printf "Active (end):    ${CYAN}%s${NC}\n" "$final_active"
    if [[ "$initial_active" != "0" && "$final_active" != "0" ]]; then
        local diff=$(( initial_active - final_active ))
        if [[ $diff -gt 0 ]]; then
            printf "Removed:         ${RED}%d${NC}\n" "$diff"
        elif [[ $diff -lt 0 ]]; then
            printf "Added:           ${GREEN}%d${NC}\n" $(( -diff ))
        else
            printf "Removed:         0\n"
        fi
    fi
    
    printf "\n${YELLOW}Press ENTER to return to menu...${NC}"
    read -r
}

#######################################
# 8. Multi-Connection Functions
#######################################

show_proxy_lists() {
    local count=$1
    local base_port=$2
    
    echo ""
    echo "${CYAN}══════════════════════════════════════════════════════════════════${NC}"
    echo "${GREEN}Add these proxies to Telegram (Settings → Advanced → Connection Type):${NC}"
    echo "${YELLOW}Enable 'Use Proxy' and 'Auto-switch Proxy' then add these:${NC}"
    echo ""
    
    for ((i=0; i<count; i++)); do
        local port=$((base_port + i))
        echo "${WHITE}${i}. https://t.me/socks?server=127.0.0.1&port=${port}${NC}"
    done
    
    echo ""
    echo "${CYAN}──────────────────────────────────────────────────────────────────${NC}"
    echo "${GREEN}Add these configs to Hiddify (Copy and paste):${NC}"
    echo ""
    
    for ((i=0; i<count; i++)); do
        local port=$((base_port + i))
        echo "${WHITE}socks://Og@127.0.0.1:${port}#${port}${NC}"
    done
    
    echo ""
    echo "${CYAN}══════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

get_multi_valid() {
    tail -200 "$MULTI_DIR/$1/client.log" 2>/dev/null | grep -E 'valid=[0-9]+' | tail -1 | sed -n 's/.*valid=\([0-9]\+\).*/\1/p' || echo 0
}

get_multi_rejected() {
    tail -200 "$MULTI_DIR/$1/client.log" 2>/dev/null | grep -E 'rejected=[0-9]+' | tail -1 | sed -n 's/.*rejected=\([0-9]\+\).*/\1/p' || echo 0
}

get_multi_active() {
    local v=$(tail -200 "$MULTI_DIR/$1/client.log" 2>/dev/null | grep -E 'Total Active:|Remaining:' | tail -1 | sed -n 's/.*\(Total Active\|Remaining\): *\([0-9]\+\).*/\2/p')
    [[ -z "$v" ]] && v=$(get_multi_valid "$1")
    echo "$v"
}

get_multi_stream() {
    tail -200 "$MULTI_DIR/$1/client.log" 2>/dev/null | grep 'Stream ID:' | tail -1 | sed -n 's/.*Stream ID: *\([0-9]\+\).*/\1/p' || echo 0
}

multi_proxy_ready() {
    tail -50 "$MULTI_DIR/$1/client.log" 2>/dev/null | grep -q "SOCKS5 Proxy server is listening" && echo "yes" || echo "no"
}

show_multi_dashboard() {
    local pids=("$@")
    local count=${#pids[@]}
    
    local old_trap=$(trap -p INT)
    trap 'echo ""; for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; done; exit 0' INT
    
    while true; do
        clear
        printf "%b\n\n" "$MULTI_DASHBOARD_HEADER"
        print_multi_col_headers
        printf "──────────────────────────────────────────────────────────────\n"
        
        for i in $(seq 1 $count); do
            local dir="$MULTI_DIR/$i"
            local port=$(cat "$dir/port.txt" 2>/dev/null || echo "?")
            local pname=$(cat "$dir/profile_name.txt" 2>/dev/null || echo "unknown")
            local v=$(get_multi_valid "$i")
            local r=$(get_multi_rejected "$i")
            local a=$(get_multi_active "$i")
            local s=$(get_multi_stream "$i")
            local pr=$(multi_proxy_ready "$i")
            local ps="${RED}✗${NC}"
            [[ "$pr" == "yes" ]] && ps="${GREEN}✓${NC}"
            
            printf "%-2d %-6s %-28s ${GREEN}%8s${NC} ${RED}%8s${NC} ${CYAN}%8s${NC} ${CYAN}%8s${NC} %6b\n" \
                   "$i" "$port" "$pname" "$v" "$r" "$a" "$s" "$ps"
        done
        
        printf "\n%b\n> " "$MULTI_DASHBOARD_KEYS"
        read -rsn1 -t 2 ch 2>/dev/null || true
        
        case "$ch" in
            v|V)
                printf "\nLog of instance [1-%d]: " "$count"
                read -r ln
                if [[ "$ln" =~ ^[0-9]+$ && "$ln" -ge 1 && "$ln" -le $count ]]; then
                    clear
                    local dir="$MULTI_DIR/$ln"
                    local pname=$(cat "$dir/profile_name.txt" 2>/dev/null || echo "unknown")
                    printf "── Log #%d (%s) (press Q to exit) ──\n\n" "$ln" "$pname"
                    if [[ -f "$dir/client.log" ]]; then
                        tail -n 50 -f "$dir/client.log" 2>/dev/null & tp=$!
                        while true; do
                            read -rsn1 -t 0.5 lkey 2>/dev/null
                            if [[ "$lkey" == "q" || "$lkey" == "Q" ]]; then
                                kill "$tp" 2>/dev/null || true
                                break
                            fi
                        done
                        wait "$tp" 2>/dev/null || true
                    else
                        printf "No log.\n"
                        read -r
                    fi
                fi
                ;;
            s|S)
                printf "\n%b\n" "$MSG_STOPPING_ALL"
                for pid in "${pids[@]}"; do
                    kill "$pid" 2>/dev/null || true
                done
                sleep 2
                for pid in "${pids[@]}"; do
                    kill -9 "$pid" 2>/dev/null || true
                done
                printf "%b\n" "$MSG_ALL_STOPPED"
                sleep 1
                eval "$old_trap" 2>/dev/null || true
                return
                ;;
            q|Q)
                eval "$old_trap" 2>/dev/null || true
                return
                ;;
        esac
    done
}

show_multi_info() {
    clear
    printf "%b\n\n" "$MULTI_INFO_HEADER"
    printf "%b\n\n" "$MULTI_SAMPLE_PROXY"
    printf "%b" "$MULTI_PROCEED"
    read -r c
    [[ "$c" == "y" || "$c" == "Y" ]] && return 0 || return 1
}

start_multi_profiles() {
    [[ ! -f "$CLIENT_BIN" ]] && { printf "%b\n" "$ERR_BINARY_NOT_FOUND"; sleep 2; return; }
    [[ ! -f "$CONFIG_FILE" ]] && { printf "%b\n" "$ERR_NO_CONFIG"; sleep 2; return; }
    show_multi_info || return
    
    local domain=$(get_domain_from_config)
    local key=$(get_key_from_config)
    if [[ -z "$domain" || -z "$key" ]]; then
        printf "%b\n" "$ERR_MISSING_DOMAIN_KEY"
        sleep 2
        return
    fi
    
    clear
    printf "%b\n\n" "$MULTI_PROFILE_SELECT_HEADER"
    printf "${WHITE}Available profiles:${NC}\n\n"
    printf "%s\n\n" "$MULTI_PROFILE_LIST"
    
    printf "%b" "$MULTI_RUN_ALL"
    read -r run_all
    
    local selected_indices=()
    
    if [[ "$run_all" == "y" || "$run_all" == "Y" ]]; then
        for i in 0 1 2 3 4 5 6 7; do
            selected_indices+=($i)
        done
    else
        printf "\n%b\n> " "$MULTI_SELECT_GUIDE"
        read -r user_selection
        user_selection="${user_selection// /}"
        IFS=',' read -ra nums <<< "$user_selection"
        for num in "${nums[@]}"; do
            if [[ "$num" =~ ^[0-7]$ ]]; then
                selected_indices+=($num)
            fi
        done
        if [[ ${#selected_indices[@]} -eq 0 ]]; then
            printf "\n%b\n" "$ERR_NO_VALID_SELECTION"
            sleep 2
            return
        fi
    fi
    
    local instance_count=${#selected_indices[@]}
    
    printf "\n${CYAN}══════════════════════════════════════════════════════════════════${NC}\n"
    printf "${GREEN}You are about to start ${instance_count} concurrent instances.${NC}\n"
    printf "${YELLOW}Ports will be assigned automatically starting from 18001.${NC}\n"
    printf "${CYAN}══════════════════════════════════════════════════════════════════${NC}\n\n"
    
    show_proxy_lists $instance_count 18001
    
    printf "${YELLOW}Press ENTER to continue or Q to cancel...${NC}\n> "
    read -r confirm
    if [[ "$confirm" == "q" || "$confirm" == "Q" ]]; then
        return
    fi
    
    printf "\n%b\n> " "$MULTI_CUSTOM_PAR"
    read -r custom_par
    local apply_custom_par=0
    if [[ -n "$custom_par" && "$custom_par" =~ ^[0-9]+$ && "$custom_par" -gt 0 ]]; then
        apply_custom_par=1
    fi
    
    kill_all_clients
    rm -rf "$MULTI_DIR"
    mkdir -p "$MULTI_DIR"
    local pids=()
    local instance=1
    local base_port=18001
    
    for idx in "${selected_indices[@]}"; do
        local port=$((base_port + instance - 1))
        local template="${TEMPLATE_FILES_MAP[$idx]}"
        local template_name="${TEMPLATE_NAMES_MAP[$idx]}"
        local dir="$MULTI_DIR/$instance"
        mkdir -p "$dir"
        
        if [[ ! -f "$template" ]]; then
            printf "${RED}Template ${template_name} not found, skipping.${NC}\n"
            ((instance++))
            continue
        fi
        
        cp "$CLIENT_BIN" "$dir/"
        cp "$template" "$dir/client_config.toml"
        [[ -f "$RESOLVERS_FILE" ]] && cp "$RESOLVERS_FILE" "$dir/client_resolvers.txt"
        
        sed -i '/^\s*=\s/d' "$dir/client_config.toml" 2>/dev/null || true
        sed -i "s|^DOMAINS = \[.*\]|DOMAINS = [\"$domain\"]|" "$dir/client_config.toml"
        sed -i "s|^ENCRYPTION_KEY = \".*\"|ENCRYPTION_KEY = \"$key\"|" "$dir/client_config.toml"
        sed -i "s|^LISTEN_PORT = .*|LISTEN_PORT = $port|" "$dir/client_config.toml"
        
        [[ $apply_custom_par -eq 1 ]] && sed -i "s|^MTU_TEST_PARALLELISM = .*|MTU_TEST_PARALLELISM = $custom_par|" "$dir/client_config.toml"
        
        echo "$port" > "$dir/port.txt"
        echo "$template_name" > "$dir/profile_name.txt"
        
        cd "$dir"
        chmod +x "$CLIENT_BIN" 2>/dev/null || true
        nohup "$CLIENT_BIN" -config "./client_config.toml" < /dev/null >> "./client.log" 2>&1 &
        pids+=($!)
        cd "$MASTER_DNS_DIR"
        
        printf "  %b profile %s on port ${CYAN}%d${NC} (PID %d)\n" "$MSG_STARTED" "$template_name" "$port" "${pids[-1]}"
        ((instance++))
    done
    
    if [[ ${#pids[@]} -eq 0 ]]; then
        printf "\n${RED}No profiles were started.${NC}\n"
        sleep 2
        return
    fi
    
    printf "\n${GREEN}Started %d profiles.${NC}\n" "${#pids[@]}"
    sleep 2
    show_multi_dashboard "${pids[@]}"
}

start_multi_mtu() {
    [[ ! -f "$CLIENT_BIN" ]] && { printf "%b\n" "$ERR_BINARY_NOT_FOUND"; sleep 2; return; }
    [[ ! -f "$CONFIG_FILE" ]] && { printf "%b\n" "$ERR_NO_CONFIG"; sleep 2; return; }
    [[ ! -f "$RESOLVERS_FILE" || ! -s "$RESOLVERS_FILE" ]] && { printf "%b\n" "$ERR_NO_RESOLVERS"; sleep 2; return; }
    show_multi_info || return
    
    local instance_count=6
    
    printf "\n${CYAN}══════════════════════════════════════════════════════════════════${NC}\n"
    printf "${GREEN}You are about to start ${instance_count} MTU test instances.${NC}\n"
    printf "${YELLOW}Ports will be assigned automatically starting from 18001.${NC}\n"
    printf "${CYAN}══════════════════════════════════════════════════════════════════${NC}\n\n"
    
    show_proxy_lists $instance_count 18001
    
    printf "${YELLOW}Press ENTER to continue or Q to cancel...${NC}\n> "
    read -r confirm
    if [[ "$confirm" == "q" || "$confirm" == "Q" ]]; then
        return
    fi
    
    printf "\n%b\n> " "$MULTI_CUSTOM_PAR"
    read -r custom_par
    local apply_custom_par=0
    if [[ -n "$custom_par" && "$custom_par" =~ ^[0-9]+$ && "$custom_par" -gt 0 ]]; then
        apply_custom_par=1
    fi
    
    kill_all_clients
    rm -rf "$MULTI_DIR"
    mkdir -p "$MULTI_DIR"
    local pids=()
    
    local MIN_UP=(30 50 70 90 110 130)
    local MAX_UP=(50 70 90 110 130 150)
    local MIN_DOWN=(60 260 460 660 860 1060)
    local MAX_DOWN=(300 500 700 900 1100 1300)
    
    for i in 1 2 3 4 5 6; do
        local idx=$((i-1))
        local port=$((18000 + i))
        local dir="$MULTI_DIR/$i"
        mkdir -p "$dir"
        
        cp "$CLIENT_BIN" "$dir/"
        cp "$CONFIG_FILE" "$dir/client_config.toml"
        cp "$RESOLVERS_FILE" "$dir/client_resolvers.txt"
        
        sed -i '/^\s*=\s/d' "$dir/client_config.toml" 2>/dev/null || true
        sed -i "s|^LISTEN_PORT = .*|LISTEN_PORT = $port|" "$dir/client_config.toml"
        sed -i "s|^MIN_UPLOAD_MTU = .*|MIN_UPLOAD_MTU = ${MIN_UP[$idx]}|" "$dir/client_config.toml"
        sed -i "s|^MAX_UPLOAD_MTU = .*|MAX_UPLOAD_MTU = ${MAX_UP[$idx]}|" "$dir/client_config.toml"
        sed -i "s|^MIN_DOWNLOAD_MTU = .*|MIN_DOWNLOAD_MTU = ${MIN_DOWN[$idx]}|" "$dir/client_config.toml"
        sed -i "s|^MAX_DOWNLOAD_MTU = .*|MAX_DOWNLOAD_MTU = ${MAX_DOWN[$idx]}|" "$dir/client_config.toml"
        
        [[ $apply_custom_par -eq 1 ]] && sed -i "s|^MTU_TEST_PARALLELISM = .*|MTU_TEST_PARALLELISM = $custom_par|" "$dir/client_config.toml"
        
        echo "$port" > "$dir/port.txt"
        echo "MTU-${MIN_UP[$idx]}-${MAX_UP[$idx]}-${MIN_DOWN[$idx]}-${MAX_DOWN[$idx]}" > "$dir/profile_name.txt"
        
        cd "$dir"
        chmod +x "$CLIENT_BIN" 2>/dev/null || true
        nohup "$CLIENT_BIN" -config "./client_config.toml" < /dev/null >> "./client.log" 2>&1 &
        pids+=($!)
        cd "$MASTER_DNS_DIR"
    done
    
    sleep 2
    show_multi_dashboard "${pids[@]}"
}

multi_connection_menu() {
    clear
    printf "%b" "$MULTI_MENU"
    read -r c
    case "$c" in
        1) start_multi_profiles ;;
        2) start_multi_mtu ;;
        3) return ;;
    esac
}

#######################################
# 9. Configuration editing
#######################################

edit_config() {
    open_editor "$CONFIG_FILE"
    if auto_parallelism_enabled; then
        local v=$(update_all_configs_parallelism)
        printf "\n"$MSG_PAR_UPDATED"\n" "$v"
        sleep 1
    fi
}

edit_resolvers() {
    open_editor "$RESOLVERS_FILE"
    if auto_parallelism_enabled; then
        local v=$(update_all_configs_parallelism)
        printf "\n"$MSG_PAR_UPDATED"\n" "$v"
        sleep 1
    fi
    # Show warning after editing if still empty
    check_resolvers_warning
}

backup_configs() {
    local backup_name="masterdns_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    cd "$SCRIPT_DIR"
    tar -czf "$backup_name" Configuration/ 2>/dev/null
    if [[ -f "$backup_name" ]]; then
        printf "$SETTINGS_BACKUP_DONE\n" "$backup_name"
    else
        printf "%b\n" "$SETTINGS_BACKUP_FAILED"
    fi
    sleep 2
}

first_run_check() {
    local retry_count=0
    while ! has_valid_config; do
        if [[ $retry_count -ge 3 ]]; then
            printf "\n${RED}Failed to create profile after 3 attempts. Exiting.${NC}\n"
            exit 1
        fi
        if create_profile; then
            break
        fi
        ((retry_count++))
    done
    
    if [[ ! -f "$RESOLVERS_FILE" || ! -s "$RESOLVERS_FILE" ]]; then
        clear
        printf "%b\n\n" "$RESOLVERS_SETUP_HEADER"
        printf "%b\n\n" "$RESOLVERS_SETUP_PROMPT"
        printf "> "
        read -r res_choice
        if [[ "$res_choice" == "y" || "$res_choice" == "Y" ]]; then
            touch "$RESOLVERS_FILE"
            open_editor "$RESOLVERS_FILE"
            if auto_parallelism_enabled; then
                update_all_configs_parallelism >/dev/null
            fi
        fi
    fi
    
    if [[ ! -f "$AUTO_MTU_FLAG" ]]; then
        show_parallelism_setup
    fi
}

#######################################
# 10. Settings menu
#######################################

settings_menu() {
    clear
    printf "%b\n\n" "$SETTINGS_HEADER"
    local auto_status
    if auto_parallelism_enabled; then
        auto_status="${GREEN}ON${NC}"
    else
        auto_status="${RED}OFF${NC}"
    fi
    printf "$SETTINGS_MENU\n\n" "$PARALLELISM_PERCENT" "$auto_status"
    printf "%b" "$SETTINGS_PROMPT"
    read -r s_choice
    case "$s_choice" in
        1)
            printf "\n%b\n> " "$SETTINGS_PCT_PROMPT"
            read -r new_pct
            if [[ "$new_pct" =~ ^[0-9]+$ && "$new_pct" -ge 1 && "$new_pct" -le 100 ]]; then
                PARALLELISM_PERCENT=$new_pct
                echo "$PARALLELISM_PERCENT" > "$PARALLELISM_FILE"
                printf "${GREEN}Percentage set to %d%%.${NC}\n" "$PARALLELISM_PERCENT"
                if auto_parallelism_enabled; then
                    update_all_configs_parallelism >/dev/null
                    printf "${GREEN}All configs updated.${NC}\n"
                fi
                sleep 2
            else
                printf "${RED}Invalid value.${NC}\n"
                sleep 2
            fi
            ;;
        2)
            if auto_parallelism_enabled; then
                set_auto_parallelism "no"
                printf "\n${YELLOW}Auto-manage turned OFF.${NC}\n"
            else
                set_auto_parallelism "yes"
                printf "\n${GREEN}Auto-manage turned ON, all configs updated.${NC}\n"
            fi
            sleep 2
            ;;
        3)
            backup_configs
            ;;
        4)
            restart_client
            ;;
        5) return ;;
    esac
}

#######################################
# 11. Main menu renderer
#######################################

draw_menu() {
    clear
    printf "%b\n\n" "$MAIN_HEADER"
    
    if is_running; then
        printf "$MSG_CLIENT_RUNNING\n" "$(cat "$PID_FILE")"
        if [[ "$(proxy_ready)" == "yes" ]]; then
            printf "$MSG_PROXY_READY\n" "$(get_active)" "$(get_stream)"
        else
            printf "$MSG_PROXY_WAITING\n" "$(get_valid)" "$(get_rejected)"
        fi
    else
        printf "$MSG_CLIENT_STOPPED\n"
        printf "$MSG_PROXY_INACTIVE\n"
    fi
    
    if auto_parallelism_enabled; then
        printf "$MSG_AUTO_PAR_ON" "$PARALLELISM_PERCENT"
    else
        printf "$MSG_AUTO_PAR_OFF"
    fi
    printf "\n\n"
    
    printf "%s\n\n" "$MAIN_MENU_ITEMS"
    printf "%b\n\n" "$MAIN_FOOTER"
    printf "%b" "$MAIN_PROMPT"
    printf '%s' "$INPUT_BUFFER"
}

#######################################
# 12. Main loop
#######################################

if [[ -f "$PARALLELISM_FILE" ]]; then
    PARALLELISM_PERCENT=$(cat "$PARALLELISM_FILE")
else
    PARALLELISM_PERCENT=10
fi
[[ "$PARALLELISM_PERCENT" =~ ^[0-9]+$ ]] || PARALLELISM_PERCENT=10
(( PARALLELISM_PERCENT < 1 )) && PARALLELISM_PERCENT=1
(( PARALLELISM_PERCENT > 100 )) && PARALLELISM_PERCENT=100

first_run_check

INPUT_BUFFER=""
REFRESH_RATE=4

while true; do
    draw_menu
    if read -rsn1 -t $REFRESH_RATE key 2>/dev/null; then
        if [[ "$key" == "" ]]; then
            choice="$INPUT_BUFFER"
            INPUT_BUFFER=""
            case "$choice" in
                1) start_client ;;
                2) stop_client ;;
                3) edit_config ;;
                4) edit_resolvers ;;
                5) show_log_view ;;
                6) profile_menu ;;
                7) start_mtu_speed_test ;;
                8) multi_connection_menu ;;
                9) start_resolver_health_check ;;
                10) settings_menu ;;
                11) clear; printf "Goodbye!\n"; exit 0 ;;
            esac
            read -t 0.1 -r -d '' 2>/dev/null || true
        elif [[ "$key" == $'\x7f' || "$key" == $'\b' ]]; then
            [[ -n "$INPUT_BUFFER" ]] && INPUT_BUFFER="${INPUT_BUFFER%?}"
        elif [[ "$key" =~ [0-9] ]]; then
            [[ ${#INPUT_BUFFER} -lt 2 ]] && INPUT_BUFFER+="$key"
        fi
    fi
done
