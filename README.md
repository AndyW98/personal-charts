# personal-charts

Helm charts for the applications I self-host on my Kubernetes cluster.
Charts are linted, validated and packaged in GitLab CI, and every new chart
version merged to the default branch is published to this project's
[GitLab Helm package registry](https://docs.gitlab.com/ee/user/packages/helm_repository/).

## Layout

```
.
├── charts/                 # one directory per chart
│   └── <app>/
│       ├── Chart.yaml
│       ├── values.yaml
│       ├── templates/
│       └── ci/             # optional *-values.yaml files used in CI validation
├── scripts/
│   └── publish-charts.sh   # packages + uploads new chart versions
├── ct.yaml                 # chart-testing config
├── .yamllint.yaml
└── .gitlab-ci.yml
```

## Using the charts

Add the repository (use a personal/deploy token with `read_api`, or
`read_package_registry` for a deploy token):

```sh
helm repo add personal-charts \
  https://<gitlab-host>/api/v4/projects/<project-id>/packages/helm/stable \
  --username <username> --password <token>
helm repo update
helm search repo personal-charts
```

Install / upgrade an app:

```sh
helm upgrade --install <release> personal-charts/<chart> \
  --namespace <ns> --create-namespace \
  -f my-values.yaml
```

If OCI publishing is enabled in CI (see below) you can also pull directly:

```sh
helm install <release> oci://<registry-host>/<group>/personal-charts/charts/<chart> --version <x.y.z>
```

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
  change to a chart** — merge requests fail `ct lint` otherwise, and the
  publish job skips versions that already exist in the registry.
- Set `appVersion` to the upstream application version being deployed.
- Keep secrets out of `values.yaml`; reference existing `Secret`s instead.
- Add `charts/<app>/ci/*-values.yaml` files to exercise non-default
  configurations in CI.

## CI pipeline

| Stage      | Job        | What it does                                                                       | Runs on               |
|------------|------------|------------------------------------------------------------------------------------|-----------------------|
| `lint`     | `lint`     | `yamllint` + `ct lint`; on MRs only changed charts, and a version bump is required | MRs, branches, tags   |
| `validate` | `validate` | `helm template` each chart (default + `ci/*-values.yaml`) through `kubeconform`    | MRs, branches, tags   |
| `package`  | `package`  | `helm package` every chart, stored as job artifacts                                | MRs, branches, tags   |
| `publish`  | `publish`  | Uploads any chart version not already in the registry                              | default branch only   |

Publishing uses the built-in `CI_JOB_TOKEN`, so no extra secrets are needed.

Useful CI variables:

- `KUBERNETES_VERSION` — version manifests are validated against; keep in sync
  with the cluster.
- `HELM_CHANNEL` — registry channel to publish to (default `stable`).
- `OCI_REGISTRY` — set (e.g. `$CI_REGISTRY_IMAGE/charts`) to also push charts
  to the GitLab container registry as OCI artifacts.

## Local checks

```sh
ct lint --config ct.yaml --all          # needs chart-testing installed
helm lint charts/*
DRY_RUN=1 CI_API_V4_URL=... CI_PROJECT_ID=... CI_JOB_TOKEN=... scripts/publish-charts.sh
```
