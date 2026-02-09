# Minecraft Server

Docker / Kubernetes 対応の Minecraft サーバー構成

## 特徴

- **Paper Server** - 高性能、プラグイン対応
- **自動停止機能** - プレイヤー不在時に自動停止してリソース節約
- **プラグイン自動導入** - ImageOnMap, DiscordSRV 等
- **バックアップ対応** - mc-backup によるデータ保護
- **監視対応** - Prometheus メトリクス収集（minecraft-exporter）

## デプロイ方法

| 環境 | ディレクトリ | 説明 |
|------|-------------|------|
| Docker Compose | [docker/](docker/) | シンプルな単一ホスト構成 |
| Kubernetes | [kubernetes/](kubernetes/) | 本格的なクラスタ構成 |

## クイックスタート

### Docker Compose

```bash
cd docker
docker compose up -d
docker compose logs -f
```

### Kubernetes

```bash
cd kubernetes
# Secret のパスワードを変更
vim secret.yaml

# デプロイ
kubectl apply -k .

# 確認
kubectl -n minecraft get pods -w
kubectl -n minecraft logs minecraft-0 -f
```

## 必要要件

**Docker版:**

- Docker & Docker Compose
- 最低4GB RAM（推奨8GB以上）
- ディスク空き容量: 5GB以上

**Kubernetes版:**

- Kubernetes クラスタ + kubectl
- kube-prometheus-stack（監視機能使用時）
- 最低4GB RAM（推奨8GB以上）

## ディレクトリ構造

```
minecraft/
├── README.md           # このファイル
├── LICENSE
├── .gitignore
│
├── docker/             # Docker Compose 構成
│   ├── README.md
│   ├── docker-compose.yml
│   ├── .env.example
│   └── scripts/
│
└── kubernetes/         # Kubernetes Manifest
    ├── README.md
    ├── kustomization.yaml
    ├── namespace.yaml
    ├── configmap.yaml
    ├── secret.yaml
    ├── pvc.yaml
    ├── statefulset.yaml
    ├── service.yaml
    ├── networkpolicy.yaml
    └── servicemonitor.yaml
```

## 参考リンク

- [itzg/docker-minecraft-server](https://github.com/itzg/docker-minecraft-server)
- [itzg/mc-backup](https://github.com/itzg/docker-mc-backup)
- [Paper Documentation](https://docs.papermc.io/)

## ライセンス

[MIT License](LICENSE)

## 履歴

- 2025-02: Kubernetes 対応追加
- 2025-01: itzg/minecraft-serverに移行
- 2022-08: 初版（Amazon Corretto + 自作Dockerfile）
