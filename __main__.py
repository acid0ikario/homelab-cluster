"""Homelab cluster IaC.

Creates a k3d cluster, installs ArgoCD via Helm, and applies the app-of-apps
root Application so ArgoCD self-manages the rest of the platform from Git.

Notes:
- k3d cluster creation is done via a local command (k3d has no first-class
  Pulumi provider); everything after that is native Kubernetes/Helm resources.
"""

import pulumi
from pulumi import Config, Output
from pulumi_command import local
import pulumi_kubernetes as k8s
from pulumi_kubernetes.helm.v3 import Release, ReleaseArgs, RepositoryOptsArgs

cfg = Config()
cluster_name = cfg.get("clusterName") or "homelab"
agents = cfg.get_int("agents") or 2
argocd_ns = cfg.get("argocdNamespace") or "argocd"
gitops_repo = cfg.get("gitopsRepo") or "https://github.com/acid0ikario/homelab-workloads"
gitops_path = cfg.get("gitopsPath") or "bootstrap"
gitops_branch = cfg.get("gitopsBranch") or "main"

# --- 1. Create the k3d cluster --------------------------------------------
create_cluster = local.Command(
    "k3d-cluster",
    create=(
        f"k3d cluster create {cluster_name} "
        f"--servers 1 --agents {agents} "
        f"--port '80:80@loadbalancer' --port '443:443@loadbalancer' "
        f"--wait"
    ),
    delete=f"k3d cluster delete {cluster_name}",
)

# kubeconfig for the freshly created cluster
kubeconfig = local.Command(
    "kubeconfig",
    create=f"k3d kubeconfig get {cluster_name}",
    opts=pulumi.ResourceOptions(depends_on=[create_cluster]),
).stdout

k8s_provider = k8s.Provider("k3d", kubeconfig=kubeconfig)
child = pulumi.ResourceOptions(provider=k8s_provider)

# --- 2. Namespace + ArgoCD via Helm ---------------------------------------
ns = k8s.core.v1.Namespace(
    "argocd-ns",
    metadata={"name": argocd_ns},
    opts=child,
)

argocd = Release(
    "argocd",
    ReleaseArgs(
        chart="argo-cd",
        version="7.7.11",
        namespace=argocd_ns,
        repository_opts=RepositoryOptsArgs(repo="https://argoproj.github.io/argo-helm"),
        values={
            "server": {"extraArgs": ["--insecure"]},
            "configs": {"params": {"server.insecure": True}},
        },
    ),
    opts=pulumi.ResourceOptions(provider=k8s_provider, depends_on=[ns]),
)

# --- 3. Root Application (app-of-apps) -------------------------------------
root_app = k8s.apiextensions.CustomResource(
    "root-app",
    api_version="argoproj.io/v1alpha1",
    kind="Application",
    metadata={"name": "root", "namespace": argocd_ns},
    spec={
        "project": "default",
        "source": {
            "repoURL": gitops_repo,
            "targetRevision": gitops_branch,
            "path": gitops_path,
        },
        "destination": {
            "server": "https://kubernetes.default.svc",
            "namespace": argocd_ns,
        },
        "syncPolicy": {
            "automated": {"prune": True, "selfHeal": True},
            "syncOptions": ["CreateNamespace=true"],
        },
    },
    opts=pulumi.ResourceOptions(provider=k8s_provider, depends_on=[argocd]),
)

pulumi.export("clusterName", cluster_name)
pulumi.export("argocdNamespace", argocd_ns)
pulumi.export("gitopsRepo", gitops_repo)
pulumi.export("nextStep", "kubectl -n argocd get applications -w")
