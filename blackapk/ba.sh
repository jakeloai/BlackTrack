#!/usr/bin/env bash
set -Eeuo pipefail
shopt -s nullglob

usage() {
  cat <<'EOF'
Usage:
  ba.sh -t target.apk [-o output_dir]

Options:
  -t, --target   APK file to analyze
  -o, --out      Output directory (optional)
  -h, --help     Show help

Notes:
  - Uses rg if available, otherwise falls back to grep.
  - Uses apktool/jadx if installed, otherwise continues with unzip + strings only.
EOF
}

have() { command -v "$1" >/dev/null 2>&1; }

TARGET=""
OUTDIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -t|--target)
      TARGET="${2:-}"
      shift 2
      ;;
    -o|--out)
      OUTDIR="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[!] Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ -z "${TARGET}" ]]; then
  usage
  exit 1
fi

if [[ ! -f "$TARGET" ]]; then
  echo "[!] File not found: $TARGET"
  exit 1
fi

TS="$(date +%Y%m%d_%H%M%S)"
BASE="${OUTDIR:-apk_recon_${TS}}"
UNZIPPED="$BASE/unzipped"
APKTOOL_DIR="$BASE/apktool"
JADX_DIR="$BASE/jadx"
FINDINGS="$BASE/findings"
META="$BASE/meta"
LOG="$BASE/recon.log"

mkdir -p "$UNZIPPED" "$FINDINGS" "$META"

exec > >(tee -a "$LOG") 2>&1

echo "[+] Target: $TARGET"
echo "[+] Output: $BASE"

cp -f "$TARGET" "$BASE/original.apk"

if have sha256sum; then
  sha256sum "$TARGET" | tee "$META/sha256.txt"
fi

if have file; then
  file "$TARGET" | tee "$META/filetype.txt"
fi

if have stat; then
  stat "$TARGET" | tee "$META/stat.txt" || true
fi

echo "[+] Unzipping APK..."
unzip -q -o "$TARGET" -d "$UNZIPPED" || {
  echo "[!] unzip failed"
  exit 1
}

echo "[+] Collecting basic file inventory..."
find "$UNZIPPED" -type f | sed "s#^$UNZIPPED/##" | sort > "$META/file_inventory.txt"

echo "[+] Extracting strings from APK..."
strings -a -n 4 "$TARGET" > "$FINDINGS/strings_apk.txt" || true

echo "[+] Extracting strings from unpacked files..."
: > "$FINDINGS/strings_unpacked.txt"
while IFS= read -r -d '' f; do
  strings -a -n 4 "$f" >> "$FINDINGS/strings_unpacked.txt" 2>/dev/null || true
done < <(find "$UNZIPPED" -type f -print0)
sort -u "$FINDINGS/strings_unpacked.txt" -o "$FINDINGS/strings_unpacked.txt" 2>/dev/null || true

if have apktool; then
  echo "[+] Running apktool decode..."
  apktool d -f -q "$TARGET" -o "$APKTOOL_DIR" || true
fi

if have jadx; then
  echo "[+] Running jadx decompile..."
  jadx -d "$JADX_DIR" "$TARGET" >/dev/null 2>&1 || true
fi

SCAN_ROOTS=()
[[ -d "$UNZIPPED" ]] && SCAN_ROOTS+=("$UNZIPPED")
[[ -d "$APKTOOL_DIR" ]] && SCAN_ROOTS+=("$APKTOOL_DIR")
[[ -d "$JADX_DIR" ]] && SCAN_ROOTS+=("$JADX_DIR")

scan_rg() {
  local name="$1"
  local pattern="$2"
  local out="$FINDINGS/$name.txt"
  : > "$out"

  if have rg; then
    for root in "${SCAN_ROOTS[@]}"; do
      rg -n -H -I -a --no-heading -o "$pattern" "$root" >> "$out" 2>/dev/null || true
    done
  else
    for root in "${SCAN_ROOTS[@]}"; do
      grep -RInaE "$pattern" "$root" >> "$out" 2>/dev/null || true
    done
  fi

  sort -u "$out" -o "$out" 2>/dev/null || true
  echo "[+] $name: $(wc -l < "$out" 2>/dev/null || echo 0)"
}

scan_grep() {
  local name="$1"
  local pattern="$2"
  local out="$FINDINGS/$name.txt"
  : > "$out"

  for root in "${SCAN_ROOTS[@]}"; do
    grep -RInaE "$pattern" "$root" >> "$out" 2>/dev/null || true
  done

  sort -u "$out" -o "$out" 2>/dev/null || true
  echo "[+] $name: $(wc -l < "$out" 2>/dev/null || echo 0)"
}

echo "[+] Hunting common recon artifacts..."

scan_rg "urls" 'https?://[[:alnum:]./_%?=&:+@~-]+' 
scan_rg "ws_urls" 'wss?://[[:alnum:]./_%?=&:+@~-]+'
scan_rg "emails" '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
scan_rg "ipv4s" '([0-9]{1,3}\.){3}[0-9]{1,3}'
scan_rg "domains" '([A-Za-z0-9-]+\.)+[A-Za-z]{2,}'
scan_rg "urls_and_hosts" '(https?://|wss?://|[A-Za-z0-9-]+\.)[A-Za-z0-9._%/-]+'

