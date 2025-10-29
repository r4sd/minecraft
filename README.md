# Minecraft Server (Docker)

Docker化されたMinecraftサーバー（Paper）+ プラグイン対応

## 目次

- [特徴](#特徴)
- [HOWTO: ゼロから始めるサーバー構築](#howto-ゼロから始めるサーバー構築)
- [クイックスタート](#クイックスタート)
- [管理コマンド](#管理コマンド)
- [設定](#設定)
- [プラグイン](#プラグイン)
- [Discord連携設定](#discord連携設定)
- [トラブルシューティング](#トラブルシューティング)
- [ライセンス](#ライセンス)

## 特徴

- **Paper Server** - 高性能、プラグイン対応
- **自動停止機能** - プレイヤー不在時に自動停止してリソース節約
- **プラグイン自動導入** - ImageOnMap, DiscordSRV等
- **バックアップ対応** - 静止点を取ってデータ保護
- **ヘルスチェック** - サーバー状態を自動監視

## 必要要件

- Docker & Docker Compose
- 最低4GB RAM（推奨8GB以上）
- ディスク空き容量: 5GB以上

## HOWTO: ゼロから始めるサーバー構築

### 前提条件

- VPS/クラウドサーバー（AWS EC2、ConoHa VPS、Contabo等）を契約済み
- サーバーにSSHでログイン可能
- Ubuntu 20.04/22.04 または Debian 11/12

### ステップ1: サーバーにSSHログイン

```bash
# ローカルPCから
ssh username@your-server-ip

# 初回ログイン後、パスワード変更推奨
passwd
```

**セキュリティ強化（推奨）:**
```bash
# 鍵認証設定
ssh-copy-id username@your-server-ip

# パスワード認証を無効化
sudo vim /etc/ssh/sshd_config
# PasswordAuthentication no
sudo systemctl restart sshd
```

### ステップ2: ホストOSセットアップ

```bash
# セットアップスクリプトをダウンロード
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/minecraft/main/scripts/setup-host.sh -o setup-host.sh

# 実行権限付与
chmod +x setup-host.sh

# 実行
./setup-host.sh
```

**セットアップスクリプトの内容:**
- システムパッケージ更新
- Docker & Docker Composeインストール
- ファイアウォール設定（ポート25565開放）
- プロジェクトディレクトリ作成
- システム要件チェック

**完了後、再ログインが必要:**
```bash
# ログアウト
exit

# 再ログイン（dockerグループ反映）
ssh username@your-server-ip
```

### ステップ3: リポジトリをクローン

```bash
# プロジェクトディレクトリへ移動
cd ~/minecraft

# リポジトリをクローン
git clone https://github.com/YOUR_USERNAME/minecraft.git .

# または、直接ダウンロード
wget https://github.com/YOUR_USERNAME/minecraft/archive/main.zip
unzip main.zip
mv minecraft-main/* .
```

### ステップ4: サーバーを起動

```bash
# プロジェクトディレクトリへ移動
cd ~/minecraft

# 起動（初回は5-10分かかる）
docker compose up -d

# ログ確認
docker compose logs -f
```

**初回起動時の処理:**
1. Paperサーバーのダウンロード
2. プラグイン（ImageOnMap, DiscordSRV）の自動インストール
3. ワールド生成
4. サーバー起動完了

**起動完了のサイン:**
```
Done (10.234s)! For help, type "help"
```

### ステップ5: 接続確認

**Minecraftクライアントから接続:**
```
サーバーアドレス: your-server-ip:25565
```

**サーバーIPの確認:**
```bash
# パブリックIPを確認
curl ifconfig.me
```

**ファイアウォール確認:**
```bash
# ポート25565が開いているか確認
sudo ufw status
sudo netstat -tuln | grep 25565
```

### ステップ6: 初期設定

**セキュリティ設定（重要）:**
```bash
# .envファイルを作成してRCONパスワードを変更
cp .env.example .env
vim .env

# RCON_PASSWORDを変更（デフォルトの"minecraft"は危険）
RCON_PASSWORD=your_secure_password_here

# 再起動して反映
docker compose restart
```

**OP権限付与:**
```bash
# RCONで接続
docker compose exec minecraft rcon-cli

# プレイヤーにOP権限付与
> op YourMinecraftUsername
> exit
```

**ホワイトリスト有効化（推奨）:**
```yaml
# docker-compose.yml
environment:
  ENABLE_WHITELIST: "true"
  WHITELIST: |
    player1
    player2
```

```bash
# 再起動
docker compose restart
```

### ステップ7: バックアップ設定

```bash
# バックアップスクリプトのテスト
cd ~/minecraft
./scripts/backup.sh

# cron設定（毎日3時に自動バックアップ）
crontab -e

# 以下を追加
0 3 * * * cd ~/minecraft && ./scripts/backup.sh

# Discord通知設定（オプション）
# .envファイル作成
echo 'DISCORD_WEBHOOK=https://discord.com/api/webhooks/YOUR_WEBHOOK_URL' > ~/minecraft/.env

# cronに環境変数を渡す
0 3 * * * cd ~/minecraft && source .env && ./scripts/backup.sh
```

### よくある質問

**Q: サーバーが起動しない**
```bash
# ログ確認
docker compose logs

# メモリ不足の場合
# docker-compose.yml の MEMORY を減らす
MEMORY: "2G"
```

**Q: 接続できない**
```bash
# ファイアウォール確認
sudo ufw allow 25565/tcp

# Dockerコンテナ確認
docker compose ps

# ポート確認
sudo netstat -tuln | grep 25565
```

**Q: メモリが足りない**
```yaml
# docker-compose.yml
environment:
  MEMORY: "2G"  # 4G → 2Gに変更

deploy:
  resources:
    limits:
      memory: 3G  # 5G → 3Gに変更
```

**Q: プラグインを追加したい**
```yaml
# Spiget Resource IDを追加
# https://www.spigotmc.org/resources/ で検索
SPIGET_RESOURCES: "26585,18494,28140"  # LuckPerms追加
```

**Q: Modサーバーにしたい**
```yaml
# docker-compose.yml
environment:
  TYPE: "FORGE"  # または FABRIC
  VERSION: "1.20.1"
  # プラグインは使えなくなる
```

## クイックスタート

### 1. サーバー起動

```bash
cd ~/minecraft
docker compose up -d
```

初回起動時は以下が自動実行されます：
- Paperサーバーのダウンロード
- プラグイン（ImageOnMap, DiscordSRV）のインストール
- ワールド生成

### 2. ログ確認

```bash
docker compose logs -f minecraft
```

`Done (x.xxxs)! For help, type "help"` が表示されたら起動完了です。

### 3. サーバー接続

Minecraftクライアントから接続：
```
サーバーアドレス: localhost:25565
```

## 管理コマンド

### サーバー操作

```bash
# 起動
docker compose up -d

# 停止
docker compose stop

# 再起動
docker compose restart

# ログ確認
docker compose logs -f minecraft

# コンテナに入る
docker compose exec minecraft bash
```

### RCON（リモートコンソール）

```bash
# RCON接続
docker compose exec minecraft rcon-cli

# コマンド実行例
> list
> op <player_name>
> whitelist add <player_name>
```

### バックアップ

**手動バックアップ:**
```bash
# 基本的な実行
cd /path/to/minecraft
./scripts/backup.sh

# 環境変数でカスタマイズ
RETENTION_DAYS=14 ./scripts/backup.sh  # 14日間保持
BACKUP_DIR=~/minecraft-backups ./scripts/backup.sh  # 保存先変更

# Discord通知付き
DISCORD_WEBHOOK=https://discord.com/api/webhooks/xxx ./scripts/backup.sh
```

**バックアップの特徴:**
- ✅ サーバー停止→バックアップ→再起動（静止点取得）
- ✅ エラーハンドリング（失敗時は自動ロールバック）
- ✅ バックアップ整合性チェック
- ✅ 古いバックアップ自動削除
- ✅ ログファイル出力（`backups/backup.log`）
- ✅ Discord通知（オプション）

**バックアップから復元:**
```bash
docker compose stop
tar xzf backups/minecraft-backup-YYYYMMDD-HHMMSS.tar.gz
docker compose start
```

**自動バックアップ設定（cron）:**
```bash
# cron編集
crontab -e

# 毎日3時にバックアップ
0 3 * * * cd ~/minecraft && ./scripts/backup.sh

# Discord通知付き
0 3 * * * cd ~/minecraft && DISCORD_WEBHOOK=https://discord.com/api/webhooks/xxx ./scripts/backup.sh

# ログ確認
tail -f ~/minecraft/backups/backup.log
```

## 設定

### docker-compose.yml

主要な設定項目：

```yaml
environment:
  # メモリ
  MEMORY: "4G"  # 使用可能メモリに応じて調整

  # プレイヤー数
  MAX_PLAYERS: 20

  # 描画距離
  VIEW_DISTANCE: 10

  # 自動停止タイムアウト（秒）
  AUTOSTOP_TIMEOUT_EST: 3600  # 1時間

  # プラグイン（Spiget Resource ID）
  SPIGET_RESOURCES: "26585,18494"
```

### プラグイン追加

Spiget Resource IDを `SPIGET_RESOURCES` に追加：

```yaml
# 例: LuckPerms (28140) を追加
SPIGET_RESOURCES: "26585,18494,28140"
```

Resource IDの確認: https://www.spigotmc.org/resources/

### ワールド設定

```yaml
environment:
  LEVEL: "world"              # ワールド名
  SEED: "-1785852800490497919"  # シード値
  LEVEL_TYPE: "minecraft:normal" # ワールドタイプ
  DIFFICULTY: "normal"        # 難易度
  MODE: "survival"            # ゲームモード
```

## プラグイン

### 自動導入プラグイン

1. **ImageOnMap (26585)**
   - URL画像を地図アイテム化
   - 使い方: `/tomap <URL>`

2. **DiscordSRV (18494)**
   - Discord連携
   - 設定ファイル: `data/plugins/DiscordSRV/config.yml`

### プラグイン設定

```bash
# 設定ファイル編集
cd server/plugins/<Plugin名>
vim config.yml

# サーバー再起動で反映
docker compose restart
```

## Discord連携設定

### 1. Discord Botを作成

1. https://discord.com/developers/applications にアクセス
2. New Application → Bot作成
3. Tokenをコピー

### 2. DiscordSRVを設定

```bash
# 設定ファイル編集
vim server/plugins/DiscordSRV/config.yml
```

```yaml
# 最小限の設定
BotToken: "YOUR_BOT_TOKEN"
Channels:
  global: "123456789012345678"  # チャンネルID
```

### 3. サーバー再起動

```bash
docker compose restart
```

## トラブルシューティング

### サーバーが起動しない

```bash
# ログ確認
docker compose logs minecraft

# コンテナ再作成
docker compose down
docker compose up -d
```

### メモリ不足

```yaml
# docker-compose.yml
environment:
  MEMORY: "2G"  # メモリを減らす

deploy:
  resources:
    limits:
      memory: 3G  # 制限も調整
```

### プラグインが動作しない

```bash
# プラグイン一覧確認
docker compose exec minecraft rcon-cli plugins

# プラグインディレクトリ確認
ls -la server/plugins/
```

### ポートが使われている

```bash
# ポート変更
# docker-compose.yml
ports:
  - "25566:25565"  # ホスト側ポートを変更
```

## パフォーマンスチューニング

### メモリ最適化

```yaml
# Aikar's Flags（推奨）
USE_AIKAR_FLAGS: "true"

# メモリ設定
MEMORY: "4G"  # 使用可能メモリの50-75%
```

### Paper設定

```bash
vim server/paper.yml
vim server/spigot.yml
```

参考: https://docs.papermc.io/paper/admin/reference/paper-global-configuration

## ディレクトリ構造

```
minecraft/
├── docker-compose.yml           # メイン設定
├── .env.example                 # 環境変数テンプレート
├── .gitignore
├── README.md
│
├── server/                      # サーバーデータ（自動生成）
├── backups/                     # バックアップ保存先
│
├── scripts/                     # 管理スクリプト
│   ├── backup.sh                # バックアップ
│   ├── setup-host.sh            # サーバーOS初期設定
│   └── setup-tailscale-desktop.sh  # デスクトップTailscale設定
│
└── docs/                        # プロジェクトメモ（オプション）
```

## アップデート

### Paperバージョンアップ

```bash
# 最新版に更新
docker compose pull
docker compose up -d
```

### プラグイン更新

```bash
# 自動更新（再起動時）
docker compose restart

# 手動更新
rm data/plugins/<Plugin名>.jar
# SPIGET_RESOURCES で再ダウンロード
docker compose restart
```

## 参考リンク

- [itzg/docker-minecraft-server](https://github.com/itzg/docker-minecraft-server)
- [Paper Documentation](https://docs.papermc.io/)
- [Spigot Resources](https://www.spigotmc.org/resources/)
- [DiscordSRV Wiki](https://docs.discordsrv.com/)

## ライセンス

[MIT License](LICENSE)

このソフトウェアは「現状のまま」提供され、いかなる保証もありません。
サーバーの停止、データ損失、その他の問題について作者は責任を負いません。

## 履歴

- 2025-01: itzg/minecraft-serverに移行
- 2022-08: 初版（Amazon Corretto + 自作Dockerfile）
