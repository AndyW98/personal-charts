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

## The `.env` file

Marinara reads its server settings from a `.env` file (`KEY=value` lines, see
[`.env.example`](https://github.com/Pasta-Devs/Marinara-Engine/blob/main/.env.example)).
In the container it is `/app/data/.env`, inside the data volume. You can
leave that file alone, or have the chart manage it with `envFile`:

```sh
# Keep the file out of git and pass it at install time ...
helm upgrade --install marinara personal-charts/marinara-engine -f my-values.yaml \
  --set-file envFile.content=./marinara.env
# ... or store it in a Secret yourself and set envFile.existingSecret=marinara-dotenv
kubectl -n marinara create secret generic marinara-dotenv --from-file=.env=./marinara.env
```

On every pod start an init container copies the file to `/app/data/.env`,
replacing the previous copy, so edits made inside the pod don't survive a
restart. When the chart creates the Secret (`envFile.content`), changing the
content restarts the pod. With `envFile.existingSecret`, restart it yourself
after you update the Secret.

Environment variables win over `.env` entries. Everything the chart sets as an
env var (`PORT`, `HOST`, `DATA_DIR`, `config.*`, `adminSecret`,
`existingSecret`, `extraEnv`) therefore overrides the same key in the file. Set
`config.logLevel` / `config.logFormat` to `""` to control those from the file.

### Admin secret

`ADMIN_SECRET` unlocks privileged actions (backups, imports, cleanup, sidecar
installs and so on) from remote devices. You can put it in the `.env` file or
in `existingSecret`, or use `adminSecret`:

- `adminSecret.existingSecret` (+ `adminSecret.key`) reads it from a Secret.
- `adminSecret.generate: true` creates `<release>-marinara-engine-admin`
  with a random value. The value is kept on upgrades, and the Secret is kept on
  uninstall. Read it with
  `kubectl get secret <release>-marinara-engine-admin -o jsonpath='{.data.ADMIN_SECRET}' | base64 -d`.
  The value is reused through Helm's `lookup`, so tools that render without
  cluster access (`helm template`, Argo CD) create a new value on every render.
  With those, use `existingSecret`.

The `adminSecret` value is passed as an env var, so it wins over `ADMIN_SECRET`
in the `.env` file or in `existingSecret`.

## TLS

### At the ingress, with cert-manager

```yaml
ingress:
  enabled: true
  className: nginx
  hosts:
    - host: marinara.example.com
      paths:
        - path: /
          pathType: Prefix
  certManager:
    enabled: true
    clusterIssuer: letsencrypt-prod   # or issuer: <namespaced Issuer>
```

This adds the `cert-manager.io/cluster-issuer` (or `cert-manager.io/issuer`)
annotation. If `ingress.tls` is empty, it also adds a TLS entry for all ingress
hosts with Secret `ingress.certManager.secretName` (default
`<release>-marinara-engine-ingress-tls`). cert-manager's ingress-shim then issues the
certificate. If you list `ingress.tls` yourself, only the annotation is added.
In both cases the hosts become `https://` CSRF origins.

### In Marinara itself (end-to-end)

`tls.enabled: true` makes Marinara serve HTTPS on port 7860 (`SSL_CERT` /
`SSL_KEY`, mounted from a `kubernetes.io/tls` Secret). The Service port is
then named `https` with `appProtocol: https`, and the probes use HTTPS. The
certificate comes from:

1. `tls.existingSecret`, an existing TLS Secret, or
2. `tls.certManager.enabled: true`, a cert-manager `Certificate` from
   `tls.certManager.issuerRef` (cert-manager's CRDs must be installed), or
3. otherwise a self-signed certificate that the chart generates and keeps on
   upgrades, like the generated admin secret.

The certificate covers the Service DNS names, the ingress hosts and
`tls.dnsNames`. Marinara reads it only at startup, so restart the pod after a
renewal. For example, add `reloader.stakater.com/auto: "true"` to
`podAnnotations` if you run [Reloader](https://github.com/stakater/Reloader).

Behind an ingress, tell the controller to use HTTPS to the backend, e.g. for
ingress-nginx `nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"`. Both
TLS modes can be combined:

```yaml
ingress:
  enabled: true
  className: nginx
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
  hosts:
    - host: marinara.example.com
      paths:
        - path: /
          pathType: Prefix
  certManager:
    enabled: true
    clusterIssuer: letsencrypt-prod
tls:
  enabled: true
  certManager:
    enabled: true
    issuerRef:
      name: internal-ca
      kind: ClusterIssuer
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
| `config.logLevel` | `warn` | `LOG_LEVEL` (`""` leaves it to `.env`) |
| `config.logFormat` | `json` | `LOG_FORMAT` (`json` or `pretty`; `""` leaves it to `.env`) |
| `config.trustedHosts` | `[]` | Extra `TRUSTED_HOSTS` (ingress hosts are added automatically) |
| `config.csrfTrustedOrigins` | `[]` | Extra `CSRF_TRUSTED_ORIGINS` (ingress hosts are added automatically) |
| `config.ipAllowlist` | `[]` | `IP_ALLOWLIST` entries (IPs/CIDRs) |
| `config.env` | `{}` | Any other non-secret upstream setting, as `NAME: value` |
| `existingSecret` | `""` | Secret loaded via `envFrom` (`BASIC_AUTH_USER`, `BASIC_AUTH_PASS`, `ADMIN_SECRET`, `ENCRYPTION_KEY`, ...) |
| `envFile.content` | `""` | Inline `.env` contents (stored in a chart-managed Secret) |
| `envFile.existingSecret` / `envFile.key` | `""` / `.env` | Existing Secret holding the `.env` file |
| `adminSecret.existingSecret` / `adminSecret.key` | `""` / `ADMIN_SECRET` | Secret key passed as `ADMIN_SECRET` |
| `adminSecret.generate` | `false` | Generate and keep a random `ADMIN_SECRET` |
| `extraEnv` / `extraEnvFrom` | `[]` | Raw extra env / envFrom entries |
| `persistence.enabled` | `true` | Persist `/app/data` (an `emptyDir` is used when disabled) |
| `persistence.existingClaim` | `""` | Use an existing PVC |
| `persistence.storageClass` | `""` | StorageClass (`-` for `""`) |
| `persistence.size` | `10Gi` | PVC size |
| `persistence.retain` | `true` | Keep the PVC on uninstall |
| `service.type` / `service.port` | `ClusterIP` / `7860` | Service settings |
| `ingress.*` | disabled | Standard ingress settings |
| `ingress.certManager.enabled` | `false` | Add cert-manager issuer annotation and default TLS entry |
| `ingress.certManager.clusterIssuer` / `issuer` | `""` | cert-manager ClusterIssuer or Issuer (exactly one) |
| `ingress.certManager.secretName` | `""` | TLS Secret name (default `<fullname>-ingress-tls`) |
| `tls.enabled` | `false` | Serve HTTPS from Marinara itself |
| `tls.existingSecret` | `""` | Existing `kubernetes.io/tls` Secret |
| `tls.dnsNames` | `[]` | Extra certificate DNS names |
| `tls.certManager.enabled` | `false` | Issue the certificate with a cert-manager `Certificate` |
| `tls.certManager.issuerRef` | `{name: "", kind: ClusterIssuer}` | Issuer for that Certificate |
| `tls.certManager.duration` / `renewBefore` | `""` | Optional Certificate lifetimes |
| `tls.selfSignedDays` | `3650` | Validity of the generated self-signed certificate |
| `resources` | 100m / 512Mi request, 4Gi limit | Container resources (add `nvidia.com/gpu` for local models) |
| `runtimeClassName` | `""` | e.g. `nvidia` for GPU nodes |
| `podSecurityContext` / `securityContext` | non-root 1000, drop ALL | Pod/container security |
| `extraVolumes` / `extraVolumeMounts` | `[]` | Extra volumes |
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
