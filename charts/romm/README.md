# romm

[RomM](https://romm.app) ROM manager, with an optional bundled single-pod MariaDB.

App version: `5.4.1` (override with `image.tag`).

### Secrets

- **App**: `existingSecret` is loaded as env vars and must hold `ROMM_AUTH_SECRET_KEY`.
  It can also hold provider credentials (`SCREENSCRAPER_USER`, `SCREENSCRAPER_PASSWORD`,
  `RETROACHIEVEMENTS_API_KEY`, `STEAMGRIDDB_API_KEY`, `IGDB_CLIENT_ID`, `IGDB_CLIENT_SECRET`, ...).
  If it is empty, the chart creates `<fullname>-app` with a random key.
- **Database**: `mariadb.auth.existingSecret` with `mariadb-root-password` and `mariadb-password`.
  If it is empty, the chart creates `<fullname>-mariadb` with random passwords.

Generated Secrets are kept on uninstall and reused on upgrade.

### Database

`mariadb.enabled: true` runs `mariadb:<mariadb.image.tag>` with `MARIADB_AUTO_UPGRADE=1`.
**Never set the tag lower than the version that last wrote the data.** MariaDB cannot
downgrade a data directory. `mariadb.persistence` takes the same `existingClaim` /
`subPath` / `hostPath` options as the app volumes. Set `mariadb.enabled: false` and fill in
`externalDatabase` to use another server.

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
  library:
    smb:
      source: //nas.lan/share
      existingSecret: smb-credentials   # `username` / `password` keys, in the release namespace
```

The share is mounted as an inline CSI volume in the pod, so the chart creates no PV or PVC for that entry and `size`,
`storageClass` and `retain` don't apply; `subPath` still does. `fsGroup` has no effect on CIFS, so the default mount
options set the owner from the image's `romm` user (`uid=...,gid=...,dir_mode=0770,file_mode=0660`).
`smb.mountOptions` replaces that list; for a guest share leave `existingSecret` empty and include `guest`.

`library` is the natural candidate. Keep `redis-data` and the bundled MariaDB (`mariadb.persistence`, which has
no SMB option) on local storage.

CI can't install this (kind has no SMB CSI driver), so the SMB path is checked only by rendering the manifests.
Setup, mount options and troubleshooting are in the [SMB guide](../../docs/smb.md).

## Install

```sh
helm upgrade --install romm personal-charts/romm -n <ns> --create-namespace -f my-values.yaml
```

See [`values.yaml`](values.yaml) for all options.
