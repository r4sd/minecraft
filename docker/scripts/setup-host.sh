#!/bin/bash
#
# Minecraft Server - Host OS Setup Script
# Ubuntu/Debian向けの初回セットアップスクリプト
#
# 前提: サーバーにSSHでログイン済み
#

set -e

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# root権限チェック
if [ "$EUID" -eq 0 ]; then
    echo_error "This script should NOT be run as root"
    echo_info "Please run as a regular user with sudo privileges"
    exit 1
fi

# sudo権限チェック
if ! sudo -v; then
    echo_error "This script requires sudo privileges"
    exit 1
fi

echo "=========================================="
echo "  Minecraft Server - Host Setup"
echo "=========================================="
echo ""

# OS確認
echo_info "Checking OS..."
if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo_info "OS: $NAME $VERSION"
else
    echo_error "Cannot detect OS. This script supports Ubuntu/Debian only."
    exit 1
fi

# システム要件確認
echo ""
echo_info "Checking system requirements..."

# メモリチェック
TOTAL_MEM=$(free -g | awk '/^Mem:/{print $2}')
echo_info "Total Memory: ${TOTAL_MEM}GB"
if [ "$TOTAL_MEM" -lt 4 ]; then
    echo_warn "Recommended: 4GB+ RAM (Current: ${TOTAL_MEM}GB)"
    echo_warn "Server may experience performance issues"
fi

# ディスクチェック
DISK_AVAIL=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
echo_info "Available Disk: ${DISK_AVAIL}GB"
if [ "$DISK_AVAIL" -lt 10 ]; then
    echo_warn "Recommended: 10GB+ free space (Current: ${DISK_AVAIL}GB)"
fi

# 1. システムアップデート
echo ""
echo_info "Step 1/6: Updating system packages..."
sudo apt-get update -qq
sudo apt-get upgrade -y -qq

# 2. 必要パッケージインストール
echo ""
echo_info "Step 2/6: Installing required packages..."
sudo apt-get install -y -qq \
    curl \
    wget \
    git \
    ca-certificates \
    gnupg \
    lsb-release

# 3. Docker インストール
echo ""
echo_info "Step 3/6: Installing Docker..."

if command -v docker &> /dev/null; then
    echo_info "Docker is already installed: $(docker --version)"
else
    # Docker公式リポジトリ追加
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
        sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Docker インストール
    sudo apt-get update -qq
    sudo apt-get install -y -qq \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-compose-plugin

    # 現在のユーザーをdockerグループに追加
    sudo usermod -aG docker "$USER"

    echo_info "Docker installed: $(docker --version)"
    echo_warn "Please log out and log back in for docker group changes to take effect"
fi

# 4. ファイアウォール設定
echo ""
echo_info "Step 4/6: Configuring firewall..."

if command -v ufw &> /dev/null; then
    # UFW使用
    echo_info "UFW detected, configuring rules..."
    sudo ufw allow 22/tcp comment 'SSH' > /dev/null
    sudo ufw allow 25565/tcp comment 'Minecraft' > /dev/null

    # UFWが無効の場合のみ有効化を提案
    if ! sudo ufw status | grep -q "Status: active"; then
        echo_warn "UFW is not active. Enable it? (y/N)"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            sudo ufw --force enable
            echo_info "UFW enabled"
        fi
    else
        sudo ufw reload > /dev/null
        echo_info "UFW rules updated"
    fi
else
    echo_warn "UFW not found. Please manually configure firewall:"
    echo "  - Allow TCP port 22 (SSH)"
    echo "  - Allow TCP port 25565 (Minecraft)"
fi

# 5. プロジェクトディレクトリ作成
echo ""
echo_info "Step 5/6: Setting up project directory..."

PROJECT_DIR="${HOME}/minecraft"
echo_info "Project directory: $PROJECT_DIR"

if [ -d "$PROJECT_DIR" ]; then
    echo_warn "Directory already exists: $PROJECT_DIR"
else
    mkdir -p "$PROJECT_DIR"
    mkdir -p "$PROJECT_DIR/backups"
    echo_info "Created: $PROJECT_DIR"
fi

# 6. Git設定確認
echo ""
echo_info "Step 6/6: Checking Git configuration..."

if [ ! -f ~/.gitconfig ] || ! git config user.name &> /dev/null; then
    echo_warn "Git not configured. Configure now? (y/N)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo -n "Enter your name: "
        read -r git_name
        echo -n "Enter your email: "
        read -r git_email
        git config --global user.name "$git_name"
        git config --global user.email "$git_email"
        echo_info "Git configured"
    fi
fi

# 完了メッセージ
echo ""
echo "=========================================="
echo -e "${GREEN}  Setup Completed Successfully!${NC}"
echo "=========================================="
echo ""
echo "Next steps:"
echo ""
echo "1. Log out and log back in (for docker group)"
echo "   $ exit"
echo "   $ ssh user@server"
echo ""
echo "2. Clone the repository:"
echo "   $ cd ~/minecraft"
echo "   $ git clone <repository-url> ."
echo ""
echo "3. Start the server:"
echo "   $ cd docker/minecraft"
echo "   $ docker compose up -d"
echo ""
echo "4. Check logs:"
echo "   $ docker compose logs -f"
echo ""
echo "5. Connect from Minecraft client:"
echo "   Server Address: $(hostname -I | awk '{print $1}'):25565"
echo ""
echo "=========================================="

# システム情報表示
echo ""
echo "System Information:"
echo "  OS: $NAME $VERSION"
echo "  Memory: ${TOTAL_MEM}GB"
echo "  Disk Available: ${DISK_AVAIL}GB"
echo "  Docker: $(docker --version 2>/dev/null || echo 'Not available in current session')"
echo "  Project Dir: $PROJECT_DIR"
echo ""

# 再起動が必要か確認
if [ -f /var/run/reboot-required ]; then
    echo_warn "System reboot is recommended"
    echo "Run: sudo reboot"
fi
