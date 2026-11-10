# k3s via Docker Compose

Runs one [k3s](https://k3s.io) node per Docker host from a single
`docker-compose.yml`. A `K3S_ROLE` variable switches the node between
**control plane** (`server`) and **worker** (`agent`).

The container is privileged and uses host networking, so a node behaves like a
native k3s install: it registers with the host's IP and hostname, and other
hosts can join it. That also means **one node per host** (ports would clash),
and Linux hosts only.

## Configuration

Settings live in `.env` next to the compose file (gitignored):

```sh
cp .env.example .env
```

| Variable | Default | Purpose |
|----------|---------|---------|
| `K3S_ROLE` | `server` | `server` = control-plane node (also schedules workloads), `agent` = worker node |
| `K3S_TOKEN` | *(required)* | Shared cluster secret; must be the same on every node |
| `K3S_URL` | *(empty)* | `https://<server-ip>:6443`. Required for agents; leave empty on the first server |
| `K3S_PLATFORM` | *(empty = native)* | Image platform, e.g. `linux/amd64` to run an x86-64 node on an ARM host. See [Running as x86-64 on ARM](#running-as-x86-64-on-arm) |
| `K3S_VERSION` | `v1.31.14-k3s1` | [`rancher/k3s`](https://hub.docker.com/r/rancher/k3s/tags) image tag; keep it the same on every node |
| `K3S_NODE_NAME` | host's hostname | Node name; must be unique in the cluster |
| `K3S_EXTRA_ARGS` | *(empty)* | Extra flags appended to `k3s server` / `k3s agent` |
| `K3S_KUBECONFIG_MODE` | `600` | File mode of the kubeconfig the server writes |

## Control-plane node

```sh
cp .env.example .env
```

```sh
sed -i "s/^K3S_TOKEN=.*/K3S_TOKEN=$(openssl rand -hex 32)/" .env
```

```sh
docker compose up -d
```

`.env` keeps `K3S_ROLE=server` and an empty `K3S_URL`. Once the node is up,
the admin kubeconfig is written to `./kubeconfig/kubeconfig.yaml` (owned by
root):

```sh
sudo env KUBECONFIG=$PWD/kubeconfig/kubeconfig.yaml kubectl get nodes
```

To use it from another machine, copy the file and replace `127.0.0.1` in its
`server:` line with the server host's IP. Without a kubeconfig you can also
run `docker compose exec k3s kubectl get nodes` on the server.

## Agent node

On each additional host, use the same files with this `.env`:

```sh
K3S_ROLE=agent
K3S_TOKEN=<same token as the server>
K3S_URL=https://<server-ip>:6443
```

```sh
docker compose up -d
```

The node shows up in `kubectl get nodes` on the server after a few seconds.

## Running as x86-64 on ARM

On an ARM host such as a Raspberry Pi, set this in `.env` to run the node as
x86-64 instead of the native architecture:

```sh
K3S_PLATFORM=linux/amd64
```

k3s itself and every pod on the node then run under QEMU user-mode emulation.
The node registers as `kubernetes.io/arch=amd64` and pulls amd64 images, so
x86-only images work on it.

The host needs the QEMU x86-64 handler registered first. Either install it
permanently (Debian / Raspberry Pi OS):

```sh
sudo apt install qemu-user-static binfmt-support
```

or register it with a helper container, which has to be repeated after every
reboot, before the node starts:

```sh
docker run --privileged --rm tonistiigi/binfmt --install amd64
```

Check that emulation works before starting the node (should print `x86_64`):

```sh
docker run --rm --platform linux/amd64 busybox uname -m
```

Things to expect:

- **It is slow.** Emulated code typically runs several times slower than
  native, and startup of the control plane can take minutes on a Pi. Prefer
  an emulated *agent* joined to a native server over an emulated server, and
  expect to raise probe timeouts on heavier workloads.
- **Not everything survives emulation.** QEMU user mode doesn't cover every
  syscall, so some workloads crash or misbehave where they would run fine on
  real x86 hardware. Treat it as a way to run the odd x86-only image, not as
  a production setup.
- **64-bit OS required**, and the stock Raspberry Pi 5 kernel uses 16K memory
  pages, which x86 emulation can choke on. If emulated containers crash
  immediately, switch to the 4K-page kernel (`kernel=kernel8.img` in
  `/boot/firmware/config.txt`).
- **Changing `K3S_PLATFORM` on an existing node** needs a wipe like a role
  switch does (below): the stored images and binaries are for the old
  architecture.
- Mixed clusters are fine: native ARM nodes and emulated amd64 nodes can join
  the same server. Use a `nodeSelector` on `kubernetes.io/arch` to steer
  x86-only pods to the emulated node.

## Switching a node's role

The role is fixed in the node's stored state, so wipe the node before
flipping `K3S_ROLE` (this deletes everything stored on that node):

```sh
kubectl delete node <node-name>
```

```sh
docker compose down -v
```

Then edit `.env` and run `docker compose up -d` again.

## Day-to-day

| Task | Command |
|------|---------|
| Logs | `docker compose logs -f` |
| Stop / start (state kept) | `docker compose stop` / `docker compose start` |
| Upgrade | Set `K3S_VERSION` in `.env`, then `docker compose up -d` — servers first, then agents |
| Remove the node and its data | `docker compose down -v` |

Recreating the container restarts every pod on that node.

## Notes

- **Firewall:** agents need TCP 6443 on the server; all nodes need UDP 8472
  (flannel VXLAN) and TCP 10250 (kubelet) between each other. The bundled
  Traefik ingress binds 80/443 on every node.
- **Disabling bundled components** (server only), e.g.
  `K3S_EXTRA_ARGS=--disable=traefik --disable=servicelb`.
- **Multiple control-plane nodes:** start the first server with
  `K3S_EXTRA_ARGS=--cluster-init` (embedded etcd), then start the others with
  `K3S_ROLE=server` and `K3S_URL` pointing at the first. Use an odd number of
  servers and open TCP 2379-2380 between them.
- **Data** lives in the `k3s_k3s-data` and `k3s_k3s-etc` Docker volumes
  (cluster state, container images, `local-path` PVs, node identity).
- Treat `K3S_TOKEN` and the kubeconfig as cluster-admin credentials.
