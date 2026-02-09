# Minecraft Server (Kubernetes)

Kubernetes で動かす Minecraft サーバー（Paper）

## 特徴

- **StatefulSet** - 安定した Pod 名でワールドデータを永続化
- **mc-backup サイドカー** - 自動バックアップ（*.jar 等は除外）
- **minecraft-exporter サイドカー** - Prometheus メトリクス収集
- **NetworkPolicy** - セキュリティ強化
- **Kustomize** - 環境別設定管理

## 必要要件

- Kubernetes クラスタ（v1.25+）
- kubectl
- kube-prometheus-stack（監視機能使用時）
- 最低4GB RAM（推奨8GB以上）

## クイックスタート

### 1. Secret のパスワードを変更

```bash
# RCON パスワードを変更（必須）
vim secret.yaml
```

### 2. デプロイ

```bash
kubectl apply -k .
```

### 3. 起動確認

```bash
# Pod 状態確認
kubectl -n minecraft get pods -w

# ログ確認
kubectl -n minecraft logs minecraft-0 -c minecraft -f

# "Done" メッセージが出たら起動完了
```

### 4. 接続

```bash
# LoadBalancer IP を確認
kubectl -n minecraft get svc minecraft

# Minecraft クライアントから接続
# サーバーアドレス: <EXTERNAL-IP>:25565
```

## Manifest 構成

| ファイル | 説明 |
|----------|------|
| namespace.yaml | minecraft Namespace |
| configmap.yaml | サーバー設定（非機密） |
| secret.yaml | RCON パスワード等（機密） |
| pvc.yaml | ワールドデータ + バックアップ用ストレージ |
| statefulset.yaml | メインサーバー + サイドカー |
| service.yaml | ゲーム接続用 + 内部用 Service |
| networkpolicy.yaml | ネットワークアクセス制御 |
| servicemonitor.yaml | Prometheus 監視設定 |
| kustomization.yaml | Kustomize 設定 |

## サイドカー構成

### mc-backup（バックアップ）

- 24時間ごとに自動バックアップ
- 7日以上古いバックアップは自動削除
- プレイヤー不在時のみバックアップ実行
- **除外対象**: `*.jar`, `cache`, `logs`, `libraries`, `versions`

### minecraft-exporter（監視）

- RCON 経由でサーバー情報取得
- Prometheus メトリクス公開（ポート 9225）
- プレイヤー数、TPS、メモリ使用量等

## 管理コマンド

### サーバー操作

```bash
# Pod 再起動
kubectl -n minecraft rollout restart statefulset minecraft

# RCON 接続
kubectl -n minecraft exec -it minecraft-0 -c minecraft -- rcon-cli

# シェル接続
kubectl -n minecraft exec -it minecraft-0 -c minecraft -- bash
```

### ログ確認

```bash
# メインサーバー
kubectl -n minecraft logs minecraft-0 -c minecraft -f

# バックアップ
kubectl -n minecraft logs minecraft-0 -c mc-backup -f

# メトリクス
kubectl -n minecraft logs minecraft-0 -c minecraft-exporter -f
```

### バックアップ確認

```bash
# バックアップ一覧
kubectl -n minecraft exec minecraft-0 -c mc-backup -- ls -la /backups

# 手動バックアップ
kubectl -n minecraft exec minecraft-0 -c mc-backup -- backup now
```

## 設定変更

### メモリ調整

```bash
# configmap.yaml の MEMORY を変更
vim configmap.yaml

# statefulset.yaml のリソース制限も調整
vim statefulset.yaml

# 適用
kubectl apply -k .
```

### プラグイン追加

```bash
# configmap.yaml の SPIGET_RESOURCES を変更
# 例: LuckPerms (28140) を追加
SPIGET_RESOURCES: "26585,18494,28140"

# 適用
kubectl apply -k .

# 再起動
kubectl -n minecraft rollout restart statefulset minecraft
```

## 監視

### Prometheus

ServiceMonitor により自動で監視対象に追加されます。

```bash
# メトリクスエンドポイント確認
kubectl -n minecraft port-forward svc/minecraft-internal 9225:9225
curl localhost:9225/metrics
```

### 主要メトリクス

- `minecraft_players_online` - オンラインプレイヤー数
- `minecraft_players_max` - 最大プレイヤー数
- `minecraft_tps` - サーバー TPS
- `minecraft_jvm_memory_bytes_used` - JVM メモリ使用量

## トラブルシューティング

### Pod が起動しない

```bash
# イベント確認
kubectl -n minecraft describe pod minecraft-0

# PVC 状態確認
kubectl -n minecraft get pvc
```

### メモリ不足

```yaml
# statefulset.yaml のリソース制限を調整
resources:
  requests:
    memory: "2Gi"
  limits:
    memory: "3Gi"
```

### 接続できない

```bash
# Service 状態確認
kubectl -n minecraft get svc

# NetworkPolicy 確認
kubectl -n minecraft get networkpolicy

# ポートフォワードでテスト
kubectl -n minecraft port-forward svc/minecraft 25565:25565
```

## 削除

```bash
# 全リソース削除（PVC 含む）
kubectl delete -k .

# Namespace のみ削除
kubectl delete namespace minecraft
```

## 参考リンク

- [itzg/docker-minecraft-server](https://github.com/itzg/docker-minecraft-server)
- [itzg/mc-backup](https://github.com/itzg/docker-mc-backup)
- [minecraft-exporter](https://github.com/Joshi425/minecraft-exporter)
- [Paper Documentation](https://docs.papermc.io/)
