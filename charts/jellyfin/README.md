# jellyfin

[Jellyfin](https://jellyfin.org) media server using the LinuxServer.io image. Volumes: `config`, `cache`, `media`.

App version: `12.4ubu2604-ls59` (override with `image.tag`).

Set `hostPort: 8096` to also expose the server on the node's IP.

## Storage

Every entry under `persistence` is mounted at its `mountPath` and can be backed by
a chart-created PVC (default), an `existingClaim` (optionally with `subPath`), or a
node `hostPath`. `enabled: false` swaps in an `emptyDir`. Chart-created PVCs carry
`helm.sh/resource-policy: keep` unless `retain: false`. `extraVolumes` /
`extraVolumeMounts` attach anything else, e.g. a shared backup or SMB claim from
the `homelab-core` chart.

## Install

```sh
helm upgrade --install jellyfin personal-charts/jellyfin -n <ns> --create-namespace -f my-values.yaml
```

See [`values.yaml`](values.yaml) for all options.
