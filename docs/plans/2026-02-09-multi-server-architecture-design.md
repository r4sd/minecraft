# Minecraft マルチサーバーアーキテクチャ設計

## 関連 Issue

- [#33 [Epic] Minecraft Server アーキテクチャ構築](https://github.com/r4sd/homelab-infra/issues/33)
- [#19 Minecraft サーバーデプロイ + 監視設定](https://github.com/r4sd/homelab-infra/issues/19)

## 概要

Phase 1（Paper シングルサーバー）から Phase 2（Velocity + マルチサーバー）へ移行する。
友達 5-10 人でロビー→サバイバル間のワールド移動を実現する。

## 設計判断

| 項目 | 決定 | 理由 |
|------|------|------|
| 方式 | Velocity + Paper ×2 | K8s マルチ Pod 構成の学習価値 |
| サーバー構成 | ロビー + サバイバル | ミニマムで移動体験を実現、クリエイティブは後から追加 |
| ワールドデータ | 新規スタート | Phase 1 は検証用、クリーンに始める |
| ロビー | シンプルハブ（看板クリック移動） | 凝った作り込みは後回し |
| マニフェスト | Kustomize 共通テンプレート + overlay | 既存構成との一貫性、サーバー追加が容易 |
| Pod 間通信 | K8s Service 経由 | シンプル。将来 Headless Service + Pod DNS に移行可能 |
| CI | kustomize build + kubeconform | ミニマム検証。後から kube-score + Trivy 追加可能 |
| リポジトリ | パブリック維持 | 機密情報なし、OSS 的価値 |

## アーキテクチャ

```
                Players (Minecraft Client)
                         │ :25565
                         ▼
              ┌─────────────────────┐
              │   Velocity Proxy    │
              │   (proxy-svc)       │
              │   LoadBalancer      │
              │   512MB / 0.5 CPU   │
              └───┬─────────┬───────┘
                  │         │
                  ▼         ▼
         ┌──────────┐  ┌──────────────────┐
         │  Lobby   │  │    Survival      │
         │  Paper   │  │    Paper         │
         │ ClusterIP│  │   ClusterIP      │
         │ 256-512MB│  │   4GB / 1CPU     │
         │ PVC: 1Gi │  │   PVC: 20Gi      │
         │          │  │   Backup: 50Gi   │
         │ プラグイン: │  │   サイドカー:     │
         │ - 移動看板 │  │   - mc-backup   │
         │          │  │   - exporter     │
         └──────────┘  │   プラグイン:      │
                       │   - ImageOnMap   │
                       │   - DiscordSRV   │
                       │   - CoreProtect  │
                       └──────────────────┘
```

### Service 構成

| Service | 種別 | ポート | 用途 |
|---------|------|--------|------|
| proxy-svc | LoadBalancer | 25565 | 外部公開（プレイヤー接続） |
| lobby-svc | ClusterIP | 25565 | Velocity → ロビー |
| survival-svc | ClusterIP | 25565 | Velocity → サバイバル |

### リソース見積もり

| コンポーネント | CPU (request/limit) | RAM (request/limit) |
|---------------|--------------------|--------------------|
| Velocity | 0.25 / 0.5 | 512Mi / 512Mi |
| Lobby | 0.25 / 0.5 | 256Mi / 512Mi |
| Survival | 1 / 2 | 4Gi / 5Gi |
| mc-backup | 0.1 / 0.2 | 128Mi / 256Mi |
| exporter | 0.05 / 0.1 | 64Mi / 128Mi |
| **合計** | **~1.65 / ~3.3** | **~5Gi / ~6.4Gi** |

## ディレクトリ構成

```
kubernetes/
├── namespace.yaml                 # 既存流用
├── networkpolicy.yaml             # 全体共通（更新）
│
├── proxy/                         # Velocity（独立構成）
│   ├── kustomization.yaml
│   ├── statefulset.yaml
│   ├── service.yaml               # LoadBalancer :25565
│   ├── configmap.yaml             # velocity.toml
│   └── secret.yaml                # forwarding secret
│
├── paper-base/                    # Paper 共通テンプレート
│   ├── kustomization.yaml
│   ├── statefulset.yaml
│   ├── service.yaml               # ClusterIP :25565
│   ├── configmap.yaml             # 共通設定
│   └── secret.yaml                # RCON パスワード
│
└── overlays/
    ├── lobby/
    │   ├── kustomization.yaml     # namePrefix: lobby-
    │   └── patch-resources.yaml   # 256MB, PVC 1Gi, サイドカー無し
    │
    └── survival/
        ├── kustomization.yaml     # namePrefix: survival-
        ├── patch-resources.yaml   # 4GB, PVC 20Gi+50Gi
        ├── patch-plugins.yaml     # SPIGET_RESOURCES, サイドカー
        └── servicemonitor.yaml    # Prometheus 監視
```

### 既存ファイルとの関係

- 現在の `kubernetes/*.yaml`（フラット構成）は Phase 1 参照用として残す
- Phase 2 マニフェストは上記の新構成で独立管理

## CI パイプライン

### 検証内容（ミニマム）

1. **kustomize build**: 各 overlay が正しくビルドできるか
2. **kubeconform**: ビルド結果が K8s スキーマに準拠しているか

### 実行タイミング

- PR 作成時 + push 時
- main マージ前に全チェック pass 必須

### 将来追加予定

- kube-score（ベストプラクティスチェック）
- Trivy（セキュリティスキャン）

## 実装ステップ

1. ディレクトリ構成の作成
2. Velocity プロキシマニフェスト
3. Paper 共通テンプレート
4. Overlay 作成（lobby, survival）
5. CI ワークフロー（kustomize build + kubeconform）
6. ドキュメント更新

## 完了条件

- [ ] `kustomize build` が全 overlay で成功
- [ ] `kubeconform` がエラー 0 で pass
- [ ] CI が PR で自動実行される
- [ ] README に構成図と使い方が記載されている

## 将来の拡張

- クリエイティブサーバー追加（overlay 追加のみ）
- Headless Service + Pod DNS への移行
- CI に kube-score + Trivy 追加
- Phase 3: PostgreSQL + Redis + API Server
