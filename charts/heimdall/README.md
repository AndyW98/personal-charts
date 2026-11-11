# heimdall

[Heimdall](https://heimdall.site) application dashboard using the LinuxServer.io image. Data lives in `/config`.

App version: `v2.8.4-ls372` (override with `image.tag`).

## Storage

Every entry under `persistence` is mounted at its `mountPath` and can be backed by
a chart-created PVC (default), an `existingClaim` (optionally with `subPath`), or a
node `hostPath`. `enabled: false` swaps in an `emptyDir`. Chart-created PVCs carry
`helm.sh/resource-policy: keep` unless `retain: false`. `extraVolumes` /
`extraVolumeMounts` attach anything else, e.g. a shared backup or SMB claim from
the `homelab-core` chart.

## Install

```sh
helm upgrade --install heimdall personal-charts/heimdall -n <ns> --create-namespace -f my-values.yaml
```

See [`values.yaml`](values.yaml) for all options.
