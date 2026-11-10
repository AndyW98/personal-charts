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
a chart-created PVC (default), an `existingClaim` (optionally with `subPath`), or a
node `hostPath`. `enabled: false` swaps in an `emptyDir`. Chart-created PVCs carry
`helm.sh/resource-policy: keep` unless `retain: false`. `extraVolumes` /
`extraVolumeMounts` attach anything else, e.g. a shared backup or SMB claim from
the `homelab-core` chart.

## Install

```sh
helm upgrade --install romm personal-charts/romm -n <ns> --create-namespace -f my-values.yaml
```

See [`values.yaml`](values.yaml) for all options.
