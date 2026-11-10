# foundryvtt

[Foundry VTT](https://foundryvtt.com) from the privately built `andyw98/foundryvtt` image. The image bundles a licensed Foundry build, so it is built outside this repo. Foundry's user data (`Config/`, `Data/`, `Logs/`, `Backups/`) lives in `/foundrydata`.

App version: `14.359` (override with `image.tag`).

The pod runs as UID/GID 1000. A `hostPath` data directory must already belong to that user.

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
