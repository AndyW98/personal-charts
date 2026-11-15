# Storing chart data on an SMB share

Most charts in this repository can keep a volume on an SMB / CIFS share (a NAS, a Windows share, a router's USB
disk) instead of a PersistentVolumeClaim.

The option is opt-in. Nothing changes until you set `smb.source` on a volume: with the default values every chart
renders exactly the manifests it did before the option existed, and no SMB driver is needed.

## Which charts

| Chart | Where to set it | Default file owner on the share |
|-------|-----------------|---------------------------------|
| `docker-registry`, `foundryvtt`, `olah` | `persistence.<entry>.smb` | `podSecurityContext.runAsUser` / `runAsGroup` (1000) |
| `dokuwiki`, `filerise`, `heimdall`, `jellyfin` | `persistence.<entry>.smb` | `env.PUID` / `env.PGID` (1000) |
| `gitea` | `persistence.<entry>.smb` | `env.USER_UID` / `env.USER_GID` (1000) |
| `romm` | `persistence.<entry>.smb` | 1000, the image's `romm` user |
| `foundryvtt` backups | `backup.destination.smb` | `podSecurityContext.runAsUser` / `runAsGroup` (1000) |
| `marinara-engine`, `opencode-kali` | `persistence.smb` (they have one volume) | `podSecurityContext.runAsUser` / `runAsGroup` (1000) |

