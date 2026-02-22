
SHELL := /bin/bash
MONITORING_NS=monitoring
ARGOCD_NS=argocd

ARGOCD_PORT=9080
GRAFANA_PORT=9081
PROMETHEUS_PORT=9082
ALERTMANAGER_PORT=9083

init:
	@echo "Initializing ArgoCD application..."
	@read -s -p "GitHub PAT: " GITHUB_PAT && echo "" && \
	kubectl create secret generic platform-gitops-repo \
		-n argocd \
		--from-literal=type=git \
		--from-literal=url=https://github.com/mmastersvz/platform-gitops.git \
		--from-literal=username=mmastersvz \
		--from-literal=password=$$GITHUB_PAT \
		--dry-run=client -o yaml | \
	kubectl apply -f - && \
	kubectl label secret platform-gitops-repo -n argocd argocd.argoproj.io/secret-type=repository --overwrite
	kubectl apply -f argocd/projects.yaml
	kubectl apply -f argocd/root-app.yaml

# Port-forwards (each runs in foreground; use separate terminals or background with &)
argocd-pf:
	kubectl port-forward svc/argocd-self-server -n $(ARGOCD_NS) $(ARGOCD_PORT):80

grafana-pf:
	kubectl port-forward svc/monitoring-grafana -n $(MONITORING_NS) $(GRAFANA_PORT):80

prometheus-pf:
	kubectl port-forward svc/monitoring-kube-prometheus-prometheus -n $(MONITORING_NS) $(PROMETHEUS_PORT):9090

alertmanager-pf:
	kubectl port-forward svc/monitoring-kube-prometheus-alertmanager -n $(MONITORING_NS) $(ALERTMANAGER_PORT):9093

pf: argocd-pf grafana-pf prometheus-pf alertmanager-pf