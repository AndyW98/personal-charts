# foundryvtt

[Foundry VTT](https://foundryvtt.com) from `ghcr.io/andyw98/foundryvtt`, built from
[`images/foundryvtt`](../../images/foundryvtt). The Foundry release is licensed and needs a short-lived download URL, so the
image is only built on demand by the **Build foundryvtt image** workflow
([`.github/workflows/foundryvtt-image.yaml`](../../.github/workflows/foundryvtt-image.yaml), which has the steps).
CI tests the chart against a placeholder image with no Foundry code. Foundry's user data (`Config/`, `Data/`, `Logs/`, `Backups/`) lives in `/foundrydata`.

App version: `14.359` (override with `image.tag`).

The image and pod run as UID/GID 1000. A `hostPath` data directory must already belong to that user.

`backup.enabled` adds a CronJob that copies `<data>/Backups` to `backup.destination.existingClaim` (optional `subPath`) on `backup.schedule`.

Set the public hostname and proxy settings (`hostname`, `proxySSL`, `proxyPort`) in Foundry's `Config/options.json`.

## Storage

Every entry under `persistence` is mounted at its `mountPath` and can be backed by
a chart-created PVC (default), an `existingClaim` (optionally with `subPath`), or a
node `hostPath`. `enabled: false` swaps in an `emptyDir`. Chart-created PVCs carry
`helm.sh/resource-policy: keep` unless `retain: false`. `extraVolumes` /
`extraVolumeMounts` attach anything else, e.g. a shared backup or SMB claim from
the `homelab-core` chart.

## Install

```sh
helm upgrade --install foundryvtt personal-charts/foundryvtt -n <ns> --create-namespace -f my-values.yaml
```

See [`values.yaml`](values.yaml) for all options.
