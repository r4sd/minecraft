# SealedSecrets for Minecraft Stack

このディレクトリには、`minecraft` namespace で使用する秘密情報を Bitnami SealedSecrets で暗号化したマニフェストを配置する。

`homelab-infra` の SealedSecrets コントローラ (bitnami.com/v1alpha1) が cluster 内で復号して通常の Secret を生成する。**平文の Secret は絶対にコミットしない**。

## 管理対象 Secret

| Secret 名 | namespace | キー | 用途 |
|----------|-----------|-----|------|
| `forwarding-secret` | `minecraft` | `forwarding.secret` | Velocity ↔ Paper の modern forwarding 共有秘密 |
| `paper-secrets` | `minecraft` | `RCON_PASSWORD` | Paper サーバーの RCON 認証（mc-backup / minecraft-exporter サイドカーから localhost で参照） |

## 暗号化手順

`kubeseal` CLI と homelab-infra クラスタへの kubectl アクセスが必要。

### 1. forwarding-secret

```bash
# 強いランダム文字列を生成 (Velocity 推奨: 24文字以上のランダム英数字)
SECRET=$(openssl rand -base64 32)

# 平文 Secret を一時的に生成 → kubeseal で暗号化
kubectl create secret generic forwarding-secret \
  --namespace minecraft \
  --from-literal=forwarding.secret="$SECRET" \
  --dry-run=client -o yaml \
  | kubeseal --format yaml \
  > kubernetes/sealed-secrets/forwarding-secret.yaml
```

### 2. paper-secrets

```bash
RCON_PASSWORD=$(openssl rand -base64 24)

kubectl create secret generic paper-secrets \
  --namespace minecraft \
  --from-literal=RCON_PASSWORD="$RCON_PASSWORD" \
  --dry-run=client -o yaml \
  | kubeseal --format yaml \
  > kubernetes/sealed-secrets/paper-secrets.yaml
```

## 適用

ArgoCD で `kubernetes/sealed-secrets/` を別 Application として管理する、または直接 apply する:

```bash
kubectl apply -f kubernetes/sealed-secrets/
```

復号後の Secret は kustomize で参照される (`paper-base/statefulset.yaml` の `envFrom`、`proxy/deployment.yaml` の `volumeMounts`)。

## ローテーション

1. 上記コマンドを再実行して新しい暗号化済みマニフェストを生成
2. コミット & ArgoCD 同期 (または `kubectl apply`)
3. Paper / Velocity Pod を再起動 (`kubectl rollout restart`)

forwarding-secret を変更する場合は **Velocity と Paper を同時に再起動** すること。秘密が一致しないと Velocity 接続が拒否される。
