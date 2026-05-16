#!/bin/bash

# Developer: JakeLo
# BlackTrack (bt) Installer & Auto-Dependency Setup
# Target: Windows 11 WSL2 (Kali Linux)

# --- 1. Root Check ---
if [[ $EUID -ne 0 ]]; then
   echo "[!] Error: This script must be run as root (use sudo)." 
   exit 1
fi

echo "[*] BlackTrack (bt) Environment Setup started..."

# --- 2. System Updates & Essential Libraries ---
echo "[*] Updating apt repositories and installing essentials..."
apt update
apt install -y golang-go bc curl grep coreutils

# --- 3. Setup Go Path environment for Real User ---
REAL_USER=$SUDO_USER
USER_HOME=$(eval echo "~$REAL_USER")
GO_BIN="$USER_HOME/go/bin"

# Ensure Go bin directory exists
sudo -u "$REAL_USER" mkdir -p "$GO_BIN"

# Update .bashrc if path is missing
if ! grep -q "export PATH=\$PATH:\$HOME/go/bin" "$USER_HOME/.bashrc"; then
    echo "[*] Adding $GO_BIN to $REAL_USER's PATH..."
    echo 'export PATH=$PATH:$HOME/go/bin' >> "$USER_HOME/.bashrc"
fi

# Export for current installer session
export PATH=$PATH:$GO_BIN

# --- 4. Tool Installation Function ---
install_go_tool() {
    local name=$1
    local path=$2
    if ! command -v "$name" &> /dev/null; then
        echo "[*] $name not found. Installing via Go..."
        sudo -u "$REAL_USER" go install -v "$path"
    else
        echo "[+] $name is already installed. Attempting update..."
        # ProjectDiscovery tools often support -up flag
        sudo -u "$REAL_USER" "$name" -up 2>/dev/null || sudo -u "$REAL_USER" go install -v "$path"
    fi
}

# --- 5. Install Dependencies ---

# APT Based Tools
echo "[*] Installing httpx-toolkit via APT..."
apt install -y httpx-toolkit

# Go Based Tools (ProjectDiscovery Stack)
install_go_tool "nuclei" "github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest"
install_go_tool "subfinder" "github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
install_go_tool "katana" "github.com/projectdiscovery/katana/cmd/katana@latest"

# --- 6. Verification of critical tools for Adaptive Scan ---
echo "[*] Verifying critical components for BlackTrack..."
for tool in nuclei subfinder katana httpx-toolkit bc curl; do
    if ! command -v "$tool" &> /dev/null; then
        echo "[!] Warning: $tool is not found in PATH."
    fi
done

# --- 7. Finalizing bt.sh ---
if [ ! -f "bt.sh" ]; then
    echo "[!] Error: bt.sh not found in $(pwd). Please place bt.sh and install.sh in the same folder."
    exit 1
fi

chmod +x bt.sh
echo "[*] Mapping BlackTrack to /usr/local/bin/bt..."
ln -sf "$(pwd)/bt.sh" /usr/local/bin/bt

echo "=================================================="
echo "[+] BlackTrack (bt) Installation Complete!"
echo "[+] Adaptive Engine & Proxy Module dependencies ready."
echo "[+] IMPORTANT: Run 'source ~/.bashrc' to refresh your PATH."
echo "[+] Usage: sudo bt -r targets.txt -proxy"
echo "=================================================="
