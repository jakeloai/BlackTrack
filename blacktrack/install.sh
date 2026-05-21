#!/bin/bash

# ==============================================================================
# Developer: JakeLo
# BlackTrack (bt) Installer & Auto-Dependency Setup
# Target: Windows 11 WSL2 (Kali Linux) / Ubuntu
# ==============================================================================

set -e

# --- Logging Functions ---
log_info()    { echo -e "\e[34m[*]\e[0m $1"; }
log_success() { echo -e "\e[32m[+]\e[0m $1"; }
log_warn()    { echo -e "\e[33m[!]\e[0m $1"; }
log_err()     { echo -e "\e[31m[ERROR]\e[0m $1"; exit 1; }

# --- 1. Root Check ---
if [[ $EUID -ne 0 ]]; then
    log_err "This script must be run as root. Please use 'sudo ./install.sh'."
fi

log_info "BlackTrack (bt) Environment Setup started..."

# --- 2. System Updates & Essential Libraries ---
log_info "Updating apt repositories and installing essentials..."
apt-get update -y
apt-get install -y golang-go bc curl grep coreutils unzip jq git

# Install httpx-toolkit via APT as requested
log_info "Installing httpx-toolkit via APT..."
apt-get install -y httpx-toolkit

# --- 3. Setup User Environment ---
REAL_USER=${SUDO_USER:-$(whoami)}
USER_HOME=$(eval echo "~$REAL_USER")
GO_BIN="$USER_HOME/go/bin"

log_info "Configuring environment for user: $REAL_USER"
sudo -u "$REAL_USER" mkdir -p "$GO_BIN"

for rc_file in "$USER_HOME/.bashrc" "$USER_HOME/.zshrc"; do
    if [ -f "$rc_file" ] && ! grep -q "export PATH=\$PATH:\$HOME/go/bin" "$rc_file"; then
        echo 'export PATH=$PATH:$HOME/go/bin' >> "$rc_file"
        log_info "Added Go binary path to $rc_file"
    fi
done

export PATH=$PATH:$GO_BIN

# --- 4. Tool Installation Function ---
install_go_tool() {
    local name=$1
    local repo_path=$2

    if ! sudo -u "$REAL_USER" command -v "$name" &> /dev/null; then
        log_info "Installing $name via Go..."
        sudo -u "$REAL_USER" env GOPATH="$USER_HOME/go" go install -v "$repo_path"
    else
        log_info "$name is already installed. Attempting update..."
        sudo -u "$REAL_USER" "$name" -up 2>/dev/null || sudo -u "$REAL_USER" env GOPATH="$USER_HOME/go" go install -v "$repo_path"
    fi
}

# --- 5. Install ProjectDiscovery Stack (Excluding HTTPX) ---
install_go_tool "nuclei" "github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest"
install_go_tool "subfinder" "github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
install_go_tool "katana" "github.com/projectdiscovery/katana/cmd/katana@latest"

# --- 6. Global Symlink Fix for Sudo Execution ---
log_info "Creating global symlinks for Go binaries..."
for bin in "$GO_BIN"/*; do
    if [ -f "$bin" ]; then
        ln -sf "$bin" "/usr/local/bin/$(basename "$bin")"
    fi
done

# --- 7. Initializing Nuclei Templates ---
log_info "Downloading latest Nuclei templates..."
sudo -u "$REAL_USER" nuclei -ut -silent || log_warn "Failed to update templates. Run 'nuclei -ut' manually later."

# --- 8. Finalizing bt.sh ---
if [ ! -f "bt.sh" ]; then
    log_err "bt.sh not found in $(pwd). Please place bt.sh and install.sh in the same directory."
fi

log_info "Mapping BlackTrack executable..."
chmod +x bt.sh
ln -sf "$(pwd)/bt.sh" /usr/local/bin/bt

echo "=================================================="
log_success "BlackTrack (bt) Installation Complete!"
log_success "All dependencies are ready (httpx-toolkit via APT)."
log_info "IMPORTANT: Run 'source ~/.bashrc' or restart your terminal to refresh PATH."
log_info "Usage: sudo bt -r targets.txt -proxy"
echo "=================================================="
