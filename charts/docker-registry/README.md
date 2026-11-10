# docker-registry

A private OCI/Docker image registry ([CNCF Distribution](https://distribution.github.io/distribution/)) storing images in `/var/lib/registry`.

App version: `3.1.2` (override with `image.tag`).

Configure it through `env` as `REGISTRY_<SECTION>_<KEY>`. For basic auth, create a Secret with an `htpasswd` key (`htpasswd -Bbn user pass`) and set `auth.htpasswdSecret`. `service.type: NodePort` with `service.nodePort` lets nodes pull from `localhost:<nodePort>`. Large pushes through an ingress may need a bigger proxy body size.

## Storage

Every entry under `persistence` is mounted at its `mountPath` and can be backed by
a chart-created PVC (default), an `existingClaim` (optionally with `subPath`), or a
node `hostPath`. `enabled: false` swaps in an `emptyDir`. Chart-created PVCs carry
`helm.sh/resource-policy: keep` unless `retain: false`. `extraVolumes` /
`extraVolumeMounts` attach anything else, e.g. a shared backup or SMB claim from
the `homelab-core` chart.

## Install

```sh
helm upgrade --install docker-registry personal-charts/docker-registry -n <ns> --create-namespace -f my-values.yaml
```

See [`values.yaml`](values.yaml) for all options.
