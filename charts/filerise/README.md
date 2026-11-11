# filerise

[FileRise](https://github.com/error311/FileRise) web file manager. Volumes: `uploads` (the managed files), `users`, `metadata`.

App version: `v3.42.0` (override with `image.tag`).

Put `PERSISTENT_TOKENS_KEY` in a Secret and set `existingSecret`. To browse other volumes, mount them under `/var/www/uploads/<name>` with `extraVolumes`/`extraVolumeMounts`.

## Storage

Every entry under `persistence` is mounted at its `mountPath` and can be backed by
a chart-created PVC (default), an `existingClaim` (optionally with `subPath`), or a
node `hostPath`. `enabled: false` swaps in an `emptyDir`. Chart-created PVCs carry
`helm.sh/resource-policy: keep` unless `retain: false`. `extraVolumes` /
`extraVolumeMounts` attach anything else, e.g. a shared backup or SMB claim from
the `homelab-core` chart.

## Install

```sh
helm upgrade --install filerise personal-charts/filerise -n <ns> --create-namespace -f my-values.yaml
```

See [`values.yaml`](values.yaml) for all options.
