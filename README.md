# Minecraft Server

Docker / Kubernetes 対応の Minecraft サーバー構成

## 特徴

- **Velocity + Paper マルチサーバー** - ロビー → サバイバル間のワールド移動
- **Kustomize overlay** - 共通テンプレートから各サーバーを生成
- **自動停止機能** - プレイヤー不在時に自動停止してリソース節約
- **プラグイン自動導入** - ImageOnMap, DiscordSRV 等
- **バックアップ対応** - mc-backup によるデータ保護
- **監視対応** - Prometheus メトリクス収集（minecraft-exporter）
- **CI** - kustomize build + kubeconform で自動検証

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

### Kubernetes（マルチサーバー）

Secret は **SealedSecrets** で管理（平文をコミットしない）。詳細は [kubernetes/sealed-secrets/README.md](kubernetes/sealed-secrets/README.md)。

```bash
# Namespace
kubectl apply -f kubernetes/namespace.yaml

# Secret (kubeseal で暗号化済みマニフェストを生成・適用)
# → kubernetes/sealed-secrets/README.md を参照
kubectl apply -f kubernetes/sealed-secrets/

# Proxy + Paper
kubectl apply -k kubernetes/proxy/
kubectl apply -k kubernetes/overlays/lobby/
kubectl apply -k kubernetes/overlays/survival/

# 確認
kubectl -n minecraft get pods -w
kubectl -n minecraft get svc velocity  # 接続先 IP
```

## 必要要件

**Docker版:**

- Docker & Docker Compose
- 最低4GB RAM（推奨8GB以上）
- ディスク空き容量: 5GB以上

**Kubernetes版:**

- Kubernetes クラスタ + kubectl
- Sealed Secrets コントローラ (homelab-infra 既設)
- `kubeseal` CLI (Secret 暗号化用)
- kube-prometheus-stack（監視機能使用時）
- 最低4GB RAM（推奨8GB以上）

## ディレクトリ構造

```
minecraft/
├── README.md
├── docker/                        # Docker Compose 構成
│   ├── docker-compose.yml
│   └── scripts/
│
├── kubernetes/                    # Kubernetes Manifest
│   ├── *.yaml                     # Phase 1（シングルサーバー）
│   ├── proxy/                     # Velocity Proxy
│   ├── paper-base/                # Paper 共通テンプレート
│   ├── sealed-secrets/            # SealedSecrets (kubeseal で暗号化)
│   └── overlays/
│       ├── lobby/                 # ロビーサーバー
│       └── survival/              # サバイバルサーバー
│
└── docs/plans/                    # 設計ドキュメント
```

## 参考リンク

- [itzg/docker-minecraft-server](https://github.com/itzg/docker-minecraft-server)
- [itzg/mc-backup](https://github.com/itzg/docker-mc-backup)
- [Paper Documentation](https://docs.papermc.io/)

## ライセンス

[MIT License](LICENSE)

## 履歴

- 2026-05: イメージ digest pin、RCON ポート非公開化、SealedSecrets 移行
- 2026-02: Velocity + Paper マルチサーバー構成追加
- 2025-02: Kubernetes 対応追加
- 2025-01: itzg/minecraft-serverに移行
- 2022-08: 初版（Amazon Corretto + 自作Dockerfile）
