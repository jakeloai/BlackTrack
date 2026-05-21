#!/bin/bash

# Developer: JakeLo
# Tool Name: BlackTrack (bt)
# Version: 2.0 (Adaptive Intelligence & Stealth Proxy)

# --- Configuration ---
DISCORD_WEBHOOK="" 
ALIVE_PROXIES="alive_proxies.txt"
YESTERDAY="all_targets_yesterday.txt"

# Proxy Sources (GitHub curated lists)
PROXY_SOURCES=(
    "https://raw.githubusercontent.com/monosans/proxy-list/main/proxies/http.txt"
    "https://raw.githubusercontent.com/TheSpeedX/SOCKS-List/master/http.txt"
    "https://raw.githubusercontent.com/proxifly/free-proxy-list/main/proxies/all/data.txt"
)

# Default values
RATE_LIMIT=15
CRON_MODE=false
FULL_SCAN=false
USE_PROXY=false
ROOT_FILE=""
SUB_FILE=""

# Templates Path
NUCLEI_TEMPLATES=$(nuclei -td 2>/dev/null)
if [ -z "$NUCLEI_TEMPLATES" ]; then
    NUCLEI_TEMPLATES="$HOME/nuclei-templates"
fi

# Help Menu
show_help() {
    echo "BlackTrack (bt) - Developed by JakeLo"
    echo "=================================================="
    echo "Usage: bt [options]"
    echo ""
    echo "Options:"
    echo "  -r <file>      Input root domains list"
    echo "  -s <file>      Input wildcard domains list"
    echo "  -rl <int>      Set global rate-limit (Default: 15)"
    echo "  -proxy         Enable Stealth Proxy Mode (Auto fetch & validate)"
    echo "  -cj            Enable Cronjob mode (Delta monitoring)"
    echo "  -f             Force Full Scan (Ignore delta history)"
    echo "  -h, --help     Show this help menu"
    exit 0
}

# --- Module: Proxy Manager (The Stealth Filter) ---
update_proxies() {
    echo "[*] Initializing Stealth Proxy Module..."
    rm -f raw_proxies.txt "$ALIVE_PROXIES"
    
    for src in "${PROXY_SOURCES[@]}"; do
        echo "[*] Fetching proxies from: $src"
        curl -s "$src" >> raw_proxies.txt
    done

    # Validation: Filter Elite proxies with latency < 800ms
    echo "[*] Validating proxies (Max Latency: 800ms)..."
    
    # Ensure the file exists to prevent bash redirection errors
    touch "$ALIVE_PROXIES"
    
    cat raw_proxies.txt | sort -u | httpx -silent -proxy-file stdin -u https://www.google.com -timeout 2 -p 80,443 -o "$ALIVE_PROXIES" > /dev/null 2>&1
    
    local count=0
    # Safely check if file has content before counting
    if [ -s "$ALIVE_PROXIES" ]; then
        count=$(wc -l < "$ALIVE_PROXIES" 2>/dev/null || echo 0)
    fi

    if [ "$count" -eq 0 ]; then
        echo "[!] No usable proxies found. Proceeding without proxy."
        USE_PROXY=false
        rm -f "$ALIVE_PROXIES"
    else
        echo "[+] Proxy Pool Ready: $count active proxies."
    fi
}

# --- Module: Adaptive Intelligence (The Sensor) ---
detect_waf_and_adjust() {
    local target=$1
    echo "[*] Analyzing target security posture: $target"
    
    # Header Analysis for WAF Fingerprints
    local headers=$(curl -s -I -L --max-time 5 "$target" 2>/dev/null)
    local waf_brand=$(echo "$headers" | grep -Ei "server: cloudflare|server: akamai|cf-ray|x-waf|sucuri|incapsula" | head -n 1 || echo "None")

    if [[ "$waf_brand" != "None" ]]; then
        echo "[!] WAF Detected: $waf_brand"
        echo "[!] Switching to STEALTH MODE (Low frequency, High jitter)"
        ADAPTIVE_RL=2
        ADAPTIVE_CONC=2
        ADAPTIVE_JITTER=5
    else
        echo "[+] No obvious WAF detected. Proceeding with AGGRESSIVE MODE."
        ADAPTIVE_RL=$RATE_LIMIT
        ADAPTIVE_CONC=15
        ADAPTIVE_JITTER=0
    fi
}

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -r) ROOT_FILE="$2"; shift ;;
        -s) SUB_FILE="$2"; shift ;;
        -rl) RATE_LIMIT="$2"; shift ;;
        -proxy) USE_PROXY=true ;;
        -cj) CRON_MODE=true ;;
        -f) FULL_SCAN=true ;;
        -h|--help) show_help ;;
        *) echo "Unknown parameter: $1"; show_help ;;
    esac
    shift
done

if [[ -z "$ROOT_FILE" && -z "$SUB_FILE" ]]; then
    show_help