echo "[+] Hunting keys / tokens / secrets..."
scan_rg "secret_keywords" '(api[_-]?key|apikey|secret|token|bearer|authorization|client[_-]?secret|client[_-]?id|passwd|password|pwd|private[_-]?key|session|cookie|auth)'
scan_rg "aws_keys" 'AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}'
scan_rg "github_tokens" 'gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]+'
scan_rg "slack_tokens" 'xox[baprs]-[A-Za-z0-9-]+'
scan_rg "stripe_keys" 'sk_(live|test)_[A-Za-z0-9]+'
scan_rg "google_api_keys" 'AIza[0-9A-Za-z_-]{35}'
scan_rg "jwt_like" 'eyJ[a-zA-Z0-9_-]+\.[a-zA-Z0-9._-]+\.[a-zA-Z0-9._-]+'
scan_rg "private_keys" '-----BEGIN (EC|RSA|OPENSSH|DSA|PRIVATE) KEY-----'

echo "[+] Hunting Android attack surface..."
scan_grep "android_exported" 'android:exported="true"'
scan_grep "android_debuggable" 'android:debuggable="true"'
scan_grep "android_cleartext" 'usesCleartextTraffic="true"|android:usesCleartextTraffic="true"'
scan_grep "android_backup" 'allowBackup="true"|android:allowBackup="true"'
scan_grep "android_network_security_config" 'networkSecurityConfig|android:networkSecurityConfig'
scan_grep "android_providers" '<provider |android:authorities=|content://'
scan_grep "android_services" '<service |android:permission=|android:process='
scan_grep "android_receivers" '<receiver |intent-filter'
scan_grep "android_permissions" 'android.permission.|uses-permission'
scan_grep "android_schemes" 'android:scheme=|intent-filter|deep link|deeplink|app link'
scan_grep "android_endpoints" 'baseUrl|baseURL|endpoint|apiUrl|api_url|serverUrl|server_url|host=|hostname='

echo "[+] Hunting common backend / cloud / infra strings..."
scan_rg "firebase" 'firebase|google-services\.json|FIREBASE_|FIREBASE|firebaseio\.com'
scan_rg "oauth" 'oauth|client_secret|client_id|redirect_uri|grant_type|refresh_token|access_token'
scan_rg "s3" 's3\.amazonaws\.com|amazonaws\.com|bucket|cloudfront\.net'
scan_rg "microsoft" 'login\.microsoftonline\.com|graph\.microsoft\.com|oauth2|AAD|Active Directory'
scan_rg "webhooks" 'webhook|slack.com/api|discord.com/api|hooks\.'
scan_rg "databases" 'mysql|mariadb|postgres|postgresql|mongodb|redis|cassandra|elasticsearch|kafka|rabbitmq'
scan_rg "vpn_rdp_admin" 'winrm|rdp|vnc|ssh|telnet|ldap|kerberos|smb|mssql|oracle'
scan_rg "docker_k8s" 'docker|kubernetes|k8s|kubectl|helm|containerd|registry'
scan_rg "analytics" 'mixpanel|amplitude|segment|appsflyer|adjust|branch\.io|firebaseanalytics'
scan_rg "push_notifications" 'fcm|push|notification|onesignal'
scan_rg "payment" 'stripe|paypal|checkout|merchant|billing|invoice'
scan_rg "contact_info" 'support@|contact@|help@|sales@|admin@|privacy@|hello@'

echo "[+] Hunting common config / code leakage..."
scan_rg "hardcoded_paths" '/sdcard/|/data/data/|/system/bin/|/proc/|/tmp/|/var/'
scan_rg "interesting_terms" 'password|secret|token|key|apikey|auth|session|cookie|credential|login|backup|debug|staging|dev|test|prod|production'
scan_rg "full_url_candidates" 'https?://[^[:space:]"'\''<>]+'
scan_rg "host_candidates" '[A-Za-z0-9.-]+\.[A-Za-z]{2,}(:[0-9]{2,5})?'

echo "[+] Building concise summary..."
SUMMARY="$BASE/summary.txt"
{
  echo "APK Recon Summary"
  echo "================="
  echo
  echo "Target: $TARGET"
  echo "Output: $BASE"
  echo

  for f in "$FINDINGS"/*.txt; do
    [[ -f "$f" ]] || continue
    n="$(wc -l < "$f" 2>/dev/null || echo 0)"
    printf "%-24s %s\n" "$(basename "$f" .txt):" "$n"
  done
} > "$SUMMARY"

echo
echo "[+] Done."
echo "[+] Summary: $SUMMARY"
echo "[+] Findings dir: $FINDINGS"
echo "[+] If apktool/jadx were present, check: $APKTOOL_DIR and $JADX_DIR"
