#!/bin/bash

# ==============================================================================
# Developer: JakeLo
# Tool Name: BlackTrack (bt)
# Version: 3.1 (Enterprise Bug Bounty Edition)
# Upgrades: Robust Error Handling, Temp Workspaces, Logging, UA Randomization
# Fixes: Global HTTPX_BIN detection, NBSP cleanup
# ==============================================================================

# Strict mode: Exit on error, trap pipe failures
set -e -o pipefail

# --- Configuration & Paths ---
DISCORD_WEBHOOK="" 
PERSISTENT_DIR="bt_workspace"
mkdir -p "$PERSISTENT_DIR"

YESTERDAY="$PERSISTENT_DIR/all_targets_yesterday.txt"
FINAL_VULNS="$PERSISTENT_DIR/nuclei_results_$(date +%Y%m%d_%H%M%S).txt"

# Temporary Workspace (Auto-cleaned on exit)
TMP_DIR=$(mktemp -d -t blacktrack_XXXXXX)
ALIVE_PROXIES="$TMP_DIR/alive_proxies.txt"

# Default values
RATE_LIMIT=15
CRON_MODE=false
FULL_SCAN=false
USE_PROXY=false
ROOT_FILE=""
SUB_FILE=""

# Proxy Sources
PROXY_SOURCES=(
    "https://raw.githubusercontent.com/monosans/proxy-list/main/proxies/http.txt"
    "https://raw.githubusercontent.com/TheSpeedX/SOCKS-List/master/http.txt"
    "https://raw.githubusercontent.com/proxifly/free-proxy-list/main/proxies/all/data.txt"
)

# Modern User-Agents for stealth
USER_AGENTS=(
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2.1 Safari/605.1.15"
    "Mozilla/5.0 (X11; Linux x86_64; rv:122.0) Gecko/20100101 Firefox/122.0"
)
RANDOM_UA=${USER_AGENTS[$RANDOM % ${#USER_AGENTS[@]}]}

# --- Global Binary Detection ---
# Ensure we use httpx-toolkit if installed via Kali APT, else fallback to httpx
if command -v httpx-toolkit &> /dev/null; then 
    HTTPX_BIN="httpx-toolkit"
elif command -v httpx &> /dev/null; then 
    HTTPX_BIN="httpx"
else
    HTTPX_BIN="httpx-toolkit" # default to toolkit for error messages
fi

# --- Core Functions ---

# Cleanup Function executed on exit
cleanup() {
    log_info "Cleaning up temporary workspace: $TMP_DIR"
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# Logging capabilities
log_info() { echo -e "\e[34m[$(date +'%H:%M:%S')] [*] $1\e[0m"; }
log_warn() { echo -e "\e[33m[$(date +'%H:%M:%S')] [!] $1\e[0m"; }
log_err()  { echo -e "\e[31m[$(date +'%H:%M:%S')] [ERROR] $1\e[0m"; >&2; exit 1; }
log_success() { echo -e "\e[32m[$(date +'%H:%M:%S')] [+] $1\e[0m"; }

# Tool Check Function
check_dependencies() {
    local tools=("subfinder" "$HTTPX_BIN" "katana" "nuclei" "curl")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            log_err "$tool is not installed or not in PATH."
        fi
    done
}

# Find Nuclei Templates
NUCLEI_TEMPLATES=$(nuclei -td 2>/dev/null || echo "$HOME/nuclei-templates")

# Help Menu
show_help() {
    echo "BlackTrack (bt) - Developed by JakeLo | Version 3.1"
    echo "=================================================="
    echo "Usage: ./bt.sh [options]"
    echo ""
    echo "Options:"
    echo "  -r <file>      Input root domains list"
    echo "  -s <file>      Input wildcard domains list"
    echo "  -rl <int>      Set global rate-limit (Default: 15)"
    echo "  -proxy         Enable Stealth Proxy Mode"
    echo "  -cj            Enable Cronjob mode (Delta monitoring)"
    echo "  -f             Force Full Scan (Ignore delta history)"
    echo "  -h, --help     Show this help menu"
    exit 0
}

# --- Module: Proxy Manager ---
update_proxies() {
    log_info "Initializing Stealth Proxy Module..."
    local raw_proxies="$TMP_DIR/raw_proxies.txt"
    touch "$raw_proxies" "$ALIVE_PROXIES"
    
    for src in "${PROXY_SOURCES[@]}"; do
        log_info "Fetching proxies from: $src"
        curl -s -m 10 "$src" >> "$raw_proxies" || true
    done

    log_info "Validating proxies (Max Latency: 800ms) using $HTTPX_BIN..."
    
    if [ ! -s "$raw_proxies" ]; then
        log_warn "Failed to fetch any raw proxies."
        USE_PROXY=false
        return
    fi

    # Fixed: Now using $HTTPX_BIN instead of hardcoded 'httpx'
    cat "$raw_proxies" | sort -u | $HTTPX_BIN -silent -proxy-file stdin -u https://www.google.com -timeout 2 -p 80,443 -o "$ALIVE_PROXIES" > /dev/null 2>&1 || true
    
    local count=0
    if [ -s "$ALIVE_PROXIES" ]; then
        count=$(wc -l < "$ALIVE_PROXIES")
    fi

    if [ "$count" -eq 0 ]; then
        log_warn "No usable proxies found. Proceeding without proxy."
        USE_PROXY=false
    else
        log_success "Proxy Pool Ready: $count active proxies."
    fi
}

# --- Module: Adaptive Intelligence ---
detect_waf_and_adjust() {
    local target=$1
    log_info "Analyzing target security posture: $target"
    
    local headers
    headers=$(curl -s -I -L -H "User-Agent: $RANDOM_UA" --max-time 5 "$target" 2>/dev/null || true)
    local waf_brand
    waf_brand=$(echo "$headers" | grep -Ei "server: cloudflare|server: akamai|cf-ray|x-waf|sucuri|incapsula" | head -n 1 || echo "None")

    if [[ "$waf_brand" != "None" ]]; then
        log_warn "WAF Detected: $(echo "$waf_brand" | tr -d '\r')"
        log_warn "Switching to STEALTH MODE (Low frequency, High jitter)"
        ADAPTIVE_RL=2
        ADAPTIVE_CONC=2
        ADAPTIVE_JITTER=5
    else
        log_success "No obvious WAF detected. Proceeding with AGGRESSIVE MODE."
        ADAPTIVE_RL=$RATE_LIMIT
        ADAPTIVE_CONC=15
        ADAPTIVE_JITTER=0
    fi
}

# --- Argument Parsing ---
if [[ "$#" -eq 0 ]]; then show_help; fi

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -r) ROOT_FILE="$2"; shift ;;
        -s) SUB_FILE="$2"; shift ;;
        -rl) RATE_LIMIT="$2"; shift ;;
        -proxy) USE_PROXY=true ;;
        -cj) CRON_MODE=true ;;
        -f) FULL_SCAN=true ;;
        -h|--help) show_help ;;
        *) log_err "Unknown parameter: $1\nRun with -h for help." ;;
    esac
    shift
