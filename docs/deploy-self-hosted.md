# Deploy self-hosted (WSL2 + k3d + Cloudflare Tunnel)

Hướng dẫn deploy lumin-studio lên cluster k3d chạy trên máy PC Windows (WSL2 Ubuntu),
public ra internet qua Cloudflare Tunnel với domain `luminstudio.vn`.

## Kiến trúc

```
git push main
   └─ GitHub Actions (self-hosted runner "Luca" trên PC, x86_64)
        ├─ bazelisk build api-gateway (amd64) + docker build worker-3d
        ├─ k3d image import → cluster "luminstudio"
        └─ kubectl apply -k infra/k8s/overlays/prod  +  rollout

internet → api.luminstudio.vn
   → Cloudflare edge → cloudflared (systemd, token tunnel) trên PC
   → http://localhost:80 (Traefik / k3d serverlb)
   → Ingress khớp Host → Service → Pod
```

Không dùng registry: ảnh build native amd64 ngay trên PC rồi nạp thẳng vào node bằng
`k3d image import`. Cluster chỉ có 1 node nên đủ.

## Thành phần đã có sẵn trên PC (`ssh pc-server`)

- k3d cluster `luminstudio` (context `k3d-luminstudio`, k3s v1.35.5), Traefik map host `:80/:443`.
- `cloudflared.service` (token tunnel, routing cấu hình trên Cloudflare dashboard).
- GitHub Actions runner "Luca" đã connect repo `huongnguyenduc/luminstudio-platform`.
- `docker`, `k3d`, `kubectl`.

**Cần cài thêm:** `bazelisk` (để build ảnh api-gateway).

## 1. Setup một lần trên PC

### 1.1 Cài bazelisk cho runner

```bash
ssh pc-server
sudo curl -fsSL -o /usr/local/bin/bazelisk \
  https://github.com/bazelbuild/bazelisk/releases/latest/download/bazelisk-linux-amd64
sudo chmod +x /usr/local/bin/bazelisk
bazelisk version    # bazelisk đọc .bazelversion trong repo
```

Runner chạy bằng systemd nên `/usr/local/bin` phải nằm trong PATH của service. Kiểm tra:

```bash
sudo systemctl show actions.runner.huongnguyenduc-luminstudio-platform.Luca.service -p Environment
```

Nếu thiếu, thêm PATH vào `~/actions-runner/.env` rồi cài lại service:

```bash
echo 'PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin' >> ~/actions-runner/.env
cd ~/actions-runner && sudo ./svc.sh stop && sudo ./svc.sh start
```

> Lần build Bazel đầu sẽ lâu (tải toolchain) và tốn vài GB cache trong `~/.cache/bazel`.

### 1.2 Lưu ý KUBECONFIG

`.bashrc` chỉ set `KUBECONFIG` cho shell tương tác. Runner và SSH non-interactive thì
không có — vì vậy `deploy-prod.sh` tự chạy `export KUBECONFIG=$(k3d kubeconfig write luminstudio)`.
Không cần làm gì thêm.

## 2. Cấu hình Cloudflare Tunnel (dashboard)

Tunnel hiện chạy bằng **token** nên routing nằm trên dashboard, không có `config.yml`.

1. Vào **Cloudflare Zero Trust → Networks → Tunnels** → chọn tunnel đang chạy.
2. Tab **Public Hostnames → Add a public hostname**:
   - **Subdomain:** `api` — **Domain:** `luminstudio.vn`
   - **Service:** Type `HTTP`, URL `localhost:80`
   - (Additional settings không cần bật TLS verify vì origin là HTTP nội bộ.)
3. Lặp lại cho các host khác nếu muốn (vd `admin.luminstudio.vn`).

Cloudflare tự tạo bản ghi DNS (CNAME proxied) cho mỗi hostname. Traefik phân biệt theo
Host header nên tất cả trỏ chung `localhost:80`.

> Ingress của MinIO console / Meilisearch trong base vẫn dùng host `*.local` (chỉ dùng nội
> bộ). Muốn public admin thì thêm Ingress host thật rồi khai báo public hostname tương ứng.

## 3. Deploy

### Cách A — qua CI (khuyến nghị)

