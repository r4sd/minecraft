# Minecraft Server (Kubernetes)

Kubernetes で動かす Minecraft サーバー（Paper + Velocity）

## アーキテクチャ

### Phase 2: マルチサーバー構成

```
              Players (Minecraft Client)
                       │ :25565
                       ▼
            ┌─────────────────────┐
            │   Velocity Proxy    │
            │   LoadBalancer      │
            └───┬─────────┬───────┘
                │         │
                ▼         ▼
       ┌──────────┐  ┌──────────────────┐
       │  Lobby   │  │    Survival      │
       │  Paper   │  │    Paper         │
       │ ClusterIP│  │   ClusterIP      │
       │ 512M-1Gi │  │ 4-5Gi + sidecars │
       └──────────┘  └──────────────────┘
```

- **Velocity Proxy**: プレイヤー接続を受け、バックエンドに振り分け
- **Lobby**: シンプルハブ（看板クリックでサーバー移動）
- **Survival**: フルスペック（プラグイン、バックアップ、監視付き）

### Phase 1: シングルサーバー（レガシー）

ルート直下の `*.yaml` ファイルが Phase 1 構成。Phase 2 移行後も参照用に残している。

## ディレクトリ構成

```
kubernetes/
├── # Phase 1（シングルサーバー）
├── namespace.yaml
├── configmap.yaml
├── secret.yaml
├── statefulset.yaml
├── service.yaml
├── pvc.yaml
├── networkpolicy.yaml
├── servicemonitor.yaml
├── kustomization.yaml
│
├── # Phase 2（マルチサーバー）
├── proxy/                    # Velocity Proxy
│   ├── deployment.yaml       # itzg/bungeecord (TYPE=VELOCITY) digest pin
│   ├── service.yaml          # LoadBalancer :25565
│   ├── configmap.yaml        # velocity.toml
│   └── kustomization.yaml    # Secret は sealed-secrets/ 参照
│
├── paper-base/               # Paper 共通テンプレート
│   ├── statefulset.yaml      # itzg/minecraft-server digest pin
│   ├── service.yaml          # ClusterIP (25565 のみ; RCON は localhost)
│   ├── configmap.yaml        # 共通設定
│   └── kustomization.yaml    # Secret は sealed-secrets/ 参照
│
├── sealed-secrets/           # SealedSecrets (homelab-infra と同じ方式)
│   └── README.md             # kubeseal ワークフロー
│
└── overlays/
    ├── lobby/                # ロビー（軽量）
    │   └── kustomization.yaml
    └── survival/             # サバイバル（フルスペック）
        ├── kustomization.yaml
        ├── patch-survival.yaml   # サイドカー + リソース拡大
        ├── patch-service.yaml    # metrics ポート (9225) 追加
        └── servicemonitor.yaml
```

## 必要要件

- Kubernetes クラスタ（v1.25+）
- kubectl
- kube-prometheus-stack（監視機能使用時）
- **Sealed Secrets コントローラ** (homelab-infra に既にインストール済)
- `kubeseal` CLI (Secret 暗号化用、ローカル)

## デプロイ（Phase 2）

### 1. Namespace 作成

```bash
kubectl apply -f kubernetes/namespace.yaml
```

### 2. SealedSecrets を生成・適用

平文 Secret はリポジトリに含めない。`kubeseal` で暗号化したマニフェストを `kubernetes/sealed-secrets/` 配下に生成して apply する。

手順: [kubernetes/sealed-secrets/README.md](sealed-secrets/README.md) を参照。

```bash
# 暗号化済みマニフェストを apply
kubectl apply -f kubernetes/sealed-secrets/
```

### 3. Proxy デプロイ

```bash
kubectl apply -k kubernetes/proxy/
```

### 4. Paper サーバーデプロイ

```bash
# ロビー
kubectl apply -k kubernetes/overlays/lobby/

# サバイバル
kubectl apply -k kubernetes/overlays/survival/
```

### 5. 起動確認

```bash
# 全 Pod 状態確認
kubectl -n minecraft get pods -w

# Velocity ログ
kubectl -n minecraft logs deploy/velocity -f

# ロビーログ
kubectl -n minecraft logs lobby-paper-0 -c paper -f

# サバイバルログ
kubectl -n minecraft logs survival-paper-0 -c paper -f
```

### 6. 接続

```bash
# Velocity の LoadBalancer IP を確認
kubectl -n minecraft get svc velocity

# Minecraft クライアントから接続
# サーバーアドレス: <EXTERNAL-IP>:25565
# → 自動的にロビーに接続される
```

## サーバー追加

クリエイティブ等のサーバーを追加する場合:

```bash
# 1. overlay を作成
mkdir -p kubernetes/overlays/creative

# 2. kustomization.yaml を作成（lobby を参考に）
# 3. velocity.toml にサーバーを追加
# 4. デプロイ
kubectl apply -k kubernetes/overlays/creative/
```

## サイドカー構成（サバイバルのみ）

### mc-backup

- 24時間ごとに自動バックアップ
- 7日以上古いバックアップは自動削除
- プレイヤー不在時のみバックアップ実行

### minecraft-exporter

- RCON 経由でサーバー情報取得
- Prometheus メトリクス公開（ポート 9225）

## 管理コマンド

```bash
# Pod 再起動
kubectl -n minecraft rollout restart statefulset lobby-paper
kubectl -n minecraft rollout restart statefulset survival-paper
kubectl -n minecraft rollout restart deploy velocity

# RCON 接続（Service には載せていないので exec 経由）
kubectl -n minecraft exec -it survival-paper-0 -c paper -- rcon-cli

# バックアップ確認
kubectl -n minecraft logs survival-paper-0 -c mc-backup -f
```

## イメージ管理

全コンテナイメージは `tag@sha256:digest` 形式で digest pin している。再現性確保と sup-chain 攻撃対策。

| イメージ | 用途 |
|----------|------|
| `itzg/minecraft-server:java21@sha256:...` | Paper サーバー本体 |
| `itzg/bungeecord:java21@sha256:...` | Velocity Proxy (TYPE=VELOCITY) |
| `itzg/mc-backup:latest@sha256:...` | バックアップサイドカー |
| `joshi425/minecraft-exporter:latest@sha256:...` | Prometheus exporter |
| `busybox:1.36@sha256:...` | initContainer (Velocity forwarding 設定生成) |

更新時は `crane digest <image>:<tag>` または Docker Hub の Tags ページで最新 digest を取得して置換。

## CI

GitHub Actions で PR 時にマニフェスト検証を自動実行:

- `kustomize build`: 各 overlay のビルド検証
- `kubeconform`: K8s スキーマ準拠チェック

## 参考リンク

- [itzg/docker-minecraft-server](https://github.com/itzg/docker-minecraft-server)
- [itzg/mc-backup](https://github.com/itzg/docker-mc-backup)
- [minecraft-exporter](https://github.com/Joshi425/minecraft-exporter)
- [Velocity Documentation](https://docs.papermc.io/velocity)
- [Paper Documentation](https://docs.papermc.io/)
