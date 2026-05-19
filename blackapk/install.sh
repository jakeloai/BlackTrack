#!/usr/bin/env bash
set -euo pipefail

echo "[+] BlackAPK Installer (stable edition)"

# -----------------------------
# 1. OS detection
# -----------------------------
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    echo "[+] Detected: ${PRETTY_NAME:-Unknown}"
fi

# -----------------------------
# 2. Update system
# -----------------------------
echo "[+] Updating package lists..."
sudo apt update -y

# -----------------------------
# 3. Core tools
# -----------------------------
echo "[+] Installing core dependencies..."

sudo apt install -y \
    unzip \
    curl \
    wget \
    file \
    binutils \
    coreutils \
    findutils \
    grep \
    gawk \
    sed \
    xxd

# -----------------------------
# 4. Recon tools
# -----------------------------
echo "[+] Installing recon tools..."

sudo apt install -y \
    ripgrep \
    apktool \
    jadx \
    default-jdk

# -----------------------------
# 5. Java fallback check
# -----------------------------
echo "[+] Checking Java..."

if ! command -v javac >/dev/null 2>&1; then
    if apt-cache search openjdk-17-jdk | grep -q openjdk-17-jdk; then
        sudo apt install -y openjdk-17-jdk
    elif apt-cache search openjdk-17-jdk-headless | grep -q headless; then
        sudo apt install -y openjdk-17-jdk-headless
    else
        sudo apt install -y default-jdk
    fi
fi

# -----------------------------
# 6. Tool verification
# -----------------------------
echo "[+] Verifying tools..."

for t in rg unzip apktool jadx java javac strings; do
    if command -v "$t" >/dev/null 2>&1; then
        echo "OK: $t"
    else
        echo "MISSING: $t"
    fi
done

# -----------------------------
# 7. Install blackapk command
# -----------------------------
echo "[+] Installing blackapk command..."

SCRIPT_PATH="$(pwd)/blackapk"

if [[ -f "$SCRIPT_PATH" ]]; then
    sudo cp "$SCRIPT_PATH" /usr/local/bin/blackapk
    sudo chmod +x /usr/local/bin/blackapk
    echo "[+] blackapk installed to /usr/local/bin"
else
    echo "[!] blackapk not found in current directory"
    echo "    Expected path: $SCRIPT_PATH"
    echo "    Skipping install"
fi

# -----------------------------
# 8. Create short alias (ba / ba.sh)
# -----------------------------
echo "[+] Creating aliases..."

sudo tee /usr/local/bin/ba >/dev/null <<'EOF'
#!/usr/bin/env bash
blackapk "$@"
EOF

sudo chmod +x /usr/local/bin/ba

sudo tee /usr/local/bin/ba.sh >/dev/null <<'EOF'
#!/usr/bin/env bash
blackapk "$@"
EOF

sudo chmod +x /usr/local/bin/ba.sh

# -----------------------------
# 9. Finish
# -----------------------------
echo "[+] Installation complete"
echo "[+] Usage:"
echo "    blackapk -t target.apk"
echo "    ba -t target.apk"
echo "    ba.sh -t target.apk"
