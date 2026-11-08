# opencode-kali

Runs [opencode](https://opencode.ai)'s headless server (`opencode serve`)
inside a Kali Linux rolling container. The agent then works with Kali's
tooling against whatever you point it at. Use it only on systems you're
authorized to test.

The image is built from [`images/opencode-kali`](../../images/opencode-kali) in
this repo and published as `ghcr.io/andyw98/opencode-kali:<opencode version>`.
By default it includes Kali's `kali-linux-headless` tool set.

## Install

1. Create the server password Secret (required), plus your LLM provider keys:

   ```sh
   kubectl create namespace opencode
   kubectl -n opencode create secret generic opencode-auth \
     --from-literal=OPENCODE_SERVER_PASSWORD="$(openssl rand -base64 24)"
   kubectl -n opencode create secret generic opencode-providers \
     --from-literal=ANTHROPIC_API_KEY=...
   ```

2. Install:

   ```sh
   helm repo add personal-charts https://andyw98.github.io/personal-charts
   helm upgrade --install opencode personal-charts/opencode-kali -n opencode \
     --set auth.existingSecret=opencode-auth \
     --set envFromSecret=opencode-providers
   ```

   The GHCR package is private when first published. Either make it public
   (GitHub → Packages → opencode-kali → Package settings) or add an
   `imagePullSecrets` entry with a token that has `read:packages`.

3. Connect:

   ```sh
   kubectl -n opencode port-forward svc/opencode-opencode-kali 4096:4096
   export OPENCODE_SERVER_PASSWORD=...
   opencode attach http://127.0.0.1:4096 --dir /workspace
   ```

## How it runs

- `opencode serve --hostname 0.0.0.0 --port 4096` as a single replica with a
  `Recreate` rollout.
- **Auth:** HTTP basic auth with username `auth.username` (default `opencode`)
  and the password from `auth.existingSecret`. The chart refuses to render
  without that Secret unless you set `auth.enabled=false`. Every API route
  needs the password, so the probes are TCP checks.
- **Storage:** one PVC (20Gi), mounted twice:
  - `/home/kali` holds opencode's config, provider logins
    (`~/.local/share/opencode`), sessions and caches.
  - `/workspace` is the server's working directory. Clone projects here.
- **Config:** `config` is rendered to `opencode.json` and passed with
  `OPENCODE_CONFIG`. The config files in the persisted home directory and in
  each project are still read too.
- Self-update is disabled (`OPENCODE_DISABLE_AUTOUPDATE`). Upgrade by bumping
  the chart, which sets the image tag from `appVersion`.

## Root, raw sockets and installing packages

By default the container runs as `kali` (uid 1000) with every capability
dropped and no privilege escalation. Under those settings, tools that need
raw sockets (for example nmap SYN or OS scans, or packet capture) fail, and
so does `apt install`. Kubernetes only gives added capabilities to root
processes, so to allow these, run as root and add only the capabilities you need:

```yaml
podSecurityContext:
  runAsNonRoot: false
  runAsUser: 0
  runAsGroup: 0
  fsGroup: 1000
securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop: [ALL]
    add: [NET_RAW, NET_ADMIN, CHOWN, DAC_OVERRIDE, FOWNER, SETUID, SETGID]
```

The agent then has root inside the container, so keep the server password
strong and the Service off the public internet.

## Values

| Key | Default | Description |
|-----|---------|-------------|
| `image.repository` | `ghcr.io/andyw98/opencode-kali` | Image repository |
| `image.tag` | `""` (appVersion) | Image tag |
| `auth.enabled` | `true` | Require `OPENCODE_SERVER_PASSWORD` |
| `auth.existingSecret` | `""` | Secret holding the password (required when enabled) |
| `auth.passwordKey` | `OPENCODE_SERVER_PASSWORD` | Key in that Secret |
| `auth.username` | `opencode` | Basic-auth username |
| `envFromSecret` | `""` | Secret loaded via `envFrom` (provider API keys) |
| `server.port` | `4096` | Listen port |
| `server.cors` | `[]` | Extra CORS origins (`--cors`) |
| `server.extraArgs` | `[]` | Extra `opencode serve` arguments |
| `config` | `{}` | `opencode.json` contents |
| `env` / `extraEnv` / `extraEnvFrom` | | Extra environment |
| `persistence.*` | enabled, 20Gi, retained | Home + workspace volume |
| `service.*`, `ingress.*` | ClusterIP 4096, ingress off | Networking |
| `podSecurityContext` / `securityContext` | non-root 1000, drop ALL | See above |
| `resources` | 250m / 512Mi request, 4Gi limit | Container resources |
| `extraVolumes` / `extraVolumeMounts` | `[]` | e.g. SSH keys or wordlists |
| `nodeSelector` / `tolerations` / `affinity` | | Scheduling |

## Image

[`images/opencode-kali/Dockerfile`](../../images/opencode-kali/Dockerfile) is
built by `.github/workflows/images.yaml`:

- `APP_VERSION` (the opencode release) comes from this chart's `appVersion`.
- `KALI_PACKAGES` sets the Kali packages to install. The default is
  `kali-linux-headless`. Use `kali-linux-large` for more tools, or `""` for a
  minimal image (CI uses the minimal one for `ct install`).
- The image is rebuilt weekly so the Kali rolling packages stay current. The
  `<version>` tag moves to each rebuild, and `<version>-<YYYYMMDD>` tags stay
  fixed.
