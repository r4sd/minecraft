#!/bin/bash
#
# Minecraft Docker Server Backup Script
# サーバーを停止してデータをバックアップ
#

set -euo pipefail

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# スクリプトのディレクトリを基準にパスを決定
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 設定（環境変数で上書き可能）
COMPOSE_FILE="${COMPOSE_FILE:-$PROJECT_ROOT/docker-compose.yml}"
BACKUP_DIR="${BACKUP_DIR:-$PROJECT_ROOT/backups}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"
CONTAINER_NAME="minecraft-server"
LOG_FILE="${LOG_FILE:-$PROJECT_ROOT/backups/backup.log}"
DISCORD_WEBHOOK="${DISCORD_WEBHOOK:-}"

# ログ関数
log() {
    echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log_info() {
    log "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    log "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    log "${RED}[ERROR]${NC} $*"
}

# Discord通知
send_discord_notification() {
    local message="$1"
    local color="${2:-5814783}"  # デフォルト: グレー

    if [ -n "$DISCORD_WEBHOOK" ]; then
        curl -H "Content-Type: application/json" \
             -X POST \
             -d "{\"embeds\":[{\"title\":\"Minecraft Backup\",\"description\":\"$message\",\"color\":$color}]}" \
             "$DISCORD_WEBHOOK" &> /dev/null || true
    fi
}

# エラーハンドラー
cleanup_on_error() {
    log_error "Backup failed! Rolling back..."

    # サーバー再起動
    if docker compose -f "$COMPOSE_FILE" ps | grep -q "minecraft"; then
        docker compose -f "$COMPOSE_FILE" start minecraft 2>/dev/null || true
    fi

    # 不完全なバックアップ削除
    if [ -f "$BACKUP_FILE" ]; then
        rm -f "$BACKUP_FILE"
        log_info "Removed incomplete backup file"
    fi

    send_discord_notification "❌ Backup failed" 15158332  # 赤
    exit 1
}

trap cleanup_on_error ERR

# バックアップディレクトリ作成
mkdir -p "$BACKUP_DIR"
mkdir -p "$(dirname "$LOG_FILE")"

# タイムスタンプ
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="$BACKUP_DIR/minecraft-backup-$TIMESTAMP.tar.gz"

log_info "=========================================="
log_info "  Minecraft Server Backup"
log_info "=========================================="
log_info "Timestamp: $TIMESTAMP"
log_info "Backup file: $BACKUP_FILE"
log_info ""

# 前提条件チェック
if [ ! -f "$COMPOSE_FILE" ]; then
    log_error "docker-compose.yml not found: $COMPOSE_FILE"
    exit 1
fi

if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed"
    exit 1
fi

# ディスク容量チェック
REQUIRED_SPACE_MB=1000
AVAILABLE_SPACE_MB=$(df -BM "$BACKUP_DIR" | awk 'NR==2 {print $4}' | sed 's/M//')
if [ "$AVAILABLE_SPACE_MB" -lt "$REQUIRED_SPACE_MB" ]; then
    log_warn "Low disk space: ${AVAILABLE_SPACE_MB}MB available (recommended: ${REQUIRED_SPACE_MB}MB+)"
fi

# サーバー停止
log_info "[1/6] Stopping Minecraft server..."
if docker compose -f "$COMPOSE_FILE" ps | grep -q "minecraft.*Up"; then
    docker compose -f "$COMPOSE_FILE" stop minecraft
    log_info "Server stopped"
else
    log_warn "Server was not running"
fi

# バックアップ実行（server.jarを除外）
log_info "[2/6] Creating backup archive..."
cd "$(dirname "$COMPOSE_FILE")"

tar czf "$BACKUP_FILE" \
    --exclude='server/*.jar' \
    --exclude='server/cache' \
    --exclude='server/logs' \
    --exclude='server/libraries' \
    --exclude='server/versions' \
    server/ 2>&1 | tee -a "$LOG_FILE" || {
        log_error "Failed to create backup archive"
        exit 1
    }

# バックアップ整合性チェック
log_info "[3/6] Verifying backup integrity..."
if tar tzf "$BACKUP_FILE" > /dev/null 2>&1; then
    log_info "Backup integrity verified"
else
    log_error "Backup file is corrupted"
    exit 1
fi

# サーバー再起動
log_info "[4/6] Starting Minecraft server..."
docker compose -f "$COMPOSE_FILE" start minecraft
log_info "Server started"

# バックアップサイズ確認
BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
log_info "[5/6] Backup completed: $BACKUP_SIZE"

# 古いバックアップ削除
log_info "[6/6] Cleaning up old backups (older than $RETENTION_DAYS days)..."
DELETED_COUNT=$(find "$BACKUP_DIR" -name "minecraft-backup-*.tar.gz" -type f -mtime +$RETENTION_DAYS -delete -print | wc -l)
if [ "$DELETED_COUNT" -gt 0 ]; then
    log_info "Deleted $DELETED_COUNT old backup(s)"
else
    log_info "No old backups to delete"
fi

log_info ""
log_info "=========================================="
log_info "  Backup completed successfully!"
log_info "=========================================="
log_info "Backup file: $BACKUP_FILE"
log_info "Size: $BACKUP_SIZE"

# バックアップ一覧表示
BACKUP_COUNT=$(ls -1 "$BACKUP_DIR"/minecraft-backup-*.tar.gz 2>/dev/null | wc -l)
log_info "Total backups: $BACKUP_COUNT"
log_info ""
log_info "Recent backups:"
ls -lh "$BACKUP_DIR"/minecraft-backup-*.tar.gz 2>/dev/null | tail -5 | tee -a "$LOG_FILE"

# Discord通知
send_discord_notification "✅ Backup completed successfully\nSize: $BACKUP_SIZE\nTotal backups: $BACKUP_COUNT" 3066993  # 緑

log_info ""
log_info "Log file: $LOG_FILE"
