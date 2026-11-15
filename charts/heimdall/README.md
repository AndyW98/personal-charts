# heimdall

[Heimdall](https://heimdall.site) application dashboard using the LinuxServer.io image. Data lives in `/config`.

App version: `v2.8.4-ls372` (override with `image.tag`).

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
  config:
    smb:
      source: //nas.lan/share
      existingSecret: smb-credentials   # `username` / `password` keys, in the release namespace
```

The share is mounted as an inline CSI volume in the pod, so the chart creates no PV or PVC for that entry and `size`,
`storageClass` and `retain` don't apply; `subPath` still does. `fsGroup` has no effect on CIFS, so the default mount
options set the owner from `env.PUID` / `env.PGID` (`uid=...,gid=...,dir_mode=0770,file_mode=0660`).
`smb.mountOptions` replaces that list; for a guest share leave `existingSecret` empty and include `guest`.

`config` holds a SQLite database, which relies on file locking; on a share add `nobrl` to the mount options.

CI can't install this (kind has no SMB CSI driver), so the SMB path is checked only by rendering the manifests.
Setup, mount options and troubleshooting are in the [SMB guide](../../docs/smb.md).

## Install

```sh
helm upgrade --install heimdall personal-charts/heimdall -n <ns> --create-namespace -f my-values.yaml
```

See [`values.yaml`](values.yaml) for all options.
