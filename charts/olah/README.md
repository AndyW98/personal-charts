# olah

[Olah](https://github.com/vtuber-plan/olah) is a self-hosted Hugging Face mirror. It proxies `huggingface.co` and
caches models, datasets and spaces block by block as clients download them, so later downloads come from the cluster.

App version: `0.5.4` (override with `image.tag`). The image is upstream's `xiahan2019/olah` from Docker Hub.

## Install

```sh
helm upgrade --install olah personal-charts/olah -n <ns> --create-namespace -f my-values.yaml
```

Then point clients at it with `HF_ENDPOINT`:

```sh
export HF_ENDPOINT=http://olah.<ns>.svc:8090   # or the ingress URL
hf download openai-community/gpt2
```

Clients keep using their own `HF_TOKEN` for gated and private repos; Olah forwards it and stores no token. Nothing
authenticates clients, so anyone who can reach the Service or ingress can download through it.

Olah's two HTML pages (the landing page at `/` and the cache listing at `/repos`) return 500 in the `0.5.4` image:
it ships a Starlette release that dropped the template call Olah uses. The API and download routes don't use
templates. Olah has no health endpoint, so the probes and `helm test` request `/docs` instead.

## Configuration

`config` is rendered into Olah's `configs.toml`:

- `cacheSizeLimit` caps the cache (`80GB`, `2TB`; not `Gi`). It is empty by default, so the cache grows until the
  volume is full. Set it below `persistence.repos.size`.
- `proxy` / `cache` rules restrict which repos may be fetched or stored. The last matching rule wins, and once a list
  has any rule, repos matching none are denied.
- `offline: true` serves only what is already cached.
- `hfNetloc` chains through another mirror instead of `huggingface.co`.
- `extra` passes any other `[basic]` key through.

`mirror.scheme` / `mirror.netloc` set the address clients use, as printed in the install notes and written to
`configs.toml`. Left empty they follow the first ingress host, or the in-cluster Service when the ingress is off.
`workers` starts more server processes for many concurrent downloads.

Behind an ingress, turn off response buffering and raise the read timeout; model files are many GB (see the comment
on `ingress.annotations`).

## Storage

Every entry under `persistence` is mounted at its `mountPath` and can be backed by
a chart-created PVC, an `existingClaim` (optionally with `subPath`), a
node `hostPath`, or an SMB share (below). `enabled: false` swaps in an `emptyDir`. Chart-created PVCs carry
`helm.sh/resource-policy: keep` unless `retain: false`.

| Entry | Path | Default | Holds |
|-------|------|---------|-------|
| `repos` | `/data/repos` | 100Gi PVC | The download cache |
| `mirrors` | `/data/mirrors` | `emptyDir` | Optional git clones served ahead of the upstream, as `models/<org>/<repo>`, `datasets/<org>/<repo>`, `spaces/<org>/<repo>` |
| `logs` | `/data/logs` | `emptyDir` | Hourly log files, which Olah never prunes (the container log has the same lines) |

Olah's cache format is not stable across versions: upstream says to delete the cache before upgrading, so empty the
`repos` volume when `appVersion` changes.

The pod runs as UID/GID 1000 with a read-only root filesystem. Volumes that don't honour `fsGroup` (hostPath, some
NFS exports) must already be writable by that user.

### SMB share

Any entry can mount an SMB / CIFS share directly, e.g. to keep the cache on a NAS. It is off until `smb.source` is
set, and needs the [SMB CSI driver](https://github.com/kubernetes-csi/csi-driver-smb) (`smb.csi.k8s.io`) installed in
the cluster:

```sh
kubectl -n <ns> create secret generic smb-credentials \
  --from-literal username=<user> --from-literal password=<password>
```

```yaml
persistence:
  repos:
    smb:
      source: //nas.lan/models
      existingSecret: smb-credentials
```

The share is mounted as an inline CSI volume in the pod, so the chart creates no PV or PVC for that entry and `size`,
`storageClass` and `retain` don't apply; `subPath` still does. `fsGroup` has no effect on CIFS, so the default mount
options make the pod's user own the files (`uid=1000,gid=1000,dir_mode=0770,file_mode=0660`, following
`podSecurityContext`). `smb.mountOptions` replaces that list; for a guest share leave `existingSecret` empty and
include `guest`.

CI can't cover this (kind has no SMB CSI driver), so the SMB path is checked only by rendering the manifests.

See [`values.yaml`](values.yaml) for all options.
