# marinara-engine

[Marinara Engine](https://github.com/Pasta-Devs/Marinara-Engine) is a self-hosted,
AI-powered chat, roleplay and game engine. You bring your own LLM connections
(OpenAI-compatible APIs, OpenRouter, local models and so on) and it serves the
web UI and API from one Node.js process on port 7860.

This chart runs the official image `ghcr.io/pasta-devs/marinara-engine`.

## Install

```sh
helm repo add personal-charts https://andyw98.github.io/personal-charts
helm upgrade --install marinara personal-charts/marinara-engine \
  --namespace marinara --create-namespace -f my-values.yaml
```

## How it runs

- **Single replica with a `Recreate` rollout.** Everything lives as files under
  `/app/data` (chats, characters, uploads, generated media, downloaded models
  and the auto-generated API-key encryption key), so two pods must never share the volume.
- **Persistence** is a chart-managed `ReadWriteOnce` PVC (10Gi), or set
  `persistence.existingClaim`. The PVC is kept on `helm uninstall` unless
  `persistence.retain=false`. Local models and embeddings need more space.
- **Non-root.** The pod runs as uid/gid 1000 (`node`) with `fsGroup: 1000`.
  The upstream entrypoint chowns `/app/data` only when started as root; here
  `fsGroup` handles volume ownership instead.
- **Health** is checked at `/api/health`, which Marinara serves without auth.

## Access and login

Marinara locks itself down by default:

- Clients on loopback (including `kubectl port-forward`) get full access with no login.
- Until a login exists, every other client (including traffic through the
  ingress) only gets a one-time setup page. The setup code is in the pod logs:
  `kubectl logs deploy/<release>-marinara-engine | grep "setup code"`.
- Instead of the setup code, you can put `BASIC_AUTH_USER` and
  `BASIC_AUTH_PASS` in a Secret and reference it with `existingSecret`.
- Requests whose `Host` header isn't trusted are rejected. Ingress hosts are
  added to `TRUSTED_HOSTS` and `CSRF_TRUSTED_ORIGINS` automatically, using
  `https://` for hosts listed in `ingress.tls`. If TLS terminates somewhere else
  (for example Cloudflare), add the origin to `config.csrfTrustedOrigins`.

Example Secret:

```sh
kubectl -n marinara create secret generic marinara-env \
  --from-literal=BASIC_AUTH_USER=me \
  --from-literal=BASIC_AUTH_PASS="$(openssl rand -base64 24)" \
  --from-literal=ADMIN_SECRET="$(openssl rand -hex 32)" \
  --from-literal=ENCRYPTION_KEY="$(openssl rand -hex 32)"
```

```yaml
existingSecret: marinara-env
ingress:
  enabled: true
  className: nginx
  annotations:
    nginx.ingress.kubernetes.io/proxy-read-timeout: "1800"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "1800"
    nginx.ingress.kubernetes.io/proxy-body-size: "100m"
  hosts:
    - host: marinara.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: marinara-tls
      hosts:
        - marinara.example.com
```

> If you set `ENCRYPTION_KEY` after first start, provider API keys saved with
> the auto-generated key (`/app/data/.encryption-key`) may no longer decrypt.
> Set it on first install, or leave it unset.

## Values

| Key | Default | Description |
|-----|---------|-------------|
| `image.repository` | `ghcr.io/pasta-devs/marinara-engine` | Image repository |
| `image.tag` | `""` (appVersion) | Image tag |
| `image.variant` | `""` | `lite` uses the smaller image without the local sidecar model, embeddings / memory recall or local Whisper |
| `config.timezone` | `""` | IANA timezone (`TZ`) for server-side schedules |
| `config.logLevel` | `warn` | `LOG_LEVEL` |
| `config.logFormat` | `json` | `LOG_FORMAT` (`json` or `pretty`) |
| `config.trustedHosts` | `[]` | Extra `TRUSTED_HOSTS` (ingress hosts are added automatically) |
| `config.csrfTrustedOrigins` | `[]` | Extra `CSRF_TRUSTED_ORIGINS` (ingress hosts are added automatically) |
| `config.ipAllowlist` | `[]` | `IP_ALLOWLIST` entries (IPs/CIDRs) |
| `config.env` | `{}` | Any other non-secret upstream setting, as `NAME: value` |
| `existingSecret` | `""` | Secret loaded via `envFrom` (`BASIC_AUTH_USER`, `BASIC_AUTH_PASS`, `ADMIN_SECRET`, `ENCRYPTION_KEY`, ...) |
| `extraEnv` / `extraEnvFrom` | `[]` | Raw extra env / envFrom entries |
| `persistence.enabled` | `true` | Persist `/app/data` (an `emptyDir` is used when disabled) |
| `persistence.existingClaim` | `""` | Use an existing PVC |
| `persistence.storageClass` | `""` | StorageClass (`-` for `""`) |
| `persistence.size` | `10Gi` | PVC size |
| `persistence.retain` | `true` | Keep the PVC on uninstall |
| `service.type` / `service.port` | `ClusterIP` / `7860` | Service settings |
| `ingress.*` | disabled | Standard ingress settings |
| `resources` | 100m / 512Mi request, 4Gi limit | Container resources (add `nvidia.com/gpu` for local models) |
| `runtimeClassName` | `""` | e.g. `nvidia` for GPU nodes |
| `podSecurityContext` / `securityContext` | non-root 1000, drop ALL | Pod/container security |
| `extraVolumes` / `extraVolumeMounts` | `[]` | Extra volumes, e.g. a TLS cert for `SSL_CERT`/`SSL_KEY` |
| `nodeSelector` / `tolerations` / `affinity` | `{}` / `[]` / `{}` | Scheduling |

The full list of upstream settings is in
[`.env.example`](https://github.com/Pasta-Devs/Marinara-Engine/blob/main/.env.example).

## Notes

- The root filesystem stays writable (`readOnlyRootFilesystem: false`) because
  Marinara installs some optional components at runtime outside `/app/data`.
- Features that use the `bubblewrap` sandbox (such as `mari db transform`) may
  not work under the restricted pod security context.
- Upstream upgrades container installs by pulling a new image. With this
  chart, upgrade by moving to a newer chart version or setting `image.tag`.