Push vào `main` chạm `services/**`, `packages/**` hoặc `infra/k8s/**` sẽ tự kích hoạt
workflow `deploy-prod`. Hoặc chạy tay: **Actions → deploy-prod → Run workflow**
(có thể nhập `image_tag` để re-deploy/rollback).

Workflow dùng `IMAGE_TAG = commit sha` → mỗi lần deploy là một tag bất biến.

### Cách B — chạy tay trên PC

```bash
ssh pc-server
cd ~/path/to/luminstudio-platform   # repo checkout của runner: ~/actions-runner/_work/...
bash infra/scripts/deploy-prod.sh                 # tag mặc định "prod"
# hoặc deploy một tag cụ thể:
IMAGE_TAG=$(git rev-parse --short HEAD) bash infra/scripts/deploy-prod.sh
# chỉ apply lại manifest, không build:
SKIP_BUILD=1 bash infra/scripts/deploy-prod.sh
```

## 4. Secrets

Overlay `prod` thay thế secret dev (plaintext trong `base`) bằng giá trị đọc từ
`infra/k8s/overlays/prod/secrets/*.env`. Các file `.env` **không commit** (đã gitignore).

**Nguồn sự thật của secrets** nằm ở `~/.config/lumin/prod-secrets/` (đổi bằng env
`LUMIN_SECRETS_DIR`), **ngoài** mọi checkout. Lý do: runner CI dùng workspace riêng
(`~/actions-runner/_work/...`) nên file trong overlay không tồn tại ở đó — nếu sinh mới
mỗi lần thì mật khẩu sẽ lệch với data Postgres/MinIO đã khởi tạo và pod không auth được.
`deploy-prod.sh` sinh ngẫu nhiên (`openssl rand`) vào `persist_dir` ở lần đầu, rồi **copy**
sang overlay để kustomize đọc. Muốn đặt tay: ghi vào `~/.config/lumin/prod-secrets/*.env`
(tham khảo `secrets/*.env.example`).

Đổi secret sau này: sửa file `.env` rồi chạy lại deploy (`SKIP_BUILD=1` đủ). Lưu ý
Postgres/MinIO đã khởi tạo data với mật khẩu cũ — đổi mật khẩu cần thao tác thêm trên DB,
không chỉ đổi secret.

## 5. Rollback

```bash
# Quay về tag cũ (CI dùng sha):
IMAGE_TAG=<sha-cũ> bash infra/scripts/deploy-prod.sh
# hoặc undo nhanh deployment:
kubectl --context k3d-luminstudio -n prod rollout undo deploy/api-gateway
```

## 6. Verify

```bash
# Trong cluster:
kubectl --context k3d-luminstudio -n prod get deploy,pods,ingress
# Qua Traefik nội bộ (giả Host header):
curl -H 'Host: api.luminstudio.vn' http://localhost/healthz
# Qua internet:
curl https://api.luminstudio.vn/healthz
```

## 7. Troubleshooting

| Triệu chứng | Nguyên nhân / khắc phục |
|---|---|
| `connection to server localhost:8080 refused` | KUBECONFIG chưa set. Dùng `export KUBECONFIG=$(k3d kubeconfig write luminstudio)` hoặc `kubectl --context k3d-luminstudio`. |
| `bazelisk: command not found` trong CI | PATH runner thiếu `/usr/local/bin` (xem 1.1). |
| Pod `ErrImageNeverPull` / `ImagePullBackOff` | Ảnh chưa import đúng tag. Chạy `k3d image import lumin/...:<tag> --cluster luminstudio`. |
| `exec format error` trong pod | Build sai kiến trúc. PC là amd64 — phải dùng target `...-image-load-amd64`. |
| 502 từ Cloudflare | cloudflared chưa trỏ `localhost:80`, hoặc Traefik/Ingress chưa có host khớp. |
| Mất data sau khi xoá pod | Postgres/MinIO/Meili là StatefulSet trên `local-path` (đĩa node). Xoá cluster = mất data → cần backup riêng. |

## 8. Việc nên làm tiếp (chưa nằm trong scope này)

- Backup định kỳ Postgres + MinIO (cluster 1 node, không HA).
- Bảo vệ token cloudflared (hiện lộ trong `ps`/systemd unit).
- Nếu muốn deploy chuẩn registry: đẩy ảnh lên GHCR, đổi `imagePullPolicy`/`imagePullSecret`.
