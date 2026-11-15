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
  data:
    smb:
      source: //nas.lan/share
      existingSecret: smb-credentials   # `username` / `password` keys, in the release namespace
```

The share is mounted as an inline CSI volume in the pod, so the chart creates no PV or PVC for that entry and `size`,
`storageClass` and `retain` don't apply; `subPath` still does. `fsGroup` has no effect on CIFS, so the default mount
options set the owner from `podSecurityContext` (`uid=...,gid=...,dir_mode=0770,file_mode=0660`).
`smb.mountOptions` replaces that list; for a guest share leave `existingSecret` empty and include `guest`.

Foundry keeps its worlds in LevelDB databases, which rely on file locking; prefer local storage for `data`
and a share for `backup.destination`, which takes the same `smb` block.

CI can't install this (kind has no SMB CSI driver), so the SMB path is checked only by rendering the manifests.

## Install

```sh
helm upgrade --install foundryvtt personal-charts/foundryvtt -n <ns> --create-namespace -f my-values.yaml
```

See [`values.yaml`](values.yaml) for all options.
