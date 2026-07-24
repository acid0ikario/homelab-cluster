# homelab-cluster — cluster IaC (k3d + Makefile)

Declarative Infrastructure-as-Code that provisions the homelab **k3d** cluster and
bootstraps **ArgoCD**. After this runs, ArgoCD pulls
[`homelab-workloads`](https://github.com/acid0ikario/homelab-workloads) and deploys
the whole platform.

Part of the [homelab](https://github.com/acid0ikario/homelab) project.

No programming language, no state backend — just a declarative `k3d.yaml` and a
`Makefile` wrapping a couple of `kubectl` applies.

## What it does

1. Creates a local **k3d** cluster from [`k3d.yaml`](k3d.yaml)
   (1 server + 2 agents, k3s v1.31, Traefik disabled so ingress-nginx owns 80/443).
2. Installs **ArgoCD** via Helm.
3. Applies the **root Application** (app-of-apps) that points ArgoCD at
   `homelab-workloads`.

From there, GitOps takes over — nothing else is applied by hand.

## Prerequisites

```bash
k3d version && kubectl version --client && helm version
```

## Usage

```bash
make up          # create cluster + install ArgoCD + apply root app (everything)
make status      # nodes, ArgoCD apps, pods
make password    # ArgoCD admin password
make urls        # start port-forwards + print browser URLs
make down        # delete the cluster
```

`make` on its own prints the available targets.

### Bring the whole platform up

```bash
git clone https://github.com/acid0ikario/homelab-cluster
cd homelab-cluster
make up

# watch ArgoCD converge:
kubectl -n argocd get applications -w
```

### Tear it down

```bash
make down        # deletes the k3d cluster entirely
```

## Files

| File | Purpose |
|------|---------|
| `k3d.yaml` | Declarative cluster definition (nodes, ports, k3s args) |
| `Makefile` | `up` / `down` / `status` / `password` / `urls` targets |
| `bootstrap/root-app.yaml` | The app-of-apps root Application ArgoCD starts from |

## Browser URLs (via Ingress)

The platform exposes services through **ingress-nginx** on `*.homelab.local`.
Add these hostnames to your hosts file first (one-time):

**Windows** — `C:\Windows\System32\drivers\etc\hosts` (edit as Administrator):
```
127.0.0.1 argocd.homelab.local grafana.homelab.local prometheus.homelab.local garmindashboard.homelab.local
```

**Linux / WSL** — `/etc/hosts` (needs sudo):
```
127.0.0.1 argocd.homelab.local grafana.homelab.local prometheus.homelab.local garmindashboard.homelab.local
```

Then open in a browser:

| Service | URL | Credentials |
|---------|-----|-------------|
| ArgoCD | http://argocd.homelab.local | `admin` / `make password` |
| Grafana | http://grafana.homelab.local | `admin` / `changeme` |
| Prometheus | http://prometheus.homelab.local | — |
| garmindashboard | http://garmindashboard.homelab.local | — |

No port-forwards needed — k3d maps ports 80/443 to localhost and ingress-nginx
routes by hostname. The Ingress resources live in `homelab-workloads/ingress/`.

## Configuration

Override on the command line, e.g.:

```bash
make up CLUSTER=lab ARGOCD_CHART=7.7.11
```

| Variable | Default | Description |
|----------|---------|-------------|
| `CLUSTER` | `homelab` | k3d cluster name |
| `ARGOCD_NS` | `argocd` | ArgoCD namespace |
| `ARGOCD_CHART` | `7.7.11` | ArgoCD Helm chart version |

Node count / ports live in `k3d.yaml`.

## License

MIT © acid0ikario