done

# Validate inputs
if [[ -n "$ROOT_FILE" && ! -f "$ROOT_FILE" ]]; then log_err "Root file '$ROOT_FILE' not found."; fi
if [[ -n "$SUB_FILE" && ! -f "$SUB_FILE" ]]; then log_err "Subdomain file '$SUB_FILE' not found."; fi
if [[ -z "$ROOT_FILE" && -z "$SUB_FILE" ]]; then log_err "You must provide -r or -s. Use -h for help."; fi

check_dependencies

log_success "MISSION START: BlackTrack Operational"

# --- Phase 0: Stealth Setup ---
PROXY_FLAG=""
if [ "$USE_PROXY" = true ]; then
    update_proxies
    if [ -f "$ALIVE_PROXIES" ] && [ -s "$ALIVE_PROXIES" ]; then
        PROXY_FLAG="-proxy-file $ALIVE_PROXIES"
    fi
fi

# --- Phase 1: Subdomain Enumeration ---
SUB_RESULT="$TMP_DIR/subfinder_raw.txt"
touch "$SUB_RESULT"

if [[ -n "$SUB_FILE" ]]; then
    log_info "Phase 1: Running Subfinder..."
    subfinder -dL "$SUB_FILE" -all -recursive -rl "$RATE_LIMIT" -silent -o "$SUB_RESULT" > /dev/null 2>&1 || true
fi

# --- Phase 2: Asset Consolidation & Alive Check ---
ALL_TARGETS="$TMP_DIR/all_targets_raw.txt"
ALIVE_TARGETS="$TMP_DIR/alive_targets.txt"

cat "$ROOT_FILE" "$SUB_FILE" "$SUB_RESULT" 2>/dev/null | sort -u > "$ALL_TARGETS" || true

if [ ! -s "$ALL_TARGETS" ]; then
    log_err "No targets loaded. Check your input files."
fi

log_info "Phase 2: Verifying alive assets with $HTTPX_BIN..."

# Fixed: Using the globally detected $HTTPX_BIN
$HTTPX_BIN -l "$ALL_TARGETS" -silent -rl "$RATE_LIMIT" -H "User-Agent: $RANDOM_UA" $PROXY_FLAG -o "$ALIVE_TARGETS" > /dev/null 2>&1 || true