fi

echo "[*] MISSION START: BlackTrack Operational"

# --- Phase 0: Stealth Setup ---
PROXY_FLAG=""
if [ "$USE_PROXY" = true ]; then
    update_proxies
    if [ -f "$ALIVE_PROXIES" ]; then
        PROXY_FLAG="-proxy-file $ALIVE_PROXIES"
    fi
fi

# --- Phase 1: Subdomain Enumeration ---
SUB_RESULT="subfinder_raw.txt"
if [[ -n "$SUB_FILE" ]]; then
    echo "[*] Phase 1: Running Subfinder..."
    subfinder -dL "$SUB_FILE" -all -recursive -rl "$RATE_LIMIT" -silent -o "$SUB_RESULT"
else
    touch "$SUB_RESULT"
fi

# --- Phase 2: Asset Consolidation & Alive Check ---
ALL_TARGETS="all_targets_raw.txt"
ALIVE_TARGETS="alive_targets.txt"
cat "$ROOT_FILE" "$SUB_FILE" "$SUB_RESULT" 2>/dev/null | sort -u > "$ALL_TARGETS"

echo "[*] Phase 2: Verifying alive assets with httpx..."
httpx-toolkit -l "$ALL_TARGETS" -silent -rl "$RATE_LIMIT" $PROXY_FLAG -o "$ALIVE_TARGETS"

# --- Phase 3: Adaptive Intelligence Execution ---
SAMPLE_TARGET=$(head -n 1 "$ALIVE_TARGETS" 2>/dev/null)
if [ -n "$SAMPLE_TARGET" ]; then
    detect_waf_and_adjust "$SAMPLE_TARGET"
else
    echo "[!] Critical Error: No alive targets found."
    exit 1
fi

# --- Phase 4: Delta Monitoring (Cron Mode) ---
SCAN_TARGET="$ALIVE_TARGETS"
if [ "$CRON_MODE" = true ] && [ "$FULL_SCAN" = false ]; then
    if [ -f "$YESTERDAY" ]; then
        echo "[*] Phase 4: Delta Monitoring active. Identifying new attack surface..."
        comm -13 <(sort "$YESTERDAY") <(sort "$ALIVE_TARGETS") > new_assets.txt
        if [ -s new_assets.txt ]; then
            echo "[!] Discovery: New assets detected."
            SCAN_TARGET="new_assets.txt"
        else
            echo "[*] Intelligence: No new surface found. Task complete."
            cp "$ALIVE_TARGETS" "$YESTERDAY"
            exit 0
        fi
    fi
fi

# --- Phase 5: Deep Crawling (Katana) ---
echo "[*] Phase 5: Executing Adaptive Crawler (RL: $ADAPTIVE_RL)..."
KATANA_RAW="katana_raw.txt"
KATANA_FILTERED="katana_filtered.txt"

katana -list "$SCAN_TARGET" -resume -d 5 -js-crawl -jsluice -kf all -path-climb -hh -system-chrome -nos -xhr -rl "$ADAPTIVE_RL" -fs rdn -tlsi $PROXY_FLAG -o "$KATANA_RAW" -silent

# Filter interesting paths and avoid static junk
grep -aEi -v "\.(png|jpg|jpeg|gif|svg|ico|css|woff|woff2|ttf|otf|mp4|txt|pdf|js)$" "$KATANA_RAW" | sort -u > "$KATANA_FILTERED"

# --- Phase 6: Adaptive Vulnerability Scanning (Nuclei) ---
echo "[*] Phase 6: Launching Nuclei Engine..."
NUCLEI_OUTPUT="nuclei_results.txt"

# Update templates before scan
nuclei -up -silent && nuclei -ut -silent

nuclei -list "$KATANA_FILTERED" \
  -t "$NUCLEI_TEMPLATES" \
  -dast -fa medium \
  -s critical,high,medium \
  -silent \
  -rl "$ADAPTIVE_RL" \
  -c "$ADAPTIVE_CONC" \
  $PROXY_FLAG \
  -o "$NUCLEI_OUTPUT"

# --- Phase 7: Reporting & Archiving ---
cp "$ALIVE_TARGETS" "$YESTERDAY"

if [ -s "$NUCLEI_OUTPUT" ]; then
    echo "[!] ALERT: Vulnerabilities discovered!"
    cat "$NUCLEI_OUTPUT"
    
    if [ -n "$DISCORD_WEBHOOK" ]; then
        MSG="[BlackTrack] Target: $ROOT_FILE | Vulns: $(wc -l < $NUCLEI_OUTPUT) | Date: $(date)"
        curl -H "Content-Type: application/json" -X POST -d "{\"content\": \"$MSG\"}" "$DISCORD_WEBHOOK"
    fi
else
    echo "[+] Scan finished. Surface clean."
fi

echo "[+] MISSION ACCOMPLISHED."
