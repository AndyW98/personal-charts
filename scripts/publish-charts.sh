#!/usr/bin/env bash
# Package every chart under charts/ and publish any version that is not
# already in the GitLab Helm package registry for this project.
#
# Required env (provided automatically by GitLab CI):
#   CI_API_V4_URL, CI_PROJECT_ID, CI_JOB_TOKEN
# Optional:
#   HELM_CHANNEL   registry channel to publish to (default: stable)
#   OCI_REGISTRY   if set (e.g. "$CI_REGISTRY_IMAGE/charts"), also push charts
#                  as OCI artifacts. Requires CI_REGISTRY, CI_REGISTRY_USER,
#                  CI_REGISTRY_PASSWORD.
#   DRY_RUN=1      package and report, but do not upload anything
set -euo pipefail

CHANNEL="${HELM_CHANNEL:-stable}"
OUT_DIR="${OUT_DIR:-.packaged}"
REPO_URL="${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/packages/helm/${CHANNEL}"
REPO_NAME="personal-charts"

mkdir -p "$OUT_DIR"

shopt -s nullglob
charts=(charts/*/Chart.yaml)
if [ ${#charts[@]} -eq 0 ]; then
  echo "No charts found under charts/ - nothing to publish."
  exit 0
fi

# Index of what is already published (may be empty on first run).
helm repo add "$REPO_NAME" "$REPO_URL" \
  --username gitlab-ci-token --password "$CI_JOB_TOKEN" --force-update >/dev/null
helm repo update "$REPO_NAME" >/dev/null || true

if [ -n "${OCI_REGISTRY:-}" ] && [ "${DRY_RUN:-0}" != "1" ]; then
  echo "$CI_REGISTRY_PASSWORD" | helm registry login "$CI_REGISTRY" \
    --username "$CI_REGISTRY_USER" --password-stdin
fi

published=0
for chart_yaml in "${charts[@]}"; do
  dir="$(dirname "$chart_yaml")"
  name="$(helm show chart "$dir" | awk '/^name:/ {print $2}')"
  version="$(helm show chart "$dir" | awk '/^version:/ {print $2}')"

  if helm search repo "$REPO_NAME/$name" --version "$version" -o json | grep -q "\"version\":\"$version\""; then
    echo "skip   $name-$version (already published)"
    continue
  fi

  echo "build  $name-$version"
  helm dependency build "$dir" >/dev/null
  pkg="$(helm package "$dir" --destination "$OUT_DIR" | awk '{print $NF}')"

  if [ "${DRY_RUN:-0}" = "1" ]; then
    echo "dry-run: would publish $pkg"
    continue
  fi

  echo "push   $pkg -> $REPO_URL"
  curl --fail-with-body --silent --show-error \
    --request POST \
    --user "gitlab-ci-token:${CI_JOB_TOKEN}" \
    --form "chart=@${pkg}" \
    "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/packages/helm/api/${CHANNEL}/charts"
  echo

  if [ -n "${OCI_REGISTRY:-}" ]; then
    echo "push   $pkg -> oci://$OCI_REGISTRY"
    helm push "$pkg" "oci://$OCI_REGISTRY"
  fi

  published=$((published + 1))
done

echo "Done. Published $published chart version(s)."