if [ ! -s "$ALIVE_TARGETS" ]; then
    log_err "Critical Error: No alive targets found after probing."
fi

# --- Phase 3: Adaptive Intelligence Execution ---
SAMPLE_TARGET=$(head -n 1 "$ALIVE_TARGETS")
detect_waf_and_adjust "$SAMPLE_TARGET"

# --- Phase 4: Delta Monitoring (Cron Mode) ---
SCAN_TARGET="$ALIVE_TARGETS"
if [ "$CRON_MODE" = true ] && [ "$FULL_SCAN" = false ]; then
    if [ -f "$YESTERDAY" ]; then
        log_info "Phase 4: Delta Monitoring active. Identifying new attack surface..."
        NEW_ASSETS="$TMP_DIR/new_assets.txt"
        comm -13 <(sort "$YESTERDAY") <(sort "$ALIVE_TARGETS") > "$NEW_ASSETS"
        
        if [ -s "$NEW_ASSETS" ]; then
            log_warn "Discovery: New assets detected. Scanning newly discovered surface."
            SCAN_TARGET="$NEW_ASSETS"
        else
            log_success "Intelligence: No new surface found. Task complete."
            cp "$ALIVE_TARGETS" "$YESTERDAY"
            exit 0
        fi
    fi
fi

# --- Phase 5: Deep Crawling (Katana) ---
log_info "Phase 5: Executing Adaptive Crawler (RL: $ADAPTIVE_RL)..."
KATANA_RAW="$TMP_DIR/katana_raw.txt"
KATANA_FILTERED="$TMP_DIR/katana_filtered.txt"

katana -list "$SCAN_TARGET" -resume -d 5 -js-crawl -jsluice -kf all -path-climb -hh -system-chrome -nos -xhr -rl "$ADAPTIVE_RL" -fs rdn -tlsi -H "User-Agent: $RANDOM_UA" $PROXY_FLAG -o "$KATANA_RAW" -silent > /dev/null 2>&1 || true

if [ -s "$KATANA_RAW" ]; then
    grep -aEi -v "\.(png|jpg|jpeg|gif|svg|ico|css|woff|woff2|ttf|otf|mp4|txt|pdf|js)$" "$KATANA_RAW" | sort -u > "$KATANA_FILTERED" || true
else
    cp "$SCAN_TARGET" "$KATANA_FILTERED"
fi

if [ ! -s "$KATANA_FILTERED" ]; then
    log_err "No actionable URLs generated after crawling."
fi

# --- Phase 6: Adaptive Vulnerability Scanning (Nuclei) ---
log_info "Phase 6: Launching Nuclei Engine..."
NUCLEI_OUTPUT="$TMP_DIR/nuclei_results_tmp.txt"

nuclei -up -silent > /dev/null 2>&1 || true

nuclei -list "$KATANA_FILTERED" \
  -t "$NUCLEI_TEMPLATES" \
  -dast -fa medium \
  -s critical,high,medium \
  -silent \
  -rl "$ADAPTIVE_RL" \
  -c "$ADAPTIVE_CONC" \
  -H "User-Agent: $RANDOM_UA" \
  $PROXY_FLAG \
  -o "$NUCLEI_OUTPUT" > /dev/null 2>&1 || true

# --- Phase 7: Reporting & Archiving ---
log_info "Phase 7: Archiving target history..."
cp "$ALIVE_TARGETS" "$YESTERDAY"

if [ -f "$NUCLEI_OUTPUT" ] && [ -s "$NUCLEI_OUTPUT" ]; then
    log_warn "ALERT: Vulnerabilities discovered!"
    
    cp "$NUCLEI_OUTPUT" "$FINAL_VULNS"
    log_success "Results saved to: $FINAL_VULNS"
    
    cat "$FINAL_VULNS"
    
    if [ -n "$DISCORD_WEBHOOK" ]; then
        log_info "Dispatching Discord notification..."
        VULN_COUNT=$(wc -l < "$FINAL_VULNS")
        MSG=" **[BlackTrack] Scan Completed**\nTarget: \`$ROOT_FILE $SUB_FILE\`\nVulns Found: **$VULN_COUNT**\nDate: \`$(date)\`\nMode: $( [ "$CRON_MODE" = true ] && echo "Cron/Delta" || echo "Full Scan" )"
        curl -s -H "Content-Type: application/json" -X POST -d "{\"content\": \"$MSG\"}" "$DISCORD_WEBHOOK" > /dev/null || true
    fi
else
    log_success "Scan finished. Surface clean."
fi

log_success "MISSION ACCOMPLISHED."