Not covered: `argentum-engine` (its only volume is Redis) and RomM's bundled MariaDB (`mariadb.persistence`).
Databases should stay on local storage. `homelab-core` has its own way to define SMB volumes, see
[One share for several releases](#one-share-for-several-releases).

## 1. Install the SMB CSI driver (once per cluster)

The charts mount the share through the [SMB CSI driver](https://github.com/kubernetes-csi/csi-driver-smb)
(`smb.csi.k8s.io`). Install it once:

```sh
helm repo add csi-driver-smb https://kubernetes-csi.github.io/csi-driver-smb
helm repo update csi-driver-smb
helm search repo csi-driver-smb --versions        # pick a version
helm install csi-driver-smb csi-driver-smb/csi-driver-smb --namespace kube-system --version <version>
```

Check that it registered:

```sh
kubectl get csidriver smb.csi.k8s.io
```

## 2. Create the credentials Secret

The chart never creates this Secret; it only references it by name. It needs the keys `username` and `password`
(and `domain` if the share requires one), and it must be in the **same namespace as the release**:

```sh
kubectl -n <ns> create secret generic smb-credentials \
  --from-literal username='<user>' \
  --from-literal password='<password>'
```

Avoid commas in the password: they split the mount options. Don't commit a manifest holding the real password;
produce the Secret with whatever you already use for secrets.

For a share that allows guest access, skip the Secret and see [Guest shares](#guest-shares).

## 3. Set the values

**Charts with `persistence` entries** (everything except `marinara-engine` and `opencode-kali`): set `smb` on the
entry that should live on the share. The entry names are in each chart's `values.yaml`.

```yaml
persistence:
  media:                                # jellyfin; `repos` for olah, `library` for romm, ...
    smb:
      source: //nas.lan/media           # //server/share
      existingSecret: smb-credentials
```

**`marinara-engine` and `opencode-kali`**: the block sits directly under `persistence`.

```yaml
persistence:
  smb:
    source: //nas.lan/marinara
    existingSecret: smb-credentials
```

**Foundry VTT backups**:

```yaml
backup:
  enabled: true
  destination:
    smb:
      source: //nas.lan/backups
      existingSecret: smb-credentials
    subPath: foundry
```

Then install or upgrade the release as usual.

Rules that apply everywhere:

- The entry must be enabled (`enabled: true`). Most are by default; `olah`'s `mirrors` and `logs` are not.
- Use one backing per entry. Setting `smb.source` together with `existingClaim` or `hostPath` fails the render.
- The chart creates no PV or PVC for an SMB entry, so `size`, `storageClass`, `volumeName` and `retain` are ignored
  for it.

### A folder inside the share

`subPath` mounts one folder of the share, and is the way to put several entries on the same share:

```yaml
persistence:
  library:
    subPath: romm/library
    smb:
      source: //nas.lan/games
      existingSecret: smb-credentials
  assets:
    subPath: romm/assets
    smb:
      source: //nas.lan/games
      existingSecret: smb-credentials
```

Kubernetes creates the folder if it is missing, provided the SMB user may write there. `marinara-engine` and
`opencode-kali` have no `subPath` value; put the folder in the source instead (`//nas.lan/share/folder`), in
which case it must already exist.

### Mount options

`fsGroup` has no effect on CIFS, so the chart sets the file owner through mount options. With `smb.mountOptions`
empty, the share is mounted with:

```
uid=<owner>,gid=<owner>,dir_mode=0770,file_mode=0660
```

where the owner is the user the app runs as (the last column of the table above). Changing `PUID`,
`runAsUser` and so on changes the mount to match.

Setting `smb.mountOptions` **replaces** the whole list, so repeat `uid` and `gid` when you add anything:

```yaml
persistence:
  data:
    smb:
      source: //192.168.0.1/share
      existingSecret: smb-credentials
      mountOptions:
        - uid=1000
        - gid=1000
        - dir_mode=0770
        - file_mode=0660
        - vers=2.0
```

Options that come up often:

| Option | When |
|--------|------|
| `vers=3.0`, `vers=2.1`, `vers=2.0`, `vers=1.0` | The server speaks an older SMB dialect than the kernel offers by default (common on router USB shares). SMB 1.0 is insecure and some kernels are built without it. |
| `nobrl` | The data includes SQLite or LevelDB databases, which rely on file locking. Locks then stay local to the pod, which is fine for these single-pod charts. |
| `file_mode=0770`, `mfsymlinks` | The app runs programs from the share or needs symlinks (`opencode-kali`'s home directory and workspace). |
| `ro` | Read-only data; also set `readOnly: true` on the entry. |
| `guest` | Guest shares, below. |

### Guest shares

Leave `existingSecret` empty and include `guest` in the mount options:

```yaml
persistence:
  media:
    readOnly: true
    smb:
      source: //nas.lan/public
      mountOptions:
        - guest
        - uid=1000
        - gid=1000
        - ro
```

## 4. Check the mount

```sh
kubectl -n <ns> get pods
kubectl -n <ns> describe pod <pod>                      # mount errors appear under Events
kubectl -n <ns> exec deploy/<release> -- df -h <mountPath>
```

The `df` line should show the share (`//server/share`) as the filesystem.

## Moving an existing release to SMB

- The chart does not copy data. Copy it to the share yourself before or after switching.
- The entry's old PVC is no longer part of the release once `smb.source` is set. With `retain: true` (the default
  on most entries) it is kept; with `retain: false` Helm deletes it on that upgrade.
- To go back, clear `smb.source`; the chart then uses the PVC again.

## What not to put on SMB

- **Databases**: MariaDB, Redis, and volumes dominated by SQLite or LevelDB (`jellyfin`'s `config`, `foundryvtt`'s
  `data`). Prefer local storage for those and SMB for media, libraries, uploads and backups.
- **`gitea` `data` and `heimdall` `config`** hold a SQLite database by default. On a share, add `nobrl`, or for
  Gitea use an external database.

## Troubleshooting

A pod that cannot mount its share stays in `ContainerCreating`; the reason is in its events
(`kubectl -n <ns> describe pod <pod>`).

| Event text | Usual cause |
|------------|-------------|
| `driver name smb.csi.k8s.io not found in the list of registered CSI drivers` | The SMB CSI driver is not installed, or not running on that node. |
| `Error getting username and password from secret` | The Secret is missing, in another namespace, or lacks the `username` / `password` keys. |
| `mount error(13): Permission denied` | Wrong username or password, or the account has no access to the share. |
| `mount error(2): No such file or directory` | Wrong share name, or a folder in `source` that does not exist. |
| `mount error(22): Invalid argument`, `mount error(95)`, `mount error(112): Host is down` | Usually an SMB dialect mismatch: add a `vers=` option. Error 22 can also be an invalid mount option. |

The mount error itself is generic. The node's kernel log says more:

```sh
sudo dmesg | grep -i cifs | tail -20
```

To try options without redeploying, mount by hand on the node (needs `cifs-utils`):

```sh
sudo mkdir -p /mnt/smbtest
sudo mount -t cifs //server/share /mnt/smbtest -o username=<user>,vers=2.0
sudo umount /mnt/smbtest
```

After changing the Secret, restart the pod (`kubectl -n <ns> rollout restart deploy/<release>`): credentials are
read only when the share is mounted.

## One share for several releases

`smb.source` mounts the share into one release's pod. To give several releases the same pre-defined volume,
declare it once in [`homelab-core`](../charts/homelab-core)'s `sharedVolumes` (a static PersistentVolume with the
`smb.csi.k8s.io` driver, plus a claim) and mount that claim from each app with `existingClaim` or `extraVolumes`.
The releases must be in the same namespace as the claim.

## How it is tested

CI installs every chart into a kind cluster, which has no SMB CSI driver, so it can't mount a share. The SMB
manifests are checked by rendering and schema validation only. Treat a first SMB deployment as untested on your
storage and check the pod events.
