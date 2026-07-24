# Homelab cluster — Makefile
# Simple, declarative IaC: k3d config + a couple of kubectl applies.
#
#   make up          # create cluster + install ArgoCD + apply root app (everything)
#   make down        # delete the cluster
#   make status      # show nodes, ArgoCD apps and pods
#   make urls        # print browser URLs (starts port-forwards)
#   make password    # print the ArgoCD admin password
#
# Requires: k3d, kubectl, helm

CLUSTER      ?= homelab
ARGOCD_NS    ?= argocd
ARGOCD_CHART ?= 7.7.11

.DEFAULT_GOAL := help

.PHONY: help up cluster argocd bootstrap down status password urls hosts wait-argocd

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

up: cluster argocd bootstrap ## Create cluster + ArgoCD + root app (full stack)
	@echo ""
	@echo "✅ Homelab is up. ArgoCD is now syncing the platform from Git."
	@echo "   Watch it converge:  kubectl -n $(ARGOCD_NS) get applications -w"
	@echo "   Browser URLs:       make urls"

cluster: ## Create the k3d cluster from k3d.yaml
	@k3d cluster list $(CLUSTER) >/dev/null 2>&1 && echo "Cluster '$(CLUSTER)' already exists." || \
		k3d cluster create --config k3d.yaml
	@kubectl config use-context k3d-$(CLUSTER) >/dev/null

argocd: ## Install ArgoCD via Helm
	@helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
	@helm repo update >/dev/null
	@helm upgrade --install argocd argo/argo-cd \
		--namespace $(ARGOCD_NS) --create-namespace \
		--version $(ARGOCD_CHART) \
		--set 'configs.params.server\.insecure=true' \
		--wait --timeout 300s
	@$(MAKE) --no-print-directory wait-argocd

wait-argocd:
	@echo "Waiting for ArgoCD to be ready..."
	@kubectl -n $(ARGOCD_NS) rollout status deploy/argocd-server --timeout=180s

bootstrap: ## Apply the app-of-apps root Application
	@kubectl apply -f bootstrap/root-app.yaml
	@echo "Root Application applied — ArgoCD takes over from here."

down: ## Delete the k3d cluster
	@k3d cluster delete $(CLUSTER)

status: ## Show nodes, ArgoCD apps and all pods
	@echo "=== Nodes ==="        && kubectl get nodes
	@echo "" && echo "=== ArgoCD Applications ===" && kubectl get applications -n $(ARGOCD_NS)
	@echo "" && echo "=== Pods ===" && kubectl get pods -A | grep -vE 'Completed'

password: ## Print the ArgoCD admin password
	@kubectl -n $(ARGOCD_NS) get secret argocd-initial-admin-secret \
		-o jsonpath='{.data.password}' | base64 -d; echo

urls: ## Print browser URLs (served via Ingress)
	@echo "Services are exposed via ingress-nginx on *.homelab.local"
	@echo ""
	@echo "  ArgoCD          → http://argocd.homelab.local          (admin / 'make password')"
	@echo "  Grafana         → http://grafana.homelab.local         (admin / changeme)"
	@echo "  Prometheus      → http://prometheus.homelab.local"
	@echo "  garmindashboard → http://garmindashboard.homelab.local"
	@echo ""
	@echo "If names don't resolve, add them to your hosts file:  make hosts"

hosts: ## Print the hosts-file line to add for *.homelab.local
	@echo "Add this line to your hosts file:"
	@echo "  Windows: C:\\Windows\\System32\\drivers\\etc\\hosts  (as Administrator)"
	@echo "  Linux/WSL: /etc/hosts  (sudo)"
	@echo ""
	@echo "127.0.0.1 argocd.homelab.local grafana.homelab.local prometheus.homelab.local garmindashboard.homelab.local"
