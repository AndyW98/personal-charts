# gitea

[Gitea](https://gitea.com) as a single pod using the rootful `gitea/gitea` image. Everything (app.ini, repositories, LFS, SQLite DB, SSH host keys) lives in `/data`.

App version: `28.3.0` (override with `image.tag`).

Configure app.ini through `env` as `GITEA__<section>__<KEY>`. Git over SSH uses a separate `<fullname>-ssh` Service (`ssh.service.type: NodePort` to expose it). For an external database, set the `GITEA__database__*` vars, with the password from `existingSecret`.

## Storage

Every entry under `persistence` is mounted at its `mountPath` and can be backed by
a chart-created PVC (default), an `existingClaim` (optionally with `subPath`), or a
node `hostPath`. `enabled: false` swaps in an `emptyDir`. Chart-created PVCs carry
`helm.sh/resource-policy: keep` unless `retain: false`. `extraVolumes` /
`extraVolumeMounts` attach anything else, e.g. a shared backup or SMB claim from
the `homelab-core` chart.

## Install

```sh
helm upgrade --install gitea personal-charts/gitea -n <ns> --create-namespace -f my-values.yaml
```

See [`values.yaml`](values.yaml) for all options.
