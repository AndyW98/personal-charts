# homelab-core

Cluster-level resources shared by the homelab app charts. Everything is off by default.

- **`clusterIssuer`**: a cert-manager ACME `ClusterIssuer` with an HTTP-01 (ingress) solver and an optional
  Cloudflare DNS-01 solver. cert-manager must already be installed. The Cloudflare token Secret must exist in
  cert-manager's cluster resource namespace (`cert-manager` by default), not in the release namespace.
- **`certificates`**: cert-manager `Certificate`s in the release namespace, e.g. one wildcard certificate for every app ingress.
- **`sharedVolumes`**: statically provisioned `PersistentVolume`s (`hostPath` or any CSI driver, e.g. `smb.csi.k8s.io`),
  each with a bound PVC in the release namespace. App releases in **the same namespace** mount them with
  `extraVolumes`. Both objects are kept on uninstall.
- **`extraObjects`**: any other manifests, rendered with `tpl`.

```sh
helm upgrade --install homelab-core personal-charts/homelab-core -n <ns> --create-namespace -f my-values.yaml
```

See [`values.yaml`](values.yaml) for all options.
