# homelab-cluster — Pulumi IaC

Infrastructure-as-Code that provisions the homelab **k3d** cluster and
bootstraps **ArgoCD**. After this runs, ArgoCD pulls
[`homelab-workloads`](https://github.com/acid0ikario/homelab-workloads) and
deploys the whole platform.

Part of the [homelab](https://github.com/acid0ikario/homelab) project.

## What it does

1. Creates a local **k3d** cluster (1 server + 2 agents, k3s v1.31).
2. Installs **ArgoCD** via Helm.
3. Applies the **root Application** (app-of-apps) that points ArgoCD at
   `homelab-workloads`.

From there, GitOps takes over — nothing else is applied by hand.

## Prerequisites

```bash
# k3d + kubectl + pulumi + python3
k3d version && kubectl version --client && pulumi version
```

## Usage

```bash
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt

pulumi stack init local          # first time only
pulumi config set gitopsRepo https://github.com/acid0ikario/homelab-workloads
pulumi up

# ArgoCD admin password:
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo
```

## Teardown

```bash
pulumi destroy       # removes ArgoCD + root app
k3d cluster delete homelab
```

## Config

| Key | Default | Description |
|-----|---------|-------------|
| `clusterName` | `homelab` | k3d cluster name |
| `agents` | `2` | number of agent nodes |
| `gitopsRepo` | — | URL of the homelab-workloads repo |
| `argocdNamespace` | `argocd` | namespace for ArgoCD |

## License

MIT © acid0ikario
