# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this repo is

A personal Helm chart repository. Each chart deploys one self-hosted
application to the owner's Kubernetes cluster. GitHub Actions lints and tests
charts on PRs, and on merge to `main` publishes new chart versions as GitHub
releases with a Helm repo index on GitHub Pages (`gh-pages`), plus OCI
artifacts on `ghcr.io/andyw98/charts`. See `README.md` for consumer-facing usage.

## Layout

- `charts/<app>/` — one chart per app. Directory name must equal `name` in `Chart.yaml`.
- `charts/<app>/ci/*-values.yaml` — extra value sets used by kubeconform validation and `ct install` in CI.
- `k3s/` — docker-compose k3s node (`K3S_ROLE=server|agent`), documented in `k3s/README.md`. Not a chart; no CI.
- `ct.yaml` — chart-testing config; `.yamllint.yaml` — YAML lint rules for `Chart.yaml`/`values.yaml`.
- `.github/workflows/lint-test.yaml` — PRs: `ct lint`, kubeconform validation, `ct install` into kind (changed charts only).
- `.github/workflows/release.yaml` — push to `main`: chart-releaser (GitHub releases + `gh-pages` index) and OCI push to GHCR.
- `images/<chart>/Dockerfile` — custom image for a chart, published by `.github/workflows/images.yaml` as
  `ghcr.io/andyw98/<chart>:<appVersion>`. The chart's `appVersion` is passed as the `APP_VERSION` build arg, so the
  Dockerfile must install that version from `ARG APP_VERSION`. `images/<chart>/ci-build-args` (KEY=value lines) slims
  the CI build that `lint-test.yaml` loads into kind as `<image.repository>:ci`.

## Rules when changing charts

- **Always bump `version` in `Chart.yaml`** for any change inside a chart directory
  (patch for fixes/tweaks, minor for new features/values, major for breaking
  value or resource changes). CI rejects MRs without a bump, and an unbumped
  version will never be republished.
- Update `appVersion` when changing the deployed upstream image version, and leave
  `image.tag` defaulting to `""` so it falls back to `.Chart.AppVersion`.
- Never commit secrets, tokens, or real passwords in `values.yaml` or `ci/` files.
  Use `existingSecret`-style values that reference Secrets created out of band.
- Prefer standard Helm conventions (`helm create` scaffolding): `_helpers.tpl`
  name/label helpers, `app.kubernetes.io/*` labels, configurable
  `resources`, `nodeSelector`, `tolerations`, `affinity`, `podSecurityContext`,
  `securityContext`, `ingress`, `persistence`.
- Set sensible secure defaults: `runAsNonRoot`, drop all capabilities,
  `readOnlyRootFilesystem` where the app allows it.
- Pin chart dependencies to exact versions in `Chart.yaml`; don't commit the
  downloaded `charts/<app>/charts/*.tgz` (gitignored).
- Keep manifests valid for the `KUBERNETES_VERSION` set in `.github/workflows/lint-test.yaml`.
- For charts with a custom image, bump `appVersion` (and the chart `version`) to upgrade the
  app; keep the Dockerfile's `ARG APP_VERSION` default in sync. Their `ci/*-values.yaml` must set
  `image.tag: ci` and `image.pullPolicy: Never`.
- When a chart refuses to render without a required value (e.g. a password Secret),
  every `ci/*-values.yaml` must supply or disable it: CI renders only those files when present.
- Charts must install cleanly into a bare kind cluster with default values (or
  `ci/*-values.yaml`), since `ct install` runs on every PR. Make optional
  dependencies (ingress, CRD-backed resources, external secrets) opt-in.

## Verifying changes

Run before committing when the tools are available:

```sh
helm lint charts/<app>
helm template <app> charts/<app> --kube-version 1.31.0 | kubeconform -strict -ignore-missing-schemas -summary
ct lint --config ct.yaml --charts charts/<app>
```

If `helm`/`ct` aren't installed, at minimum check YAML syntax and explain in the
summary that CI will perform the full lint/validation.

## Don'ts

- Don't commit `*.tgz` files or edit the `gh-pages` branch by hand — chart-releaser owns it.
- Don't change the Helm repo URL, GHCR path, or release tag format without being
  asked — the cluster's Helm/GitOps config depends on them.
