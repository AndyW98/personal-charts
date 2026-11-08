# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this repo is

A personal Helm chart repository. Each chart deploys one self-hosted
application to the owner's Kubernetes cluster. GitLab CI lints, validates,
packages and publishes charts to the project's GitLab Helm package registry
(channel `stable`). See `README.md` for consumer-facing usage.

## Layout

- `charts/<app>/` — one chart per app. Directory name must equal `name` in `Chart.yaml`.
- `charts/<app>/ci/*-values.yaml` — extra value sets rendered in CI validation.
- `scripts/publish-charts.sh` — packages charts and uploads versions not yet in the registry (idempotent).
- `ct.yaml` — chart-testing config; `.yamllint.yaml` — YAML lint rules (templates are excluded).
- `.gitlab-ci.yml` — stages: `lint` → `validate` → `package` → `publish` (publish runs on the default branch only).

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
- Keep manifests valid for the `KUBERNETES_VERSION` set in `.gitlab-ci.yml`.

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

- Don't edit `.packaged/` or commit `*.tgz` files.
- Don't change the publish channel or registry URL without being asked —
  the cluster's Helm/GitOps config depends on them.
