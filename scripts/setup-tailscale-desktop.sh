#!/bin/bash
#
# Tailscale Desktop Setup Script
# macOS/Linux デスクトップ用
#

set -e

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

clear
echo "=========================================="
echo "  Tailscale Desktop Setup"
echo "=========================================="
echo ""

# OS検出
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
    echo_info "Detected: macOS"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
    echo_info "Detected: Linux"
else
    echo_error "Unsupported OS: $OSTYPE"
    exit 1
fi

# Tailscaleインストール済みチェック
if command -v tailscale &> /dev/null; then
    echo_info "Tailscale is already installed"
    TAILSCALE_VERSION=$(tailscale version | head -n1)
    echo_info "Version: $TAILSCALE_VERSION"

    echo ""
    echo "What would you like to do?"
    echo "1) Update Tailscale"
    echo "2) Reconfigure"
    echo "3) Show status"
    echo "4) Exit"
    read -p "Select [1-4]: " choice

    case $choice in
        1)
            echo_step "Updating Tailscale..."
            ;;
        2)
            echo_step "Reconfiguring..."
            tailscale down
            tailscale up
            exit 0
            ;;
        3)
            tailscale status
            exit 0
            ;;
        4)
            exit 0
            ;;
        *)
            echo_error "Invalid choice"
            exit 1
            ;;
    esac
fi

# インストール開始
echo ""
echo_step "Step 1/3: Installing Tailscale..."

if [ "$OS" = "macos" ]; then
    # macOS: Homebrewでインストール
    if ! command -v brew &> /dev/null; then
        echo_error "Homebrew is not installed"
        echo "Install Homebrew first: https://brew.sh"
        exit 1
    fi

    echo_info "Installing via Homebrew..."
    brew install --cask tailscale

    echo_info "Opening Tailscale app..."
    open -a Tailscale

elif [ "$OS" = "linux" ]; then
    # Linux: 公式スクリプトでインストール
    echo_info "Installing via official script..."
    curl -fsSL https://tailscale.com/install.sh | sh
fi

# Tailscale起動待ち
echo ""
echo_step "Step 2/3: Starting Tailscale..."
sleep 3

# macOSの場合はGUIから認証
if [ "$OS" = "macos" ]; then
    echo_info "Please authenticate via Tailscale app"
    echo_info "Click the Tailscale icon in menu bar and sign in"
    echo ""
    read -p "Press Enter after authentication..."

elif [ "$OS" = "linux" ]; then
    # Linuxの場合はCLIで起動
    echo_info "Starting Tailscale daemon..."
    sudo tailscale up
fi

# 接続確認
echo ""
echo_step "Step 3/3: Verifying connection..."
sleep 2

if tailscale status &> /dev/null; then
    TAILSCALE_IP=$(tailscale ip -4)

    echo ""
    echo "=========================================="
    echo -e "${GREEN}  Tailscale Setup Complete!${NC}"
    echo "=========================================="
    echo ""
    echo "Your Tailscale IP: ${BLUE}$TAILSCALE_IP${NC}"
    echo ""

    # デバイス一覧表示
    echo "Connected devices:"
    tailscale status --self=false | head -10

    echo ""
    echo "=========================================="
    echo "Next Steps:"
    echo "=========================================="
    echo ""
    echo "1. SSH to your Minecraft server:"
    echo "   ${BLUE}ssh user@<server-tailscale-ip>${NC}"
    echo ""
    echo "2. Play Minecraft (optional - via Tailscale):"
    echo "   Server Address: ${BLUE}<server-tailscale-ip>:25565${NC}"
    echo ""
    echo "3. Manage Tailscale:"

    if [ "$OS" = "macos" ]; then
        echo "   - Menu bar icon → Settings"
    else
        echo "   - ${BLUE}tailscale status${NC}  # Show status"
        echo "   - ${BLUE}tailscale up${NC}      # Connect"
        echo "   - ${BLUE}tailscale down${NC}    # Disconnect"
    fi

    echo ""
    echo "4. Admin console:"
    echo "   ${BLUE}https://login.tailscale.com/admin${NC}"
    echo ""

else
    echo_error "Tailscale setup failed"
    echo "Please check:"
    echo "  - Internet connection"
    if [ "$OS" = "linux" ]; then
        echo "  - sudo systemctl status tailscaled"
    fi
    exit 1
fi

# SSH設定提案
echo ""
echo "=========================================="
echo "Optional: SSH Config Setup"
echo "=========================================="
echo ""
echo "Would you like to add Minecraft server to SSH config?"
read -p "Enter server Tailscale IP (or press Enter to skip): " SERVER_IP

if [ -n "$SERVER_IP" ]; then
    read -p "Enter SSH username (default: ubuntu): " SSH_USER
    SSH_USER=${SSH_USER:-ubuntu}

    SSH_CONFIG="$HOME/.ssh/config"

    # バックアップ
    if [ -f "$SSH_CONFIG" ]; then
        cp "$SSH_CONFIG" "$SSH_CONFIG.backup.$(date +%s)"
        echo_info "Backed up existing SSH config"
    fi

    # SSH設定追加
    cat >> "$SSH_CONFIG" <<EOF

# Minecraft Server (via Tailscale)
Host minecraft-server
    HostName $SERVER_IP
    User $SSH_USER
    IdentityFile ~/.ssh/id_rsa
EOF

    chmod 600 "$SSH_CONFIG"

    echo_info "SSH config updated!"
    echo ""
    echo "Now you can connect with:"
    echo "  ${BLUE}ssh minecraft-server${NC}"
    echo ""
fi

echo "=========================================="
echo "Setup complete!"
echo "=========================================="
