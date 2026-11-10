# personal-charts

Helm charts for the applications I self-host on my Kubernetes cluster.
GitHub Actions lints and tests charts on pull requests. When a new chart
version is merged to `main`, it is published to:

- **A classic Helm repository** served from GitHub Pages (`gh-pages` branch),
  with each chart package attached to a GitHub release.
- **GHCR** as an OCI artifact at `oci://ghcr.io/andyw98/charts/<chart>`.

## Charts

| Chart | App | Description |
|-------|-----|-------------|
| [`argentum-engine`](charts/argentum-engine) | [Argentum Engine](https://github.com/wingedsheep/argentum-engine) | Magic: The Gathering rules engine + web client with built-in or LLM AI opponents |
| [`docker-registry`](charts/docker-registry) | [Distribution](https://distribution.github.io/distribution/) | Private Docker / OCI image registry |
| [`dokuwiki`](charts/dokuwiki) | [DokuWiki](https://www.dokuwiki.org) | Database-free wiki (LinuxServer.io image) |
| [`filerise`](charts/filerise) | [FileRise](https://github.com/error311/FileRise) | Web file manager |
| [`foundryvtt`](charts/foundryvtt) | [Foundry VTT](https://foundryvtt.com) | Virtual tabletop (privately built image) |
| [`gitea`](charts/gitea) | [Gitea](https://gitea.com) | Lightweight Git service, single pod |
| [`heimdall`](charts/heimdall) | [Heimdall](https://heimdall.site) | Application dashboard (LinuxServer.io image) |
| [`homelab-core`](charts/homelab-core) | — | cert-manager ClusterIssuer/Certificates, shared PersistentVolumes, extra objects |
| [`jellyfin`](charts/jellyfin) | [Jellyfin](https://jellyfin.org) | Media server (LinuxServer.io image) |
| [`marinara-engine`](charts/marinara-engine) | [Marinara Engine](https://github.com/Pasta-Devs/Marinara-Engine) | Self-hosted AI chat, roleplay and game engine |
| [`opencode-kali`](charts/opencode-kali) | [opencode](https://opencode.ai) | `opencode serve` in a Kali Linux container (custom image from `images/opencode-kali`) |
| [`romm`](charts/romm) | [RomM](https://romm.app) | ROM manager and web emulator, with an optional bundled MariaDB |

## Layout

```
.
├── charts/                     # one directory per chart
│   └── <app>/
│       ├── Chart.yaml
│       ├── values.yaml
│       ├── templates/
│       └── ci/                 # optional *-values.yaml files used in CI
├── images/                     # custom images for charts that need one
│   └── <chart>/
│       ├── Dockerfile          # published as ghcr.io/andyw98/<chart>:<appVersion>
│       └── ci-build-args       # optional build args for the CI (kind) build
├── k3s/                        # docker-compose k3s node (server or agent), see k3s/README.md
├── ct.yaml                     # chart-testing config
├── .yamllint.yaml              # YAML lint rules for Chart.yaml / values.yaml
└── .github/workflows/
    ├── lint-test.yaml          # PRs: lint, validate, install into kind
    ├── images.yaml             # build/push images/<chart> to GHCR
    └── release.yaml            # main: package + publish new versions
```

## Using the charts

From the Helm repository (GitHub Pages):

```sh
helm repo add personal-charts https://andyw98.github.io/personal-charts
helm repo update
helm search repo personal-charts

helm upgrade --install <release> personal-charts/<chart> \
  --namespace <ns> --create-namespace \
  -f my-values.yaml
```

Or directly from GHCR (no `repo add` needed):

```sh
helm upgrade --install <release> oci://ghcr.io/andyw98/charts/<chart> \
  --version <x.y.z> --namespace <ns> --create-namespace -f my-values.yaml
```

> If the repository or GHCR packages are private, GitHub Pages needs to be
> accessible to the cluster and `helm registry login ghcr.io` needs a token
> with `read:packages`.

## Adding a chart

```sh
helm create charts/<app>
# edit Chart.yaml, values.yaml, templates/
helm lint charts/<app>
helm template <app> charts/<app> | less
```

Conventions:

- Chart directory name == `name` in `Chart.yaml`.
- Follow [SemVer](https://semver.org/) for `version`. **Bump `version` on every
  change to a chart.** PRs fail `ct lint` without a bump, and the release
  workflow skips versions that already have a release.
- Set `appVersion` to the upstream application version being deployed.
- Keep secrets out of `values.yaml`; reference existing `Secret`s instead.
- Add `charts/<app>/ci/*-values.yaml` files to exercise non-default
  configurations in CI (used by both kubeconform validation and `ct install`).

## CI

| Workflow         | Trigger                          | What it does                                                                                                                                      |
|------------------|----------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------|
| `lint-test.yaml` | PRs touching `charts/**`         | For changed charts only: `ct lint` (helm lint, yamllint, version-bump check), render + validate with `kubeconform`, then `ct install` into a kind cluster |
| `release.yaml`   | Push to `main` touching `charts/**` | [chart-releaser](https://github.com/helm/chart-releaser-action) creates a `<chart>-<version>` GitHub release and updates `index.yaml` on `gh-pages`; new packages are also pushed to GHCR |

Both workflows use the built-in `GITHUB_TOKEN`, so no secrets need to be configured.

`KUBERNETES_VERSION` in `lint-test.yaml` sets the Kubernetes version manifests
are validated against; keep it in sync with the cluster.

### Custom images

Some charts run an image built in this repository from `images/<chart>/Dockerfile`:

- `images.yaml` builds it on PRs (without pushing) and publishes it on pushes
  to `main`, every Monday, and on manual runs. It's tagged
  `ghcr.io/andyw98/<chart>:<appVersion>`, `:<appVersion>-<YYYYMMDD>` and
  `:latest`, and the chart's `appVersion` is passed in as the `APP_VERSION`
  build arg.
- `lint-test.yaml` builds a CI copy (using `images/<chart>/ci-build-args`),
  tags it `<image.repository>:ci` and loads it into kind before `ct install`.
  The chart's `ci/*-values.yaml` should use `image.tag: ci` and
  `image.pullPolicy: Never`.
- The chart release and the image build run as separate workflows, so a new
  chart version can be published a few minutes before its image exists.
- New GHCR packages are private. Make them public or give the cluster an
  image pull secret.

### One-time repository setup

1. Make `main` the default branch.
2. **Settings → Actions → General → Workflow permissions**: allow
   *Read and write permissions* (needed to create releases, push `gh-pages`
   and publish packages).
3. After the first release run creates the `gh-pages` branch:
   **Settings → Pages** → *Deploy from a branch* → `gh-pages` / `/ (root)`.
4. Optional: protect `main` and require the *Lint and test charts* check.

## Running a cluster

[`k3s/`](k3s) holds a `docker-compose.yml` that runs a k3s node on a Docker
host, switchable between control-plane and agent roles with `K3S_ROLE`. See
[`k3s/README.md`](k3s/README.md).

## Local checks

```sh
helm lint charts/<app>
ct lint --config ct.yaml --charts charts/<app>      # needs chart-testing
helm template <app> charts/<app> | kubeconform -strict -ignore-missing-schemas -summary
```
