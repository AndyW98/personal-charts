# filerise

[FileRise](https://github.com/error311/FileRise) web file manager. Volumes: `uploads` (the managed files), `users`, `metadata`.

App version: `v3.42.0` (override with `image.tag`).

Put `PERSISTENT_TOKENS_KEY` in a Secret and set `existingSecret`. To browse other volumes, mount them under `/var/www/uploads/<name>` with `extraVolumes`/`extraVolumeMounts`.

## Storage

Every entry under `persistence` is mounted at its `mountPath` and can be backed by
a chart-created PVC (default), an `existingClaim` (optionally with `subPath`), a
node `hostPath`, or an SMB share (below). `enabled: false` swaps in an `emptyDir`. Chart-created PVCs carry
`helm.sh/resource-policy: keep` unless `retain: false`. `extraVolumes` /
`extraVolumeMounts` attach anything else, e.g. a shared backup claim from
the `homelab-core` chart.

### SMB share

Any entry can mount an SMB / CIFS share directly. It is off until `smb.source` is set, and needs the
[SMB CSI driver](https://github.com/kubernetes-csi/csi-driver-smb) (`smb.csi.k8s.io`) installed in the cluster:

```yaml
persistence:
  uploads:
    smb:
      source: //nas.lan/share
      existingSecret: smb-credentials   # `username` / `password` keys, in the release namespace
```

The share is mounted as an inline CSI volume in the pod, so the chart creates no PV or PVC for that entry and `size`,
`storageClass` and `retain` don't apply; `subPath` still does. `fsGroup` has no effect on CIFS, so the default mount
options set the owner from `env.PUID` / `env.PGID` (`uid=...,gid=...,dir_mode=0770,file_mode=0660`).
`smb.mountOptions` replaces that list; for a guest share leave `existingSecret` empty and include `guest`.

`uploads` is the natural candidate.

CI can't install this (kind has no SMB CSI driver), so the SMB path is checked only by rendering the manifests.

## Install

```sh
helm upgrade --install filerise personal-charts/filerise -n <ns> --create-namespace -f my-values.yaml
```

See [`values.yaml`](values.yaml) for all options.
